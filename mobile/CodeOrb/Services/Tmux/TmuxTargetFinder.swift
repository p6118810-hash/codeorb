//
//  TmuxTargetFinder.swift
//  CodeOrb
//
//  Finds tmux targets for active session processes
//

import Foundation
import os.log

/// Finds tmux session/window/pane targets for active session processes
actor TmuxTargetFinder {
    static let shared = TmuxTargetFinder()
    nonisolated static let logger = Logger(subsystem: "com.codeorb", category: "TmuxTargetFinder")

    private init() {}

    /// Find the tmux target for a given session PID
    func findTarget(forSessionPid sessionPid: Int, socketPath: String? = nil) async -> TmuxTarget? {
        guard let tmuxPath = await TmuxPathFinder.shared.getTmuxPath() else {
            return nil
        }

        guard let output = await runTmuxCommand(tmuxPath: tmuxPath, socketPath: socketPath, args: [
            "list-panes", "-a", "-F", "#{session_name}:#{window_index}.#{pane_index} #{pane_pid}"
        ]) else {
            return nil
        }

        let tree = ProcessTreeBuilder.shared.buildTree()

        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1)
            guard parts.count == 2,
                  let panePid = Int(parts[1]) else { continue }

            let targetString = String(parts[0])

            if ProcessTreeBuilder.shared.isDescendant(targetPid: sessionPid, ofAncestor: panePid, tree: tree) {
                return TmuxTarget(from: targetString)
            }
        }

        return nil
    }

    /// Find the tmux target for a given working directory
    func findTarget(forWorkingDirectory workingDir: String, socketPath: String? = nil) async -> TmuxTarget? {
        guard let tmuxPath = await TmuxPathFinder.shared.getTmuxPath() else {
            return nil
        }

        guard let output = await runTmuxCommand(tmuxPath: tmuxPath, socketPath: socketPath, args: [
            "list-panes", "-a", "-F", "#{session_name}:#{window_index}.#{pane_index} #{pane_current_path}"
        ]) else {
            return nil
        }

        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let targetString = String(parts[0])
            let panePath = String(parts[1])

            if panePath == workingDir {
                return TmuxTarget(from: targetString)
            }
        }

        return nil
    }

    /// Find the tmux target for a given pane tty (e.g. ttys005 or /dev/ttys005)
    func findTarget(forTTY tty: String, socketPath: String? = nil) async -> TmuxTarget? {
        guard let tmuxPath = await TmuxPathFinder.shared.getTmuxPath() else {
            return nil
        }

        guard let output = await runTmuxCommand(tmuxPath: tmuxPath, socketPath: socketPath, args: [
            "list-panes", "-a", "-F", "#{session_name}:#{window_index}.#{pane_index} #{pane_tty}"
        ]) else {
            return nil
        }

        let normalizedTTY = Self.normalizeTTY(tty)

        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let targetString = String(parts[0])
            let paneTTY = Self.normalizeTTY(String(parts[1]))

            if paneTTY == normalizedTTY {
                return TmuxTarget(from: targetString)
            }
        }

        return nil
    }

    /// Resolve the pane tty for a known tmux target.
    func tty(for target: TmuxTarget, socketPath: String? = nil) async -> String? {
        guard let tmuxPath = await TmuxPathFinder.shared.getTmuxPath() else {
            return nil
        }

        guard let output = await runTmuxCommand(tmuxPath: tmuxPath, socketPath: socketPath, args: [
            "display-message", "-p", "-t", target.targetString, "#{pane_tty}"
        ]) else {
            return nil
        }

        let normalized = Self.normalizeTTY(output)
        return normalized.isEmpty ? nil : normalized
    }

    /// Resolve an attached client tty for a session, preferring the most recently active client.
    func clientTTY(forSessionName sessionName: String, socketPath: String? = nil) async -> String? {
        guard let tmuxPath = await TmuxPathFinder.shared.getTmuxPath() else {
            return nil
        }

        guard let output = await runTmuxCommand(tmuxPath: tmuxPath, socketPath: socketPath, args: [
            "list-clients", "-F", "#{client_activity} #{client_tty} #{session_name}"
        ]) else {
            return nil
        }

        let candidates = output
            .components(separatedBy: "\n")
            .compactMap { line -> (Int, String)? in
                let parts = line.split(separator: " ", maxSplits: 2)
                guard parts.count == 3,
                      let activity = Int(parts[0]),
                      String(parts[2]) == sessionName else {
                    return nil
                }

                let clientTTY = Self.normalizeTTY(String(parts[1]))
                guard !clientTTY.isEmpty else { return nil }
                return (activity, clientTTY)
            }
            .sorted { $0.0 > $1.0 }

        return candidates.first?.1
    }

    /// Check if a session's tmux pane is currently the active pane
    func isSessionPaneActive(sessionPid: Int) async -> Bool {
        guard let tmuxPath = await TmuxPathFinder.shared.getTmuxPath() else {
            return false
        }

        // Find which pane the session is in
        guard let sessionTarget = await findTarget(forSessionPid: sessionPid) else {
            return false
        }

        // Get the currently active pane
        guard let output = await runTmuxCommand(tmuxPath: tmuxPath, socketPath: nil, args: [
            "display-message", "-p", "#{session_name}:#{window_index}.#{pane_index}"
        ]) else {
            return false
        }

        let activeTarget = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return sessionTarget.targetString == activeTarget
    }

    // MARK: - Private Methods

    private func runTmuxCommand(tmuxPath: String, socketPath: String?, args: [String]) async -> String? {
        do {
            return try await ProcessExecutor.shared.run(
                tmuxPath,
                arguments: Self.socketArguments(socketPath: socketPath) + args
            )
        } catch {
            Self.logger.error(
                "tmux command failed args=\((Self.socketArguments(socketPath: socketPath) + args).joined(separator: " "), privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    nonisolated private static func socketArguments(socketPath: String?) -> [String] {
        guard let socketPath, !socketPath.isEmpty else { return [] }
        return ["-S", socketPath]
    }

    nonisolated private static func normalizeTTY(_ tty: String) -> String {
        tty
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/dev/", with: "")
    }
}
