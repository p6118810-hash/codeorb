//
//  AutoContinueManager.swift
//  CodeOrb
//
//  Sends a guarded "continue" prompt when a session explicitly asks to continue.
//

import Foundation
import os.log

@MainActor
final class AutoContinueManager {
    static let shared = AutoContinueManager()
    nonisolated static let logger = Logger(subsystem: "com.codeorb", category: "AutoContinue")

    private var submittedWaitingSessionIds: Set<String> = []
    private let delay: Duration = .milliseconds(900)

    private init() {}

    func handleNewWaitingSessions(_ sessions: [SessionState]) {
        guard AppSettings.autoContinueEnabled else {
            Self.logger.debug("Auto continue skipped; setting disabled")
            return
        }

        for session in sessions {
            let key = waitingSessionKey(for: session)
            guard !submittedWaitingSessionIds.contains(key) else { continue }
            guard shouldContinue(session: session) else {
                Self.logger.debug("Auto continue skipped; no keyword matched for \(session.sessionId.prefix(8), privacy: .public)")
                continue
            }

            submittedWaitingSessionIds.insert(key)
            Task {
                try? await Task.sleep(for: delay)
                await submitIfStillWaiting(sessionId: session.sessionId, originalKey: key)
            }
        }
    }

    private func submitIfStillWaiting(sessionId: String, originalKey: String) async {
        guard AppSettings.autoContinueEnabled else { return }
        guard let session = await SessionStore.shared.session(for: sessionId),
              session.phase == .waitingForInput,
              waitingSessionKey(for: session) == originalKey,
              shouldContinue(session: session) else {
            return
        }

        let message = continueMessage(for: session)
        let sent = await send(message: message, to: session)
        Self.logger.notice(
            "Auto continue session=\(session.sessionId.prefix(8), privacy: .public) message=\(message, privacy: .public) sent=\(sent, privacy: .public)"
        )
    }

    private func send(message: String, to session: SessionState) async -> Bool {
        let context = await SessionTerminalContextResolver.shared.resolve(for: session)
        var fallbackTTY = context.tty ?? session.tty

        if context.isInTmux {
            let socketPath = await TmuxSocketResolver.shared.socketPath(forSessionPid: context.pid)
            if let target = await tmuxTarget(for: session, context: context, socketPath: socketPath) {
                let sentViaTmux = await ToolApprovalHandler.shared.sendMessage(message, to: target)
                if sentViaTmux {
                    return true
                }
                fallbackTTY = await TmuxTargetFinder.shared.tty(for: target, socketPath: socketPath) ?? fallbackTTY
                Self.logger.debug(
                    "Auto continue tmux send failed; falling back to iTerm tty=\(fallbackTTY ?? "nil", privacy: .public) for \(session.sessionId.prefix(8), privacy: .public)"
                )
            }
        }

        guard let tty = fallbackTTY else {
            Self.logger.debug("Auto continue failed; no tty for \(session.sessionId.prefix(8), privacy: .public)")
            return false
        }

        return await ITerm2Controller.shared.sendText(
            tty: tty,
            text: message,
            submit: true,
            workingDirectory: session.cwd,
            commandHint: commandHint(for: session),
            windowHint: session.windowHint
        )
    }

    private func tmuxTarget(for session: SessionState, context: SessionTerminalContext, socketPath: String?) async -> TmuxTarget? {
        if let pid = context.pid,
           let target = await TmuxTargetFinder.shared.findTarget(forSessionPid: pid, socketPath: socketPath) {
            return target
        }

        if let tty = context.tty,
           let target = await TmuxTargetFinder.shared.findTarget(forTTY: tty, socketPath: socketPath) {
            return target
        }

        return await TmuxTargetFinder.shared.findTarget(forWorkingDirectory: session.cwd, socketPath: socketPath)
    }

    private func shouldContinue(session: SessionState) -> Bool {
        let haystack = matchingText(for: session).lowercased()
        guard !haystack.isEmpty else { return false }

        let matched = keywords().contains { keyword in
            haystack.contains(keyword.lowercased())
        }
        Self.logger.debug(
            "Auto continue match session=\(session.sessionId.prefix(8), privacy: .public) matched=\(matched, privacy: .public) keywords=\(AppSettings.autoContinueKeywords, privacy: .public) text=\(String(haystack.prefix(120)), privacy: .public)"
        )
        return matched
    }

    private func keywords() -> [String] {
        AppSettings.autoContinueKeywords
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func continueMessage(for session: SessionState) -> String {
        containsCJK(languageText(for: session)) ? "继续" : "continue"
    }

    private func matchingText(for session: SessionState) -> String {
        var parts: [String] = []
        if session.lastMessageRole != "user", let lastMessage = session.lastMessage {
            parts.append(lastMessage)
        }
        parts.append(contentsOf: session.chatItems.suffix(8).compactMap { item in
            switch item.type {
            case .assistant(let text), .thinking(let text):
                return text
            default:
                return nil
            }
        })
        return parts.joined(separator: "\n")
    }

    private func languageText(for session: SessionState) -> String {
        var parts: [String] = [
            session.lastMessage ?? "",
            session.summary ?? "",
            session.firstUserMessage ?? "",
        ]
        parts.append(contentsOf: session.chatItems.suffix(8).compactMap { item in
            switch item.type {
            case .user(let text), .assistant(let text):
                return text
            default:
                return nil
            }
        })
        return parts.joined(separator: "\n")
    }

    private func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
    }

    private func commandHint(for session: SessionState) -> String {
        switch session.provider {
        case .codex:
            return "codex"
        case .claude:
            return "claude"
        case .gemini:
            return "gemini"
        }
    }

    private func waitingSessionKey(for session: SessionState) -> String {
        session.stableId
    }
}
