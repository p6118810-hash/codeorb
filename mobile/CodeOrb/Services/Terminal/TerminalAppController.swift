//
//  TerminalAppController.swift
//  CodeOrb
//
//  Generic terminal app activation fallback when pane-level focusing is unavailable.
//

import AppKit
import Foundation
import os.log

actor TerminalAppController {
    static let shared = TerminalAppController()
    nonisolated static let logger = Logger(subsystem: "com.codeorb", category: "TerminalApp")

    private init() {}

    func activate(processIdentifier pid: Int) -> Bool {
        activate(processIdentifier: pid, ignoringOtherApps: false)
    }

    func activate(processIdentifier pid: Int, ignoringOtherApps: Bool) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid_t(pid)) else {
            Self.logger.debug("activate failed because pid \(pid, privacy: .public) is not a running app")
            return false
        }

        var options: NSApplication.ActivationOptions = [.activateAllWindows]
        if ignoringOtherApps {
            options.insert(.activateIgnoringOtherApps)
        }

        let activated = app.activate(options: options)
        Self.logger.debug(
            "activate pid=\(pid, privacy: .public) bundle=\(app.bundleIdentifier ?? "nil", privacy: .public) ignoring=\(ignoringOtherApps, privacy: .public) result=\(activated, privacy: .public)"
        )
        return activated
    }

    func bundleIdentifier(processIdentifier pid: Int) -> String? {
        NSRunningApplication(processIdentifier: pid_t(pid))?.bundleIdentifier
    }

    func displayName(processIdentifier pid: Int?) -> String? {
        guard let pid else { return nil }
        return NSRunningApplication(processIdentifier: pid_t(pid))?.localizedName
    }

    func appLabel(processIdentifier pid: Int?) -> String? {
        guard let pid,
              let app = NSRunningApplication(processIdentifier: pid_t(pid)) else {
            return nil
        }
        return Self.friendlyLabel(for: app)
    }

    func ancestorAppLabel(processIdentifier pid: Int?) -> String? {
        guard let pid else { return nil }

        let tree = ProcessTreeBuilder.shared.buildTree()
        var current = pid
        var depth = 0

        while current > 1 && depth < 24 {
            if let app = NSRunningApplication(processIdentifier: pid_t(current)),
               let bundleIdentifier = app.bundleIdentifier,
               !bundleIdentifier.isEmpty {
                return Self.friendlyLabel(for: app)
            }

            guard let info = tree[current] else { break }
            current = info.ppid
            depth += 1
        }

        return nil
    }

    nonisolated private static func friendlyLabel(for app: NSRunningApplication) -> String? {
        switch app.bundleIdentifier {
        case "com.googlecode.iterm2":
            return "iTerm2"
        case "com.mitchellh.ghostty":
            return "Ghostty"
        case "com.apple.Terminal":
            return "Terminal"
        case "com.openai.codex":
            return "Codex App"
        default:
            return app.localizedName
        }
    }
}

