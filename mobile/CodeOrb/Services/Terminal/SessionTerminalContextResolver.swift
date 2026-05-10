//
//  SessionTerminalContextResolver.swift
//  CodeOrb
//
//  Resolves live terminal metadata for sessions that were restored from disk.
//

import Foundation

struct SessionTerminalContext: Sendable {
    let pid: Int?
    let tty: String?
    let isInTmux: Bool
    let terminalPid: Int?
}

actor SessionTerminalContextResolver {
    static let shared = SessionTerminalContextResolver()

    private init() {}

    func resolve(for session: SessionState) async -> SessionTerminalContext {
        if session.provider == .codex,
           let transcriptPath = session.transcriptPath,
           let pid = Self.findLiveCodexSessionPid(transcriptPath: transcriptPath, cwd: session.cwd) {
            return context(forPid: pid, fallbackTTY: session.tty, fallbackIsInTmux: session.isInTmux)
        }

        if let pid = session.pid {
            return context(forPid: pid, fallbackTTY: session.tty, fallbackIsInTmux: session.isInTmux)
        }

        return SessionTerminalContext(
            pid: nil,
            tty: session.tty,
            isInTmux: session.isInTmux,
            terminalPid: nil
        )
    }

    private func context(
        forPid pid: Int,
        fallbackTTY: String?,
        fallbackIsInTmux: Bool
    ) -> SessionTerminalContext {
        let tree = ProcessTreeBuilder.shared.buildTree()
        let tty = tree[pid]?.tty ?? fallbackTTY
        let isInTmux = ProcessTreeBuilder.shared.isInTmux(pid: pid, tree: tree) || fallbackIsInTmux
        let terminalPid = ProcessTreeBuilder.shared.findTerminalPid(forProcess: pid, tree: tree)

        return SessionTerminalContext(
            pid: pid,
            tty: tty,
            isInTmux: isInTmux,
            terminalPid: terminalPid
        )
    }

    nonisolated static func findLiveCodexSessionPid(
        transcriptPath: String,
        cwd: String,
        tree providedTree: [Int: ProcessInfo]? = nil
    ) -> Int? {
        if let cached = liveCodexPidCache[transcriptPath],
           Date().timeIntervalSince(cached.checkedAt) < 60,
           kill(Int32(cached.pid), 0) == 0 {
            return cached.pid
        }

        let result = ProcessExecutor.shared.runSync("/usr/sbin/lsof", arguments: [
            "-t", transcriptPath
        ])

        guard case .success(let output) = result else {
            return nil
        }

        let tree = providedTree ?? ProcessTreeBuilder.shared.buildTree()
        let candidatePids = output
            .components(separatedBy: "\n")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { pid in
                guard let info = tree[pid] else { return false }
                guard info.command.lowercased().contains("codex") else { return false }
                return info.tty != nil || ProcessTreeBuilder.shared.isInTmux(pid: pid, tree: tree)
            }

        for pid in candidatePids {
            let workingDirectory = ProcessTreeBuilder.shared.getWorkingDirectory(forPid: pid)
            if workingDirectory == cwd {
                liveCodexPidCache[transcriptPath] = (pid, Date())
                return pid
            }
        }

        if let pid = candidatePids.first {
            liveCodexPidCache[transcriptPath] = (pid, Date())
            return pid
        }

        liveCodexPidCache.removeValue(forKey: transcriptPath)
        return nil
    }
}

private nonisolated(unsafe) var liveCodexPidCache: [String: (pid: Int, checkedAt: Date)] = [:]
