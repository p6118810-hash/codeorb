//
//  MCPToolFormatter.swift
//  CodeOrb
//
//  Utility for formatting MCP tool names and arguments
//

import Foundation

struct MCPToolFormatter {

    /// Tool aliases for friendlier display names
    private static let toolAliases: [String: String] = [
        "AgentOutputTool": "Await Agent",
        "AskUserQuestion": "Question",
        "TodoWrite": "Todo",
        "TodoRead": "Todo",
        "WebFetch": "Fetch",
        "WebSearch": "Search",
        "NotebookEdit": "Notebook",
        "BashOutput": "Bash",
        "KillShell": "Shell",
        "EnterPlanMode": "Plan",
        "ExitPlanMode": "Plan",
        "SlashCommand": "Command",
        "run_shell_command": "Command",
        "read_file": "Read",
        "read_many_files": "Read",
        "list_directory": "Files",
        "grep_search": "Search",
        "glob": "Glob",
        "replace": "Edit",
        "write_file": "Write",
        "ask_user": "Question",
        "write_todos": "Todo",
        "google_web_search": "Search",
        "web_fetch": "Fetch",
        "enter_plan_mode": "Plan",
        "exit_plan_mode": "Plan",
        "activate_skill": "Skill",
        "save_memory": "Memory",
        "get_internal_docs": "Docs",
        "update_topic": "Status",
        "tracker_create_task": "Tracker",
        "tracker_get_task": "Tracker",
        "tracker_list_tasks": "Tracker",
        "tracker_update_task": "Tracker",
        "tracker_add_dependency": "Tracker",
        "tracker_visualize": "Tracker",
        "complete_task": "Complete",
    ]

    /// Checks if tool name is in MCP format (e.g., "mcp__deepwiki__ask_question")
    static func isMCPTool(_ name: String) -> Bool {
        name.hasPrefix("mcp__")
    }

    /// Converts snake_case to Title Case
    /// e.g., "ask_question" → "Ask Question"
    static func toTitleCase(_ snakeCase: String) -> String {
        snakeCase
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    /// Formats MCP tool ID to human-readable format
    /// e.g., "mcp__deepwiki__ask_question" → "Deepwiki - Ask Question"
    /// Returns alias if available, otherwise original name
    static func formatToolName(_ toolId: String) -> String {
        // Check for alias first
        if let alias = toolAliases[toolId] {
            return alias
        }

        guard isMCPTool(toolId) else { return toolId }

        // Remove "mcp__" prefix and split by "__"
        let withoutPrefix = String(toolId.dropFirst(5)) // Drop "mcp__"
        let parts = withoutPrefix.split(separator: "_", maxSplits: 1, omittingEmptySubsequences: true)

        guard parts.count >= 1 else { return toolId }

        let serverName = toTitleCase(String(parts[0]))

        if parts.count >= 2 {
            // The second part starts with "_" which we need to drop
            let toolNameRaw = String(parts[1]).hasPrefix("_")
                ? String(String(parts[1]).dropFirst())
                : String(parts[1])
            let toolName = toTitleCase(toolNameRaw)
            return "\(serverName) - \(toolName)"
        }

        return serverName
    }

    /// Formats tool input dictionary for display
    /// e.g., ["repoName": "facebook/react", "question": "How does..."] → `repoName: "facebook/react", question: "How does..."`
    /// Truncates long values and limits number of args shown
    static func formatArgs(_ input: [String: String], maxValueLength: Int = 30, maxArgs: Int = 3) -> String {
        guard !input.isEmpty else { return "" }

        let sortedKeys = input.keys.sorted()
        var formattedParts: [String] = []

        for key in sortedKeys.prefix(maxArgs) {
            guard let value = input[key] else { continue }

            let truncatedValue: String
            if value.count > maxValueLength {
                truncatedValue = String(value.prefix(maxValueLength)) + "..."
            } else {
                truncatedValue = value
            }

            formattedParts.append("\(key): \"\(truncatedValue)\"")
        }

        var result = formattedParts.joined(separator: ", ")

        if sortedKeys.count > maxArgs {
            result += ", ..."
        }

        return result
    }

    /// Formats tool input from Any dictionary (handles both String and non-String values)
    static func formatArgs(_ input: [String: Any], maxValueLength: Int = 30, maxArgs: Int = 3) -> String {
        guard !input.isEmpty else { return "" }

        let sortedKeys = input.keys.sorted()
        var formattedParts: [String] = []

        for key in sortedKeys.prefix(maxArgs) {
            guard let value = input[key] else { continue }

            let stringValue: String
            if let str = value as? String {
                stringValue = str
            } else if let bool = value as? Bool {
                stringValue = bool ? "true" : "false"
            } else if let num = value as? NSNumber {
                stringValue = num.stringValue
            } else {
                stringValue = String(describing: value)
            }

            let truncatedValue: String
            if stringValue.count > maxValueLength {
                truncatedValue = String(stringValue.prefix(maxValueLength)) + "..."
            } else {
                truncatedValue = stringValue
            }

            formattedParts.append("\(key): \"\(truncatedValue)\"")
        }

        var result = formattedParts.joined(separator: ", ")

        if sortedKeys.count > maxArgs {
            result += ", ..."
        }

        return result
    }

    static func summarizeDisplayText(_ text: String?, maxLength: Int? = nil) -> String? {
        guard let text else { return nil }

        let normalized = sanitizedInlineMediaMarkup(in: text)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return nil }

        let summarized = summarizeStructuredJSON(normalized) ?? normalized

        if let maxLength, summarized.count > maxLength {
            return String(summarized.prefix(maxLength - 3)) + "..."
        }

        return summarized
    }