actor GhosttyController {
    static let shared = GhosttyController()
    nonisolated static let logger = Logger(subsystem: "com.codeorb", category: "Ghostty")

    private let bundleIdentifier = "com.mitchellh.ghostty"

    private init() {}

    private struct GhosttySurface: Sendable {
        let windowId: String
        let windowName: String
        let tabId: String
        let tabName: String
        let isSelectedTab: Bool
        let focusedTerminalId: String
        let terminalId: String
        let terminalName: String
        let workingDirectory: String

        var isFocused: Bool {
            terminalId == focusedTerminalId
        }

        var combinedTitle: String {
            [terminalName, tabName, windowName]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }

        var bestDisplayLabel: String? {
            for candidate in [terminalName, tabName, windowName] {
                let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                return trimmed
            }
            return nil
        }
    }

    func isAvailable() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    func isGhosttyProcess(_ pid: Int?) async -> Bool {
        guard let pid else { return false }
        return await TerminalAppController.shared.bundleIdentifier(processIdentifier: pid) == bundleIdentifier
    }

    func terminalLabel(
        workingDirectory: String,
        commandHint: String? = nil,
        projectName: String? = nil,
        windowHint: String? = nil
    ) async -> String? {
        await bestSurface(
            workingDirectory: workingDirectory,
            commandHint: commandHint,
            projectName: projectName,
            windowHint: windowHint
        )?.bestDisplayLabel
    }

    func focusTerminal(
        workingDirectory: String,
        commandHint: String? = nil,
        projectName: String? = nil,
        windowHint: String? = nil
    ) async -> Bool {
        guard isAvailable() else { return false }
        guard let surface = await bestSurface(
            workingDirectory: workingDirectory,
            commandHint: commandHint,
            projectName: projectName,
            windowHint: windowHint
        ) else {
            Self.logger.debug(
                "focusTerminal no Ghostty surface matched cwd=\(workingDirectory, privacy: .public) hint=\(commandHint ?? "nil", privacy: .public)"
            )
            return false
        }

        let focused = await focusSurface(surface)

        Self.logger.notice(
            "focusTerminal cwd=\(workingDirectory, privacy: .public) hint=\(commandHint ?? "nil", privacy: .public) terminal=\(surface.bestDisplayLabel ?? surface.terminalId, privacy: .public) result=\(focused, privacy: .public)"
        )

        return focused
    }

    private func bestSurface(
        workingDirectory: String,
        commandHint: String?,
        projectName: String?,
        windowHint: String?
    ) async -> GhosttySurface? {
        let surfaces = await listSurfaces()
        guard !surfaces.isEmpty else { return nil }

        let targetPath = Self.normalizedPath(workingDirectory)
        let normalizedHint = Self.normalizedToken(commandHint)
        let normalizedProject = Self.normalizedToken(projectName)
        let normalizedWindowHint = Self.normalizedToken(windowHint)

        return surfaces
            .compactMap { surface -> (GhosttySurface, Int)? in
                let score = Self.surfaceScore(
                    surface: surface,
                    targetPath: targetPath,
                    commandHint: normalizedHint,
                    projectName: normalizedProject,
                    windowHint: normalizedWindowHint
                )
                guard score > 0 else { return nil }
                return (surface, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 > rhs.1
                }
                if lhs.0.isFocused != rhs.0.isFocused {
                    return lhs.0.isFocused && !rhs.0.isFocused
                }
                if lhs.0.isSelectedTab != rhs.0.isSelectedTab {
                    return lhs.0.isSelectedTab && !rhs.0.isSelectedTab
                }
                return lhs.0.terminalId < rhs.0.terminalId
            }
            .first?
            .0
    }

    private func listSurfaces() async -> [GhosttySurface] {
        let script = """
        tell application "Ghostty"
            set outputLines to {}

            repeat with w in windows
                set windowId to ""
                set windowName to ""
                try
                    set windowId to (id of w as text)
                end try
                try
                    set windowName to (name of w as text)
                end try

                repeat with tb in tabs of w
                    set tabId to ""
                    set tabName to ""
                    set tabSelected to "false"
                    set focusedTerminalId to ""

                    try
                        set tabId to (id of tb as text)
                    end try
                    try
                        set tabName to (name of tb as text)
                    end try
                    try
                        set tabSelected to ((selected of tb) as text)
                    end try
                    try
                        set focusedTerminalId to (id of focused terminal of tb as text)
                    end try

                    repeat with trm in terminals of tb
                        set terminalId to ""
                        set terminalName to ""
                        set terminalWorkingDirectory to ""

                        try
                            set terminalId to (id of trm as text)
                        end try
                        try
                            set terminalName to (name of trm as text)
                        end try
                        try
                            set terminalWorkingDirectory to (working directory of trm as text)
                        end try

                        copy (windowId & tab & windowName & tab & tabId & tab & tabName & tab & tabSelected & tab & focusedTerminalId & tab & terminalId & tab & terminalName & tab & terminalWorkingDirectory) to end of outputLines
                    end repeat
                end repeat
            end repeat

            set oldDelimiters to AppleScript's text item delimiters
            set AppleScript's text item delimiters to linefeed
            set outputText to outputLines as text
            set AppleScript's text item delimiters to oldDelimiters
            return outputText
        end tell
        """

        guard let output = await runAppleScript(script) else {
            return []
        }

        return output
            .components(separatedBy: .newlines)
            .compactMap(Self.parseSurface)
    }

    private func focusSurface(_ surface: GhosttySurface) async -> Bool {
        _ = activateApp(ignoringOtherApps: true)

        let escapedWindowId = Self.appleScriptEscaped(surface.windowId)
        let escapedTabId = Self.appleScriptEscaped(surface.tabId)
        let escapedTerminalId = Self.appleScriptEscaped(surface.terminalId)

        let script = """
        tell application "Ghostty"
            set targetWindowId to "\(escapedWindowId)"
            set targetTabId to "\(escapedTabId)"
            set targetTerminalId to "\(escapedTerminalId)"
            set matchedWindow to missing value
            set matchedTab to missing value
            set matchedTerminal to missing value

            repeat with w in windows
                try
                    if (id of w as text) is targetWindowId then
                        set matchedWindow to w
                        repeat with tb in tabs of w
                            try
                                if (id of tb as text) is targetTabId then
                                    set matchedTab to tb
                                    repeat with trm in terminals of tb
                                        try
                                            if (id of trm as text) is targetTerminalId then
                                                set matchedTerminal to trm
                                                exit repeat
                                            end if
                                        end try
                                    end repeat
                                    exit repeat
                                end if
                            end try
                        end repeat
                        exit repeat
                    end if
                end try
            end repeat

            if matchedWindow is missing value or matchedTab is missing value or matchedTerminal is missing value then
                return "not-found"
            end if

            activate window matchedWindow
            select tab matchedTab
            focus matchedTerminal
            delay 0.05
            try
                return (id of focused terminal of matchedTab as text)
            on error
                return "focused"
            end try
        end tell
        """

        let result = await runAppleScript(script)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        _ = activateApp(ignoringOtherApps: true)
        try? await Task.sleep(nanoseconds: 60_000_000)

        let frontmostBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let matchedTerminal = result == surface.terminalId || result == "focused"
        let isFrontmost = frontmostBundle == bundleIdentifier

        Self.logger.notice(
            "focusSurface target=\(surface.terminalId, privacy: .public) result=\(result ?? "nil", privacy: .public) frontmost=\(frontmostBundle ?? "nil", privacy: .public)"
        )

        return matchedTerminal && isFrontmost
    }

    private func runAppleScript(_ script: String) async -> String? {
        do {
            return try await ProcessExecutor.shared.run("/usr/bin/osascript", arguments: ["-e", script])
        } catch {
            Self.logger.error("AppleScript execution failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    nonisolated private static func appleScriptEscaped(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func activateApp(ignoringOtherApps: Bool) -> Bool {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        guard let app = apps.first else { return false }
        return app.activate(options: ignoringOtherApps ? [.activateAllWindows, .activateIgnoringOtherApps] : [.activateAllWindows])
    }

    nonisolated private static func parseSurface(_ line: String) -> GhosttySurface? {
        let fields = line.components(separatedBy: "\t")
        guard fields.count >= 9 else { return nil }
        return GhosttySurface(
            windowId: fields[0],
            windowName: fields[1],
            tabId: fields[2],
            tabName: fields[3],
            isSelectedTab: fields[4].lowercased() == "true",
            focusedTerminalId: fields[5],
            terminalId: fields[6],
            terminalName: fields[7],
            workingDirectory: fields[8]
        )
    }

    nonisolated private static func surfaceScore(
        surface: GhosttySurface,
        targetPath: String,
        commandHint: String?,
        projectName: String?,
        windowHint: String?
    ) -> Int {
        let surfacePath = normalizedPath(surface.workingDirectory)
        let pathScore = pathMatchScore(surfacePath: surfacePath, targetPath: targetPath)
        guard pathScore > 0 else { return 0 }

        var score = pathScore
        let combinedTitle = normalizedToken(surface.combinedTitle) ?? ""

        if let commandHint, combinedTitle.contains(commandHint) {
            score += 120
        }

        if let projectName, combinedTitle.contains(projectName) {
            score += 80
        }

        if let windowHint, combinedTitle.contains(windowHint) {
            score += 48
        }

        if surface.isSelectedTab {
            score += 12
        }

        if surface.isFocused {
            score += 4
        }

        return score
    }

    nonisolated private static func pathMatchScore(surfacePath: String, targetPath: String) -> Int {
        guard !surfacePath.isEmpty, !targetPath.isEmpty else { return 0 }
        if surfacePath == targetPath { return 1_000 }

        if surfacePath.hasPrefix(targetPath + "/") {
            let depthDelta = surfacePath.dropFirst(targetPath.count + 1).split(separator: "/").count
            return max(780, 920 - (depthDelta * 40))
        }

        if targetPath.hasPrefix(surfacePath + "/") {
            let depthDelta = targetPath.dropFirst(surfacePath.count + 1).split(separator: "/").count
            return max(680, 860 - (depthDelta * 48))
        }

        return 0
    }

    nonisolated private static func normalizedPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return URL(fileURLWithPath: trimmed)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
            .lowercased()
    }

    nonisolated private static func normalizedToken(_ token: String?) -> String? {
        guard let token else { return nil }
        let normalized = token
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized.isEmpty ? nil : normalized
    }
}
