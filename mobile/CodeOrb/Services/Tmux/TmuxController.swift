//
//  TmuxController.swift
//  CodeOrb
//
//  High-level tmux operations controller
//

import Foundation
import os.log

/// Controller for tmux operations
actor TmuxController {
    static let shared = TmuxController()
    nonisolated static let logger = Logger(subsystem: "com.codeorb", category: "TmuxController")

    private init() {}

    func findTmuxTarget(forSessionPid pid: Int) async -> TmuxTarget? {
        await TmuxTargetFinder.shared.findTarget(forSessionPid: pid)
    }

    func findTmuxTarget(forWorkingDirectory dir: String) async -> TmuxTarget? {
        await TmuxTargetFinder.shared.findTarget(forWorkingDirectory: dir)
    }

    func sendMessage(_ message: String, to target: TmuxTarget) async -> Bool {
        await ToolApprovalHandler.shared.sendMessage(message, to: target)
    }

    func approveOnce(target: TmuxTarget) async -> Bool {
        await ToolApprovalHandler.shared.approveOnce(target: target)
    }

    func approveAlways(target: TmuxTarget) async -> Bool {
        await ToolApprovalHandler.shared.approveAlways(target: target)
    }

    func reject(target: TmuxTarget, message: String? = nil) async -> Bool {
        await ToolApprovalHandler.shared.reject(target: target, message: message)
    }

    func switchToPane(target: TmuxTarget, socketPath: String? = nil, clientTTY: String? = nil) async -> Bool {
        guard let tmuxPath = await TmuxPathFinder.shared.getTmuxPath() else {
            Self.logger.error("switchToPane failed because tmux binary was not found")
            return false
        }

        do {
            let socketArgs = Self.socketArguments(socketPath: socketPath)

            if let clientTTY, !clientTTY.isEmpty {
                _ = try await ProcessExecutor.shared.run(tmuxPath, arguments: socketArgs + [
                    "switch-client",
                    "-c", Self.fullTTYPath(for: clientTTY),
                    "-t", target.targetString
                ])
                Self.logger.debug(
                    "switch-client succeeded target=\(target.targetString, privacy: .public) clientTTY=\(clientTTY, privacy: .public) socket=\(socketPath ?? "default", privacy: .public)"
                )
                return true
            }

            _ = try await ProcessExecutor.shared.run(tmuxPath, arguments: socketArgs + [
                "select-window", "-t", "\(target.session):\(target.window)"
            ])

            _ = try await ProcessExecutor.shared.run(tmuxPath, arguments: socketArgs + [
                "select-pane", "-t", target.targetString
            ])

            Self.logger.debug(
                "select-window/select-pane succeeded target=\(target.targetString, privacy: .public) socket=\(socketPath ?? "default", privacy: .public)"
            )
            return true
        } catch {
            Self.logger.error(
                "switchToPane failed target=\(target.targetString, privacy: .public) clientTTY=\(clientTTY ?? "nil", privacy: .public) socket=\(socketPath ?? "default", privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }

    nonisolated private static func socketArguments(socketPath: String?) -> [String] {
        guard let socketPath, !socketPath.isEmpty else { return [] }
        return ["-S", socketPath]
    }

    nonisolated private static func fullTTYPath(for tty: String) -> String {
        if tty.hasPrefix("/dev/") {
            return tty
        }
        return "/dev/\(tty)"
    }
}
