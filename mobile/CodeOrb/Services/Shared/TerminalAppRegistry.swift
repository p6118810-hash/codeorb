//
//  TerminalAppRegistry.swift
//  CodeOrb
//
//  Centralized registry of known terminal applications
//

import Foundation

/// Registry of known terminal application names and bundle identifiers
struct TerminalAppRegistry: Sendable {
    /// Terminal app names for process matching
    static let appNames: Set<String> = [
        "Terminal",
        "iTerm2",
        "iTerm",
        "Ghostty",
        "Alacritty",
        "kitty",
        "Hyper",
        "Warp",
        "WezTerm",
        "Tabby",
        "Rio",
        "Contour",
        "foot",
        "st",
        "urxvt",
        "xterm",
        "Code",           // VS Code
        "Code - Insiders",
        "Cursor",
        "Windsurf",
        "zed"
    ]

    /// Bundle identifiers for terminal apps (for window enumeration)
    static let bundleIdentifiers: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "io.alacritty",
        "org.alacritty",
        "net.kovidgoyal.kitty",
        "co.zeit.hyper",
        "dev.warp.Warp-Stable",
        "com.github.wez.wezterm",
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.todesktop.230313mzl4w4u92",  // Cursor
        "com.exafunction.windsurf",
        "dev.zed.Zed"
    ]

    /// Check if an app name or command path is a known terminal
    static func isTerminal(_ appNameOrCommand: String) -> Bool {
        let lower = appNameOrCommand.lowercased()
        let basename = URL(fileURLWithPath: appNameOrCommand).lastPathComponent.lowercased()

        // Prefer exact basename matches so generic names like "Code" don't
        // accidentally match unrelated commands such as "codex".
        for name in appNames {
            let candidate = name.lowercased()
            if basename == candidate || lower.hasSuffix("/\(candidate)") {
                return true
            }
        }

        // Additional checks for common patterns
        return basename.contains("terminal") || basename.contains("iterm")
    }

    /// Check if a bundle identifier is a known terminal
    static func isTerminalBundle(_ bundleId: String) -> Bool {
        bundleIdentifiers.contains(bundleId)
    }
}
