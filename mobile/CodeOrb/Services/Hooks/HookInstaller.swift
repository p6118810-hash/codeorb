//
//  HookInstaller.swift
//  CodeOrb
//
//  Auto-installs Codex hooks on app launch.
//

import Foundation

struct HookInstaller {
    private static let managedTimeout = 45
    private static let geminiManagedTimeout = 5000
    private static let managedEvents: [(name: String, matcher: String?)] = [
        ("SessionStart", "startup|resume"),
        ("UserPromptSubmit", nil),
        ("Stop", nil),
    ]
    private static let claudeManagedEvents: [(name: String, matcher: String?)] = [
        ("SessionStart", nil),
        ("UserPromptSubmit", nil),
        ("PreToolUse", "*"),
        ("PostToolUse", "*"),
        ("Notification", "*"),
        ("PermissionRequest", "*"),
        ("PreCompact", "auto"),
        ("PreCompact", "manual"),
        ("SessionEnd", nil),
        ("Stop", nil),
    ]
    private static let geminiManagedEvents: [(name: String, matcher: String?)] = [
        ("SessionStart", nil),
        ("BeforeAgent", nil),
        ("BeforeTool", nil),
        ("AfterTool", nil),
        ("AfterAgent", nil),
        ("Notification", nil),
        ("SessionEnd", nil),
    ]

