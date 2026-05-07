//
//  CodexConversationParser.swift
//  CodeOrb
//
//  Parses Codex rollout JSONL transcripts from ~/.codex/sessions.
//

import Foundation

actor CodexConversationParser {
    static let shared = CodexConversationParser()

    struct DiscoveredSession: Sendable {
        let sessionId: String
        let cwd: String
        let transcriptPath: String
        let startedAt: Date?
        let modifiedAt: Date
    }

    private struct Snapshot {
        let modificationDate: Date
        let messages: [ChatMessage]
        let completedToolIds: Set<String>
        let toolResults: [String: ConversationParser.ToolResult]
        let conversationInfo: ConversationInfo
        let sessionPhase: SessionPhase
    }

    private var cache: [String: Snapshot] = [:]

    func parse(transcriptPath: String) -> ConversationInfo {
        snapshot(for: transcriptPath).conversationInfo
    }

    func parseFullConversation(transcriptPath: String) -> [ChatMessage] {
        snapshot(for: transcriptPath).messages
    }

    func completedToolIds(transcriptPath: String) -> Set<String> {
        snapshot(for: transcriptPath).completedToolIds
    }

    func toolResults(transcriptPath: String) -> [String: ConversationParser.ToolResult] {
        snapshot(for: transcriptPath).toolResults
    }

    func sessionPhase(transcriptPath: String) -> SessionPhase {
        snapshot(for: transcriptPath).sessionPhase
    }

    func discoverRecentSessions(limit: Int = 12, scanLimit: Int = 48) -> [DiscoveredSession] {
        let root = CodexPaths.projectsDir
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var candidates: [(url: URL, modifiedAt: Date)] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent.hasPrefix("rollout-"),
                  fileURL.pathExtension == "jsonl" else {
                continue
            }

            let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey])
            let modifiedAt = values?.contentModificationDate ?? .distantPast
            candidates.append((fileURL, modifiedAt))
        }

        let sortedCandidates = candidates
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(scanLimit)

        var discovered: [DiscoveredSession] = []
        var seenSessionIds = Set<String>()

        for candidate in sortedCandidates {
            guard let session = parseDiscoveredSession(at: candidate.url, modifiedAt: candidate.modifiedAt),
                  !seenSessionIds.contains(session.sessionId) else {
                continue
            }

            discovered.append(session)
            seenSessionIds.insert(session.sessionId)

            if discovered.count >= limit {
                break
            }
        }

        return discovered
    }

    private func snapshot(for transcriptPath: String) -> Snapshot {
        let fileURL = URL(fileURLWithPath: transcriptPath)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: fileURL.path),
              let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let modificationDate = attributes[.modificationDate] as? Date,
              let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return Snapshot(
                modificationDate: .distantPast,
                messages: [],
                completedToolIds: [],
                toolResults: [:],
                conversationInfo: ConversationInfo(
                    summary: nil,
                    lastMessage: nil,
                    lastMessageRole: nil,
                    lastToolName: nil,
                    firstUserMessage: nil,
                    lastUserMessageDate: nil
                ),
                sessionPhase: .idle
            )
        }

        if let cached = cache[transcriptPath], cached.modificationDate == modificationDate {
            return cached
        }

        var messages: [ChatMessage] = []
        var completedToolIds = Set<String>()
        var toolResults: [String: ConversationParser.ToolResult] = [:]
        var usage = UsageInfo()
        var firstUserMessage: String?
        var lastUserMessage: String?
        var lastUserMessageDate: Date?
        var lastAssistantMessage: String?
        var lastToolName: String?
        var lastToolPreview: String?
        var pendingToolCalls = Set<String>()
        var lastEventType: String?
        var hasActiveTurn = false

        for (index, line) in contents.split(whereSeparator: \.isNewline).enumerated() {
            guard let object = jsonObject(for: String(line)) else { continue }
            let timestamp = parseTimestamp(object["timestamp"] as? String) ?? modificationDate
            let payload = object["payload"] as? [String: Any] ?? [:]

            switch object["type"] as? String {
            case "response_item":
                let itemType = payload["type"] as? String

                if itemType == "message", let role = payload["role"] as? String {
                    switch role {
                    case "user":
                        guard let text = responseMessageText(
                            from: payload,
                            textType: "input_text",
                            skipsInjectedBlocks: true
                        ) else { break }

                        let message = ChatMessage(
                            id: "codex-user-\(index)",
                            role: .user,
                            timestamp: timestamp,
                            content: [.text(text)]
                        )
                        messages.append(message)
                        firstUserMessage = firstUserMessage ?? text
                        lastUserMessage = text
                        lastUserMessageDate = timestamp

                    case "assistant":
                        guard let text = responseMessageText(
                            from: payload,
                            textType: "output_text",
                            skipsInjectedBlocks: false
                        ) else { break }

                        let message = ChatMessage(
                            id: "codex-assistant-\(index)",
                            role: .assistant,
                            timestamp: timestamp,
                            content: [.text(text)]
                        )
                        messages.append(message)
                        lastAssistantMessage = text

                    default:
                        break
                    }

                } else if itemType == "function_call" || itemType == "custom_tool_call" {
                    guard let toolName = payload["name"] as? String,
                          let callId = payload["call_id"] as? String,
                          !toolName.isEmpty else { break }

                    let input: [String: String]
                    if itemType == "custom_tool_call" {
                        input = ["input": payload["input"] as? String ?? ""]
                    } else {
                        input = parseArguments(payload["arguments"] as? String)
                    }

                    let message = ChatMessage(
                        id: "codex-tool-\(callId)",
                        role: .assistant,
                        timestamp: timestamp,
                        content: [.toolUse(ToolUseBlock(id: callId, name: toolName, input: input))]
                    )
                    messages.append(message)
                    pendingToolCalls.insert(callId)
                    lastToolName = toolName
                    lastToolPreview = preview(for: input)

                } else if itemType == "function_call_output" || itemType == "custom_tool_call_output" {
                    guard let callId = payload["call_id"] as? String else { break }
                    completedToolIds.insert(callId)
                    pendingToolCalls.remove(callId)

                    let output = payload["output"] as? String
                    toolResults[callId] = ConversationParser.ToolResult(
                        content: output,
                        stdout: output,
                        stderr: nil,
                        isError: false
                    )
                }

            case "event_msg":
                lastEventType = payload["type"] as? String
                switch lastEventType {
                case "task_started":
                    hasActiveTurn = true
                case "task_complete", "turn_aborted":
                    hasActiveTurn = false
                default:
                    break
                }
                if payload["type"] as? String == "token_count",
                   let info = payload["info"] as? [String: Any],
                   let totalUsage = info["total_token_usage"] as? [String: Any] {
                    usage.inputTokens = intValue(totalUsage["input_tokens"])
                    usage.outputTokens = intValue(totalUsage["output_tokens"])
                    usage.cacheReadTokens = intValue(totalUsage["cached_input_tokens"])
                }

            default:
                break
            }
        }

        let lastMessage: String?
        let lastMessageRole: String?
        if let assistant = lastAssistantMessage {
            lastMessage = assistant
            lastMessageRole = "assistant"
        } else if let toolPreview = lastToolPreview {
            lastMessage = toolPreview
            lastMessageRole = "tool"
        } else {
            lastMessage = lastUserMessage
            lastMessageRole = lastUserMessage == nil ? nil : "user"
        }

        let info = ConversationInfo(
            summary: lastAssistantMessage ?? lastUserMessage,
            lastMessage: lastMessage,
            lastMessageRole: lastMessageRole,
            lastToolName: lastToolName,
            firstUserMessage: firstUserMessage,
            lastUserMessageDate: lastUserMessageDate,
            usage: usage
        )

        let inferredPhase: SessionPhase
        if !pendingToolCalls.isEmpty || hasActiveTurn || lastEventType == "task_started" {
            inferredPhase = .processing
        } else if lastEventType == "task_complete" {
            inferredPhase = .waitingForInput
        } else {
            inferredPhase = .idle
        }

        let snapshot = Snapshot(
            modificationDate: modificationDate,
            messages: messages,
            completedToolIds: completedToolIds,
            toolResults: toolResults,
            conversationInfo: info,
            sessionPhase: inferredPhase
        )
        cache[transcriptPath] = snapshot
        return snapshot
    }

    private func parseDiscoveredSession(at fileURL: URL, modifiedAt: Date) -> DiscoveredSession? {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            return nil
        }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: 16 * 1024),
              let contents = String(data: data, encoding: .utf8) else {
            return nil
        }

        for line in contents.split(whereSeparator: \.isNewline) {
            guard let object = jsonObject(for: String(line)),
                  object["type"] as? String == "session_meta",
                  let payload = object["payload"] as? [String: Any],
                  let sessionId = payload["id"] as? String,
                  let cwd = payload["cwd"] as? String,
                  !sessionId.isEmpty,
                  !cwd.isEmpty else {
                continue
            }

            let startedAt = parseTimestamp(payload["timestamp"] as? String)
            return DiscoveredSession(
                sessionId: sessionId,
                cwd: cwd,
                transcriptPath: fileURL.path,
                startedAt: startedAt,
                modifiedAt: modifiedAt
            )
        }

        return nil
    }

    private func parseArguments(_ raw: String?) -> [String: String] {
        guard let raw,
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }

        var result: [String: String] = [:]
        for (key, value) in object {
            if let string = stringify(value) {
                result[key] = string
            }
        }
        return result
    }

    private func preview(for input: [String: String]) -> String? {
        if let command = input["cmd"] ?? input["chars"] ?? input["command"] {
            return collapsed(command, limit: 110)
        }
        return input.values.first.flatMap { collapsed($0, limit: 110) }
    }

    private func stringify(_ value: Any) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case let array as [Any]:
            return array.compactMap { stringify($0) }.joined(separator: ", ")
        case let object as [String: Any]:
            if let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
               let string = String(data: data, encoding: .utf8) {
                return string
            }
            return nil
        default:
            return nil
        }
    }

    private func responseMessageText(
        from payload: [String: Any],
        textType: String,
        skipsInjectedBlocks: Bool
    ) -> String? {
        guard let content = payload["content"] as? [[String: Any]] else {
            return nil
        }

        let segments = content.compactMap { item -> String? in
            guard item["type"] as? String == textType,
                  let text = item["text"] as? String else {
                return nil
            }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }

            if skipsInjectedBlocks, isInjectedPromptBlock(trimmed) {
                return nil
            }

            return trimmed
        }

        guard !segments.isEmpty else {
            return nil
        }

        return collapsed(segments.joined(separator: " "), limit: 4_000)
    }

    private func isInjectedPromptBlock(_ text: String) -> Bool {
        text.hasPrefix("# AGENTS.md instructions for ")
            || text.hasPrefix("<environment_context>")
            || text.hasPrefix("<permissions instructions>")
            || text.hasPrefix("<collaboration_mode>")
            || text.hasPrefix("<skills_instructions>")
    }

    private func collapsed(_ value: String, limit: Int) -> String? {
        let collapsed = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")

        guard !collapsed.isEmpty else { return nil }
        guard collapsed.count > limit else { return collapsed }

        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: limit - 1)
        return "\(collapsed[..<endIndex])…"
    }

    private func intValue(_ value: Any?) -> Int {
        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        default:
            return 0
        }
    }

    private func parseTimestamp(_ value: String?) -> Date? {
        guard let value else { return nil }
        return Self.isoFormatter.date(from: value)
    }

    private func jsonObject(for line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    nonisolated private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
