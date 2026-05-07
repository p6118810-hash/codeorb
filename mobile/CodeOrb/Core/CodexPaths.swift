//
//  CodexPaths.swift
//  CodeOrb
//
//  Single source of truth for all Codex config directory paths.
//  Resolves automatically via filesystem detection, with an optional user
//  override via AppSettings.codexDirectoryPath.
//

import Foundation

enum CodexPaths {

    /// Cached resolved directory to avoid filesystem checks on every access
    private static var _cachedDir: URL?

    /// Guards reads/writes to _cachedDir — accessed from the main actor
    /// (UI settings), the ConversationParser actor, and background watcher
    /// queues, so cross-thread access needs synchronization.
    private static let cacheLock = NSLock()

    /// Root Codex config directory, resolved once and cached.
    ///
    /// Resolution order:
    /// 1. CODEX_HOME environment variable (if set and exists)
    /// 2. AppSettings.codexDirectoryPath override (if changed from default)
    static var codexDir: URL {
        cacheLock.lock()
        if let cached = _cachedDir {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        // Resolve outside the lock — involves filesystem and settings reads
        // that shouldn't block other threads.
        let resolved = resolveCodexDir()

        cacheLock.lock()
        // Another thread may have populated the cache while we were resolving;
        // prefer theirs for consistency, but either value is correct.
        if let existing = _cachedDir {
            cacheLock.unlock()
            return existing
        }
        _cachedDir = resolved
        cacheLock.unlock()
        return resolved
    }

    static var hooksDir: URL {
        codexDir.appendingPathComponent("hooks")
    }

    static var hooksFile: URL {
        codexDir.appendingPathComponent("hooks.json")
    }

    static var configFile: URL {
        codexDir.appendingPathComponent("config.toml")
    }

    static var projectsDir: URL {
        codexDir.appendingPathComponent("sessions")
    }

    /// Shell-safe absolute path for hook commands in hooks.json.
    /// Absolute paths keep custom directories working;
    /// quoting keeps paths with spaces from being split by the shell.
    static var hookScriptShellPath: String {
        shellQuote(codexDir.appendingPathComponent("hooks/codeorb-state.py").path)
    }

    /// Invalidate the cached directory so the next access re-resolves.
    /// Call this when the user changes AppSettings.codexDirectoryPath.
    static func invalidateCache() {
        cacheLock.lock()
        _cachedDir = nil
        cacheLock.unlock()
    }

    private static func resolveCodexDir() -> URL {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        // 1. CODEX_HOME env var takes highest priority
        if let envDir = Foundation.ProcessInfo.processInfo.environment["CODEX_HOME"] {
            let expanded = (envDir as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded)
            if fm.fileExists(atPath: url.path) {
                return url
            }
        }

        // 2. User override via settings - accepts either an absolute path
        //    (chosen via the folder picker) or a legacy directory name under ~/
        let settingsValue = AppSettings.codexDirectoryPath
        if !settingsValue.isEmpty && settingsValue != ".codex" {
            if settingsValue.hasPrefix("/") {
                return URL(fileURLWithPath: settingsValue)
            } else {
                return home.appendingPathComponent(settingsValue)
            }
        }

        // 3. Default Codex home
        return home.appendingPathComponent(".codex")
    }

    private static func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