    private static func sanitizedInlineMediaMarkup(in text: String) -> String {
        let imageTagPattern = #"<image\b[^>]*>\s*</image>"#
        let withoutImageTags = text.replacingOccurrences(
            of: imageTagPattern,
            with: "",
            options: .regularExpression
        )

        return withoutImageTags.replacingOccurrences(
            of: #"(\[Image[^\]]+\])(?=\S)"#,
            with: "$1 ",
            options: .regularExpression
        )
    }

    private static func summarizeStructuredJSON(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (trimmed.hasPrefix("{") && trimmed.hasSuffix("}"))
            || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) else {
            return nil
        }

        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        return summarizeStructuredValue(object)
    }

    private static func summarizeStructuredValue(_ value: Any) -> String? {
        if let dict = value as? [String: Any] {
            if let planItems = dict["plan"] as? [[String: Any]], !planItems.isEmpty {
                if let activeItem = planItems.first(where: { ($0["status"] as? String) == "in_progress" }),
                   let step = activeItem["step"] as? String {
                    let status = statusLabel(activeItem["status"] as? String)
                    return status.map { "\(step) · \($0)" } ?? step
                }

                if let firstItem = planItems.first,
                   let step = firstItem["step"] as? String {
                    let completedCount = planItems.filter { ($0["status"] as? String) == "completed" }.count
                    return "Plan · \(completedCount)/\(planItems.count) · \(step)"
                }
            }

            if let step = dict["step"] as? String {
                let status = statusLabel(dict["status"] as? String)
                return status.map { "\(step) · \($0)" } ?? step
            }

            if let questions = dict["questions"] as? [[String: Any]], !questions.isEmpty {
                if let firstQuestion = questions.first?["question"] as? String {
                    return firstQuestion
                }
                return "Awaiting user input"
            }

            for key in ["prompt", "message", "description", "question", "header", "label", "text", "query", "url"] {
                if let textValue = dict[key] as? String,
                   let summarized = summarizeDisplayText(textValue) {
                    return summarized
                }
            }

            if let status = statusLabel(dict["status"] as? String) {
                return status
            }
        }

        if let array = value as? [Any], let first = array.first {
            let remainder = array.count > 1 ? " · +\(array.count - 1) more" : ""
            return summarizeStructuredValue(first).map { "\($0)\(remainder)" }
        }

        if let stringValue = value as? String {
            return summarizeDisplayText(stringValue)
        }

        return nil
    }

    private static func statusLabel(_ status: String?) -> String? {
        guard let status, !status.isEmpty else { return nil }

        switch status {
        case "in_progress":
            return "in progress"
        case "completed":
            return "completed"
        case "pending":
            return "pending"
        case "blocked":
            return "blocked"
        default:
            return status.replacingOccurrences(of: "_", with: " ")
        }
    }
}