    private static var claudeRootDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }

    private static var claudeHooksDir: URL {
        claudeRootDir.appendingPathComponent("hooks")
    }

    private static var claudeSettingsFile: URL {
        claudeRootDir.appendingPathComponent("settings.json")
    }

    private static var claudeHookScriptURL: URL {
        claudeHooksDir.appendingPathComponent("codeorb-state.py")
    }

    private static var claudeHookScriptShellPath: String {
        shellQuote(claudeHookScriptURL.path)
    }

    private static var geminiRootDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".gemini")
    }

    private static var geminiHooksDir: URL {
        geminiRootDir.appendingPathComponent("hooks")
    }

    private static var geminiSettingsFile: URL {
        geminiRootDir.appendingPathComponent("settings.json")
    }

    private static var geminiHookScriptURL: URL {
        geminiHooksDir.appendingPathComponent("codeorb-state.py")
    }

    private static var geminiHookScriptShellPath: String {
        shellQuote(geminiHookScriptURL.path)
    }

    /// Install hook script and update hooks.json/config.toml on app launch.
    static func installIfNeeded() {
        installCodexHooks()
        installClaudeHooks()
        installGeminiHooks()
    }

    static func isInstalled() -> Bool {
        isCodexInstalled() || isClaudeInstalled() || isGeminiInstalled()
    }

    static func uninstall() {
        uninstallCodexHooks()
        uninstallClaudeHooks()
        uninstallGeminiHooks()
    }

    private static func installCodexHooks() {
        let hooksDir = CodexPaths.hooksDir
        let pythonScript = hooksDir.appendingPathComponent("codeorb-state.py")
        let legacyPythonScript = hooksDir.appendingPathComponent("claude-island-state.py")

        try? FileManager.default.createDirectory(at: hooksDir, withIntermediateDirectories: true)

        if let bundled = Bundle.main.url(forResource: "codeorb-state", withExtension: "py") {
            try? FileManager.default.removeItem(at: pythonScript)
            try? FileManager.default.removeItem(at: legacyPythonScript)
            try? FileManager.default.copyItem(at: bundled, to: pythonScript)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: pythonScript.path
            )
        }

        updateHooks(at: CodexPaths.hooksFile)
        enableCodexHooksFeature(at: CodexPaths.configFile)
    }

    private static func installClaudeHooks() {
        try? FileManager.default.createDirectory(at: claudeHooksDir, withIntermediateDirectories: true)
        try? claudeHookScriptContents().write(to: claudeHookScriptURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: claudeHookScriptURL.path
        )
        updateClaudeHooks(at: claudeSettingsFile)
    }

    private static func installGeminiHooks() {
        try? FileManager.default.createDirectory(at: geminiHooksDir, withIntermediateDirectories: true)
        try? geminiHookScriptContents().write(to: geminiHookScriptURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: geminiHookScriptURL.path
        )
        updateGeminiHooks(at: geminiSettingsFile)
    }

    private static func isCodexInstalled() -> Bool {
        guard let data = try? Data(contentsOf: CodexPaths.hooksFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any] else {
            return false
        }

        for (_, value) in hooks {
            guard let groups = value as? [[String: Any]] else { continue }
            for group in groups {
                guard let groupHooks = group["hooks"] as? [[String: Any]] else { continue }
                if groupHooks.contains(where: isManagedHook) {
                    return true
                }
            }
        }

        return false
    }

    private static func isClaudeInstalled() -> Bool {
        isSettingsHooksInstalled(at: claudeSettingsFile)
    }

    private static func isGeminiInstalled() -> Bool {
        isSettingsHooksInstalled(at: geminiSettingsFile)
    }

    private static func uninstallCodexHooks() {
        let pythonScript = CodexPaths.hooksDir.appendingPathComponent("codeorb-state.py")
        let legacyPythonScript = CodexPaths.hooksDir.appendingPathComponent("claude-island-state.py")
        try? FileManager.default.removeItem(at: pythonScript)
        try? FileManager.default.removeItem(at: legacyPythonScript)

        removeHooks(at: CodexPaths.hooksFile)
        disableCodexHooksFeatureIfManaged(at: CodexPaths.configFile)
    }

    private static func uninstallClaudeHooks() {
        try? FileManager.default.removeItem(at: claudeHookScriptURL)
        removeClaudeHooks(at: claudeSettingsFile)
    }

    private static func uninstallGeminiHooks() {
        try? FileManager.default.removeItem(at: geminiHookScriptURL)
        removeGeminiHooks(at: geminiSettingsFile)
    }

    private static func updateHooks(at hooksURL: URL) {
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: hooksURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = existing
        }

        var hooks = root["hooks"] as? [String: Any] ?? [:]
        let command = "\(detectPython()) \(CodexPaths.hookScriptShellPath)"

        for (eventName, value) in hooks {
            let existingGroups = value as? [[String: Any]] ?? []
            let cleanedGroups = existingGroups.compactMap { sanitizeGroup($0) }
            if cleanedGroups.isEmpty {
                hooks.removeValue(forKey: eventName)
            } else {
                hooks[eventName] = cleanedGroups
            }
        }

        for event in managedEvents {
            let group = managedGroup(matcher: event.matcher, command: command)
            let existingGroups = hooks[event.name] as? [[String: Any]] ?? []
            hooks[event.name] = existingGroups + [group]
        }

        root["hooks"] = hooks

        if let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: hooksURL)
        }
    }

    private static func removeHooks(at hooksURL: URL) {
        guard let data = try? Data(contentsOf: hooksURL),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = root["hooks"] as? [String: Any] else {
            return
        }

        for (eventName, value) in hooks {
            let existingGroups = value as? [[String: Any]] ?? []
            let cleanedGroups = existingGroups.compactMap { sanitizeGroup($0) }

            if cleanedGroups.isEmpty {
                hooks.removeValue(forKey: eventName)
            } else {
                hooks[eventName] = cleanedGroups
            }
        }

        if hooks.isEmpty {
            root.removeValue(forKey: "hooks")
        } else {
            root["hooks"] = hooks
        }

        if root.isEmpty {
            try? FileManager.default.removeItem(at: hooksURL)
            return
        }

        if let updatedData = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) {
            try? updatedData.write(to: hooksURL)
        }
    }

    private static func updateClaudeHooks(at settingsURL: URL) {
        let command = "\(detectPython()) \(claudeHookScriptShellPath)"
        updateSettingsHooks(
            at: settingsURL,
            events: claudeManagedEvents,
            command: command,
            timeout: managedTimeout
        )
    }

    private static func removeClaudeHooks(at settingsURL: URL) {
        removeSettingsHooks(at: settingsURL)
    }

    private static func updateGeminiHooks(at settingsURL: URL) {
        let command = "\(detectPython()) \(geminiHookScriptShellPath)"
        updateSettingsHooks(
            at: settingsURL,
            events: geminiManagedEvents,
            command: command,
            timeout: geminiManagedTimeout
        )
    }

    private static func removeGeminiHooks(at settingsURL: URL) {
        removeSettingsHooks(at: settingsURL)
    }

    private static func enableCodexHooksFeature(at configURL: URL) {
        let existing = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        let updated = withCodexHooksEnabled(existing)
        guard updated != existing else { return }
        try? updated.write(to: configURL, atomically: true, encoding: .utf8)
    }

    private static func disableCodexHooksFeatureIfManaged(at configURL: URL) {
        guard let existing = try? String(contentsOf: configURL, encoding: .utf8) else {
            return
        }

        let updated = withoutCodexHooks(existing)
        guard updated != existing else { return }
        try? updated.write(to: configURL, atomically: true, encoding: .utf8)
    }

    private static func withCodexHooksEnabled(_ contents: String) -> String {
        var lines = contents.components(separatedBy: "\n")

        if let featureIndex = lineIndex(ofKey: "codex_hooks", inSection: "features", lines: lines) {
            if lines[featureIndex].trimmingCharacters(in: .whitespaces) == "codex_hooks = true" {
                return contents
            }
            lines[featureIndex] = "codex_hooks = true"
            return lines.joined(separator: "\n")
        }

        if let sectionRange = sectionRange(named: "features", lines: lines) {
            lines.insert("codex_hooks = true", at: sectionRange.upperBound)
            return lines.joined(separator: "\n")
        }

        if !lines.isEmpty, lines.last?.isEmpty == false {
            lines.append("")
        }
        lines.append("[features]")
        lines.append("codex_hooks = true")
        return lines.joined(separator: "\n")
    }

    private static func withoutCodexHooks(_ contents: String) -> String {
        var lines = contents.components(separatedBy: "\n")
        guard let index = lineIndex(ofKey: "codex_hooks", inSection: "features", lines: lines) else {
            return contents
        }

        lines.remove(at: index)

        if let range = sectionRange(named: "features", lines: lines) {
            let remaining = lines[range.lowerBound + 1..<range.upperBound]
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasPrefix("#") }

            if remaining.isEmpty {
                lines.remove(at: range.lowerBound)
                if range.lowerBound < lines.count, lines[range.lowerBound].isEmpty {
                    lines.remove(at: range.lowerBound)
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func sectionRange(named name: String, lines: [String]) -> Range<Int>? {
        let header = "[\(name)]"
        guard let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == header }) else {
            return nil
        }

        var end = lines.count
        if start + 1 < lines.count {
            for index in (start + 1)..<lines.count {
                let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                    end = index
                    break
                }
            }
        }

        return start..<end
    }

    private static func lineIndex(ofKey key: String, inSection section: String, lines: [String]) -> Int? {
        guard let range = sectionRange(named: section, lines: lines) else {
            return nil
        }

        for index in (range.lowerBound + 1)..<range.upperBound {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#") else { continue }
            if trimmed.hasPrefix("\(key) =") {
                return index
            }
        }

        return nil
    }

    private static func isSettingsHooksInstalled(at settingsURL: URL) -> Bool {
        guard let data = try? Data(contentsOf: settingsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any] else {
            return false
        }

        for (_, value) in hooks {
            guard let groups = value as? [[String: Any]] else { continue }
            for group in groups {
                guard let groupHooks = group["hooks"] as? [[String: Any]] else { continue }
                if groupHooks.contains(where: isManagedHook) {
                    return true
                }
            }
        }

        return false
    }

    private static func updateSettingsHooks(
        at settingsURL: URL,
        events: [(name: String, matcher: String?)],
        command: String,
        timeout: Int
    ) {
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = existing
        }

        var hooks = root["hooks"] as? [String: Any] ?? [:]

        for (eventName, value) in hooks {
            let existingGroups = value as? [[String: Any]] ?? []
            let cleanedGroups = existingGroups.compactMap { sanitizeGroup($0) }
            if cleanedGroups.isEmpty {
                hooks.removeValue(forKey: eventName)
            } else {
                hooks[eventName] = cleanedGroups
            }
        }

        for event in events {
            let group = managedGroup(matcher: event.matcher, command: command, timeout: timeout)
            let existingGroups = hooks[event.name] as? [[String: Any]] ?? []
            hooks[event.name] = existingGroups + [group]
        }

        root["hooks"] = hooks

        if let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: settingsURL)
        }
    }

    private static func removeSettingsHooks(at settingsURL: URL) {
        guard let data = try? Data(contentsOf: settingsURL),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = root["hooks"] as? [String: Any] else {
            return
        }

        for (eventName, value) in hooks {
            let existingGroups = value as? [[String: Any]] ?? []
            let cleanedGroups = existingGroups.compactMap { sanitizeGroup($0) }

            if cleanedGroups.isEmpty {
                hooks.removeValue(forKey: eventName)
            } else {
                hooks[eventName] = cleanedGroups
            }
        }

        if hooks.isEmpty {
            root.removeValue(forKey: "hooks")
        } else {
            root["hooks"] = hooks
        }

        if let updatedData = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) {
            try? updatedData.write(to: settingsURL)
        }
    }

    private static func managedGroup(matcher: String?, command: String, timeout: Int = managedTimeout) -> [String: Any] {
        var group: [String: Any] = [
            "hooks": [[
                "type": "command",
                "command": command,
                "timeout": timeout,
            ]]
        ]

        if let matcher {
            group["matcher"] = matcher
        }

        return group
    }

    private static func sanitizeGroup(_ group: [String: Any]) -> [String: Any]? {
        guard let hooks = group["hooks"] as? [[String: Any]] else {
            return group
        }

        let filteredHooks = hooks.filter { !isManagedHook($0) }
        guard !filteredHooks.isEmpty else {
            return nil
        }

        var updated = group
        updated["hooks"] = filteredHooks
        return updated
    }

    private static func isManagedHook(_ hook: [String: Any]) -> Bool {
        let command = hook["command"] as? String ?? ""
        return command.contains("codeorb-state.py")
            || command.contains("claude-island-state.py")
            || command.contains("OpenIslandHooks")
            || command.contains("open-island-bridge")
            || command.contains("vibe-island")
    }

    private static func detectPython() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["python3"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return "python3"
            }
        } catch {
            return "python"
        }

        return "python"
    }

    private static func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func claudeHookScriptContents() -> String {
        """
        #!/usr/bin/env python3
        import json
        import os
        import socket
        import subprocess
        import sys

        SOCKET_PATH = "/tmp/claude-island.sock"
        TIMEOUT_SECONDS = 300

        def get_tty():
            ppid = os.getppid()
            try:
                result = subprocess.run(
                    ["ps", "-p", str(ppid), "-o", "tty="],
                    capture_output=True,
                    text=True,
                    timeout=2,
                )
                tty = result.stdout.strip()
                if tty and tty not in {"??", "-"}:
                    return tty if tty.startswith("/dev/") else "/dev/" + tty
            except Exception:
                pass

            for stream in (sys.stdin, sys.stdout, sys.stderr):
                try:
                    return os.ttyname(stream.fileno())
                except (OSError, AttributeError):
                    continue
            return None

        def send_event(state):
            try:
                sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                sock.settimeout(TIMEOUT_SECONDS)
                sock.connect(SOCKET_PATH)
                sock.sendall(json.dumps(state).encode())
                if state.get("status") == "waiting_for_approval":
                    response = sock.recv(4096)
                    sock.close()
                    if response:
                        return json.loads(response.decode())
                else:
                    sock.close()
            except (socket.error, OSError, json.JSONDecodeError):
                return None
            return None

        def main():
            try:
                data = json.load(sys.stdin)
            except json.JSONDecodeError:
                sys.exit(1)

            event = data.get("hook_event_name", "")
            state = {
                "provider": "claude",
                "session_id": data.get("session_id", "unknown"),
                "cwd": data.get("cwd", ""),
                "event": event,
                "pid": os.getppid(),
                "tty": get_tty(),
                "prompt": data.get("prompt"),
                "last_assistant_message": data.get("last_assistant_message"),
            }

            tool_input = data.get("tool_input", {})
            if event == "UserPromptSubmit":
                state["status"] = "processing"
            elif event == "PreToolUse":
                state["status"] = "running_tool"
                state["tool"] = data.get("tool_name")
                state["tool_input"] = tool_input
                if data.get("tool_use_id"):
                    state["tool_use_id"] = data.get("tool_use_id")
            elif event == "PostToolUse":
                state["status"] = "processing"
                state["tool"] = data.get("tool_name")
                state["tool_input"] = tool_input
                if data.get("tool_use_id"):
                    state["tool_use_id"] = data.get("tool_use_id")
            elif event == "PermissionRequest":
                state["status"] = "waiting_for_approval"
                state["tool"] = data.get("tool_name")
                state["tool_input"] = tool_input
                response = send_event(state)
                if response:
                    decision = response.get("decision", "ask")
                    reason = response.get("reason", "")
                    if decision == "allow":
                        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": {"behavior": "allow"}}}))
                    elif decision == "deny":
                        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": {"behavior": "deny", "message": reason or "Denied by user via CodeOrb"}}}))
                sys.exit(0)
            elif event == "Notification":
                notification_type = data.get("notification_type")
                if notification_type == "permission_prompt":
                    sys.exit(0)
                state["status"] = "waiting_for_input" if notification_type == "idle_prompt" else "notification"
                state["notification_type"] = notification_type
                state["message"] = data.get("message")
            elif event == "Stop" or event == "SessionStart" or event == "SubagentStop":
                state["status"] = "waiting_for_input"
            elif event == "SessionEnd":
                state["status"] = "ended"
            elif event == "PreCompact":
                state["status"] = "compacting"
            else:
                state["status"] = "unknown"

            send_event(state)

        if __name__ == "__main__":
            main()
        """
    }

    private static func geminiHookScriptContents() -> String {
        """
        #!/usr/bin/env python3
        import fcntl
        import json
        import os
        import socket
        import subprocess
        import sys
        import uuid

        SOCKET_PATH = "/tmp/codeorb.sock"
        CACHE_PATH = os.path.expanduser("~/.gemini/hooks/codeorb-tool-cache.json")
        TIMEOUT_SECONDS = 30

        def get_tty():
            ppid = os.getppid()
            try:
                result = subprocess.run(
                    ["ps", "-p", str(ppid), "-o", "tty="],
                    capture_output=True,
                    text=True,
                    timeout=2,
                )
                tty = result.stdout.strip()
                if tty and tty not in {"??", "-"}:
                    return tty if tty.startswith("/dev/") else "/dev/" + tty
            except Exception:
                pass

            for stream in (sys.stdin, sys.stdout, sys.stderr):
                try:
                    return os.ttyname(stream.fileno())
                except (OSError, AttributeError):
                    continue
            return None

        def send_event(state):
            try:
                sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                sock.settimeout(TIMEOUT_SECONDS)
                sock.connect(SOCKET_PATH)
                sock.sendall(json.dumps(state).encode())
                sock.close()
            except (socket.error, OSError):
                return

        def with_cache(update_fn):
            os.makedirs(os.path.dirname(CACHE_PATH), exist_ok=True)
            with open(CACHE_PATH, "a+", encoding="utf-8") as handle:
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
                try:
                    handle.seek(0)
                    raw = handle.read().strip()
                    cache = json.loads(raw) if raw else {}
                    if not isinstance(cache, dict):
                        cache = {}
                    result = update_fn(cache)
                    handle.seek(0)
                    handle.truncate()
                    json.dump(cache, handle)
                    return result
                finally:
                    fcntl.flock(handle.fileno(), fcntl.LOCK_UN)

        def tool_cache_key(session_id, tool_name, tool_input):
            try:
                encoded = json.dumps(tool_input or {}, sort_keys=True, separators=(",", ":"))
            except TypeError:
                encoded = "{}"
            return f"{session_id}:{tool_name or 'unknown'}:{encoded}"

        def cache_tool_start(session_id, tool_name, tool_input):
            def update(cache):
                key = tool_cache_key(session_id, tool_name, tool_input)
                queue = cache.get(key) or []
                tool_use_id = f"gemini-{uuid.uuid4().hex}"
                queue.append(tool_use_id)
                cache[key] = queue
                return tool_use_id
            return with_cache(update)

        def cache_tool_finish(session_id, tool_name, tool_input):
            def update(cache):
                key = tool_cache_key(session_id, tool_name, tool_input)
                queue = cache.get(key) or []
                if queue:
                    tool_use_id = queue.pop(0)
                    if queue:
                        cache[key] = queue
                    else:
                        cache.pop(key, None)
                    return tool_use_id
                return f"gemini-{uuid.uuid4().hex}"
            return with_cache(update)

        def clear_session_cache(session_id):
            def update(cache):
                keys = [key for key in cache.keys() if key.startswith(f"{session_id}:")]
                for key in keys:
                    cache.pop(key, None)
            with_cache(update)

        def main():
            try:
                data = json.load(sys.stdin)
            except json.JSONDecodeError:
                sys.exit(1)

            hook_event = data.get("hook_event_name", "")
            session_id = data.get("session_id", "unknown")
            state = {
                "provider": "gemini",
                "session_id": session_id,
                "cwd": data.get("cwd") or os.getcwd(),
                "event": hook_event,
                "pid": os.getppid(),
                "tty": get_tty(),
                "transcript_path": data.get("transcript_path"),
            }

            if hook_event == "SessionStart":
                state["status"] = "starting"
            elif hook_event == "BeforeAgent":
                state["event"] = "UserPromptSubmit"
                state["status"] = "processing"
                state["prompt"] = data.get("prompt")
            elif hook_event == "AfterAgent":
                state["event"] = "Stop"
                state["status"] = "waiting_for_input"
                state["prompt"] = data.get("prompt")
                state["last_assistant_message"] = data.get("prompt_response")
            elif hook_event == "BeforeTool":
                tool_input = data.get("tool_input") or {}
                state["event"] = "PreToolUse"
                state["status"] = "running_tool"
                state["tool"] = data.get("tool_name")
                state["tool_input"] = tool_input
                state["tool_use_id"] = cache_tool_start(session_id, data.get("tool_name"), tool_input)
            elif hook_event == "AfterTool":
                tool_input = data.get("tool_input") or {}
                state["event"] = "PostToolUse"
                state["status"] = "processing"
                state["tool"] = data.get("tool_name")
                state["tool_input"] = tool_input
                state["tool_use_id"] = cache_tool_finish(session_id, data.get("tool_name"), tool_input)
            elif hook_event == "Notification":
                state["status"] = "processing"
                state["notification_type"] = data.get("notification_type")
                state["message"] = data.get("message")
            elif hook_event == "PreCompress":
                state["event"] = "PreCompact"
                state["status"] = "compacting"
            elif hook_event == "SessionEnd":
                clear_session_cache(session_id)
                state["status"] = "ended"
                state["message"] = data.get("reason")
            else:
                state["status"] = "unknown"

            send_event(state)

        if __name__ == "__main__":
            main()
        """
    }
}
