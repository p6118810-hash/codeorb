//
//  ITerm2Controller.swift
//  CodeOrb
//
//  Lightweight iTerm2 automation for focusing sessions by tty.
//

import AppKit
import Foundation
import os.log

actor ITerm2Controller {
    static let shared = ITerm2Controller()
    nonisolated static let logger = Logger(subsystem: "com.codeorb", category: "ITerm2")

    private let bundleIdentifier = "com.googlecode.iterm2"

    private init() {}

    func isAvailable() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    func activate() async -> Bool {
        guard isAvailable() else { return false }
        let success = await runAppleScript("""
        tell application "iTerm2"
            activate
            return "activated"
        end tell
        """)?.trimmingCharacters(in: .whitespacesAndNewlines) == "activated"
        Self.logger.debug("activate result=\(success, privacy: .public)")
        return success
    }

    func focusSession(tty: String) async -> Bool {
        guard isAvailable() else { return false }

        let normalizedTTY = Self.fullTTYPath(for: tty)
        let script = """
        tell application "iTerm2"
            set targetTTY to "\(normalizedTTY)"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        try
                            if tty of s is targetTTY then
                                tell w to select
                                tell t to select
                                tell s to select
                                activate
                                return "matched"
                            end if
                        end try
                    end repeat
                end repeat
            end repeat
            activate
            return "activated"
        end tell
        """

        let result = await runAppleScript(script)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let matched = result == "matched"
        Self.logger.debug(
            "focusSession tty=\(normalizedTTY, privacy: .public) result=\(matched, privacy: .public) raw=\(result ?? "nil", privacy: .public)"
        )
        return matched
    }

    func sendText(
        tty: String,
        text: String,
        submit: Bool,
        workingDirectory: String? = nil,
        commandHint: String? = nil,
        windowHint: String? = nil
    ) async -> Bool {
        guard isAvailable() else { return false }

        let normalizedTTY = Self.fullTTYPath(for: tty)
        let escapedTTY = Self.appleScriptString(normalizedTTY)
        let escapedText = Self.appleScriptString(text)
        let submitScript = submit
            ? """
                        delay 0.12
                        tell s to write text "" newline YES
            """
            : ""
        let script = """
        tell application "iTerm2"
            set targetTTY to "\(escapedTTY)"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        try
                            if tty of s is targetTTY then
                                tell s to write text "\(escapedText)" newline NO
        \(submitScript)
                                return "sent"
                            end if
                        end try
                    end repeat
                end repeat
            end repeat
            return "not-found"
        end tell
        """

        let result = await runAppleScript(script)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let sent = result == "sent"
        Self.logger.notice(
            "sendText tty=\(normalizedTTY, privacy: .public) cwd=\(workingDirectory ?? "nil", privacy: .public) submit=\(submit, privacy: .public) result=\(sent, privacy: .public) raw=\(result ?? "nil", privacy: .public)"
        )
        return sent
    }

    func sessionLabel(tty: String) async -> String? {
        guard isAvailable() else { return nil }

        let normalizedTTY = Self.fullTTYPath(for: tty)
        let script = """
        tell application "iTerm2"
            set targetTTY to "\(normalizedTTY)"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        try
                            if tty of s is targetTTY then
                                return (name of s as text)
                            end if
                        end try
                    end repeat
                end repeat
            end repeat
            return ""
        end tell
        """

        let result = await runAppleScript(script)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result?.isEmpty == false ? result : nil
    }

    private func runAppleScript(_ script: String) async -> String? {
        do {
            return try await ProcessExecutor.shared.run("/usr/bin/osascript", arguments: ["-e", script])
        } catch {
            Self.logger.error("AppleScript execution failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    nonisolated private static func fullTTYPath(for tty: String) -> String {
        if tty.hasPrefix("/dev/") {
            return tty
        }
        return "/dev/\(tty)"
    }

    nonisolated private static func appleScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
    }
}
