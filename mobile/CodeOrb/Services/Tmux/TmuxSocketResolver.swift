//
//  TmuxSocketResolver.swift
//  CodeOrb
//
//  Resolves the tmux socket from a session process environment.
//

import Foundation
import os.log

actor TmuxSocketResolver {
    static let shared = TmuxSocketResolver()

    nonisolated static let logger = Logger(subsystem: "com.codeorb", category: "TmuxSocket")

    private init() {}

    func socketPath(forSessionPid pid: Int?) async -> String? {
        guard let pid else { return nil }

        if let socketPath = socketPath(forPid: pid) {
            return socketPath
        }

        let tree = ProcessTreeBuilder.shared.buildTree()
        var currentPid = tree[pid]?.ppid

        while let ancestorPid = currentPid {
            if let socketPath = socketPath(forPid: ancestorPid) {
                return socketPath
            }
            currentPid = tree[ancestorPid]?.ppid
        }

        return nil
    }

    private func socketPath(forPid pid: Int) -> String? {
        let result = ProcessExecutor.shared.runSync("/bin/ps", arguments: [
            "eww", "-p", String(pid), "-o", "command="
        ])

        guard case .success(let output) = result else {
            return nil
        }

        guard let match = output.range(of: #"TMUX=([^\s]+)"#, options: .regularExpression) else {
            return nil
        }

        let envValue = String(output[match])
            .replacingOccurrences(of: "TMUX=", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let socketPath = envValue.split(separator: ",", maxSplits: 1).first.map(String.init)
        if let socketPath, !socketPath.isEmpty {
            Self.logger.debug("Resolved tmux socket for pid \(pid): \(socketPath, privacy: .public)")
        }
        return socketPath
    }
}
