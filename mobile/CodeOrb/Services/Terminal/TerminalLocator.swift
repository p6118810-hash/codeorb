//
//  TerminalLocator.swift
//  CodeOrb
//
//  Unified terminal focus entrypoint. First release targets iTerm2 + tmux.
//

import Foundation
import os.log

actor TerminalLocator {
    static let shared = TerminalLocator()

    nonisolated static let logger = Logger(subsystem: "com.codeorb", category: "TerminalLocator")
    private var terminalLabelCache: [String: String] = [:]

    private init() {}

    func canLocate(session: SessionState) async -> Bool {
        let context = await SessionTerminalContextResolver.shared.resolve(for: session)
        let hasITerm = await ITerm2Controller.shared.isAvailable()
        let hasGhostty = await GhosttyController.shared.isAvailable()
        let isGhosttyTerminal = await GhosttyController.shared.isGhosttyProcess(context.terminalPid)
        let canFocusViaGhostty = hasGhostty && isGhosttyTerminal
        let hasYabai = await WindowFinder.shared.isYabaiAvailable()
        let canFocusExactTTY = context.tty != nil
        let shouldInferTarget = context.isInTmux || context.tty == nil
        let socketPath = context.isInTmux
            ? await TmuxSocketResolver.shared.socketPath(forSessionPid: context.pid)
            : nil
        let inferredTarget = shouldInferTarget
            ? (context.isInTmux
            ? await tmuxTarget(for: session, context: context, socketPath: socketPath)
            : await TmuxTargetFinder.shared.findTarget(forWorkingDirectory: session.cwd, socketPath: nil))
            : nil

        let canFocusViaITerm = hasITerm && !isGhosttyTerminal && (canFocusExactTTY || inferredTarget != nil)
        let canFocusViaScriptedTerminal = canFocusViaGhostty && !session.cwd.isEmpty
        let canFocusViaWindow = hasYabai && (context.pid != nil || context.terminalPid != nil || inferredTarget != nil)
        let canActivateTerminalApp = context.terminalPid != nil
        let canLocate = canFocusViaITerm || canFocusViaScriptedTerminal || canFocusViaWindow || canActivateTerminalApp

        Self.logger.debug(
            "canLocate session \(session.sessionId.prefix(8), privacy: .public) result=\(canLocate, privacy: .public) hasITerm=\(hasITerm, privacy: .public) hasGhostty=\(hasGhostty, privacy: .public) hasYabai=\(hasYabai, privacy: .public) target=\(inferredTarget?.targetString ?? "nil", privacy: .public) socket=\(socketPath ?? "default", privacy: .public) tty=\(context.tty ?? "nil", privacy: .public) pid=\(context.pid.map(String.init) ?? "nil", privacy: .public) terminalPid=\(context.terminalPid.map(String.init) ?? "nil", privacy: .public) tmux=\(context.isInTmux, privacy: .public)"
        )

        return canLocate
    }

    func focus(session: SessionState) async -> Bool {
        let context = await SessionTerminalContextResolver.shared.resolve(for: session)
        let hasITerm = await ITerm2Controller.shared.isAvailable()
        let hasGhostty = await GhosttyController.shared.isAvailable()
        let isGhosttyTerminal = await GhosttyController.shared.isGhosttyProcess(context.terminalPid)
        let shouldInferTarget = context.isInTmux || context.tty == nil
        let socketPath = context.isInTmux
            ? await TmuxSocketResolver.shared.socketPath(forSessionPid: context.pid)
            : nil
        let target = shouldInferTarget
            ? (context.isInTmux
            ? await tmuxTarget(for: session, context: context, socketPath: socketPath)
            : await TmuxTargetFinder.shared.findTarget(forWorkingDirectory: session.cwd, socketPath: nil))
            : nil
        let hasTmuxTarget = context.isInTmux || target != nil
        let clientTTY = hasTmuxTarget
            ? await clientTTY(for: target, context: context, socketPath: socketPath)
            : nil

        Self.logger.notice(
            "Focus session \(session.sessionId.prefix(8), privacy: .public) target=\(target?.targetString ?? "nil", privacy: .public) socket=\(socketPath ?? "default", privacy: .public) clientTTY=\(clientTTY ?? "nil", privacy: .public) paneTTY=\(context.tty ?? "nil", privacy: .public) pid=\(context.pid.map(String.init) ?? "nil", privacy: .public) terminalPid=\(context.terminalPid.map(String.init) ?? "nil", privacy: .public) tmux=\(context.isInTmux, privacy: .public)"
        )

        if hasGhostty,
           await GhosttyController.shared.focusTerminal(
            workingDirectory: session.cwd,
            commandHint: commandHint(for: session),
            projectName: session.projectName,
            windowHint: session.windowHint
           ) {
            Self.logger.notice(
                "Focused Ghostty terminal for session \(session.sessionId.prefix(8), privacy: .public) via cwd match"
            )
            return true
        }

        if !isGhosttyTerminal,
           !context.isInTmux,
           hasITerm,
           let tty = context.tty,
           await ITerm2Controller.shared.focusSession(tty: tty) {
            Self.logger.notice(
                "Focused iTerm directly via tty \(tty, privacy: .public) for session \(session.sessionId.prefix(8), privacy: .public)"
            )
            return true
        }

        if hasTmuxTarget, let target {
            let switched = await TmuxController.shared.switchToPane(target: target, socketPath: socketPath, clientTTY: clientTTY)
            Self.logger.debug(
                "tmux switch result for session \(session.sessionId.prefix(8), privacy: .public): \(switched, privacy: .public)"
            )
        }

        if !isGhosttyTerminal,
           hasITerm,
           let clientTTY,
           await ITerm2Controller.shared.focusSession(tty: clientTTY) {
            Self.logger.notice(
                "Focused iTerm via clientTTY \(clientTTY, privacy: .public) for session \(session.sessionId.prefix(8), privacy: .public)"
            )
            return true
        }

        if !isGhosttyTerminal,
           hasITerm,
           let tty = context.tty,
           await ITerm2Controller.shared.focusSession(tty: tty) {
            Self.logger.notice(
                "Focused iTerm via context tty \(tty, privacy: .public) for session \(session.sessionId.prefix(8), privacy: .public)"
            )
            return true
        }

        if !isGhosttyTerminal,
           hasITerm,
           let target,
           let paneTTY = await TmuxTargetFinder.shared.tty(for: target, socketPath: socketPath),
           await ITerm2Controller.shared.focusSession(tty: paneTTY) {
            Self.logger.notice(
                "Focused iTerm via pane tty \(paneTTY, privacy: .public) for session \(session.sessionId.prefix(8), privacy: .public)"
            )
            return true
        }

        if let terminalPid = context.terminalPid,
           await TerminalAppController.shared.activate(processIdentifier: terminalPid) {
            Self.logger.notice(
                "Activated terminal app pid \(terminalPid, privacy: .public) for session \(session.sessionId.prefix(8), privacy: .public)"
            )
            return true
        }

        if hasITerm, await ITerm2Controller.shared.activate() {
            Self.logger.notice(
                "Activated iTerm as fallback for session \(session.sessionId.prefix(8), privacy: .public)"
            )
            return true
        }

        if let pid = context.pid {
            let focused = await YabaiController.shared.focusWindow(forSessionPid: pid)
            Self.logger.debug(
                "Yabai focus by pid result for session \(session.sessionId.prefix(8), privacy: .public): \(focused, privacy: .public)"
            )
            return focused
        }

        guard hasTmuxTarget else {
            Self.logger.notice(
                "Focus failed for session \(session.sessionId.prefix(8), privacy: .public): no tmux target and no pid"
            )
            return false
        }

        let focused = await YabaiController.shared.focusWindow(forWorkingDirectory: session.cwd)
        Self.logger.notice(
            "Yabai focus by cwd result for session \(session.sessionId.prefix(8), privacy: .public): \(focused, privacy: .public)"
        )
        return focused
    }

    func terminalLabel(session: SessionState) async -> String? {
        let cacheKey = terminalLabelCacheKey(for: session)
        if let cached = terminalLabelCache[cacheKey] {
            return cached
        }

        if let label = await TerminalAppController.shared.ancestorAppLabel(processIdentifier: session.pid) {
            terminalLabelCache[cacheKey] = label
            return label
        }

        if let label = await TerminalAppController.shared.appLabel(processIdentifier: session.pid) {
            terminalLabelCache[cacheKey] = label
            return label
        }

        return nil
    }

    func cachedTerminalLabel(session: SessionState) -> String? {
        terminalLabelCache[terminalLabelCacheKey(for: session)]
    }

    func prewarmTerminalLabels(for sessions: [SessionState]) async {
        for session in sessions {
            guard session.pid != nil else { continue }
            _ = await terminalLabel(session: session)
        }
    }

    private func commandHint(for session: SessionState) -> String? {
        switch session.provider {
        case .codex:
            return "codex"
        case .claude:
            return "claude"
        case .gemini:
            return "gemini"
        }
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

    private func clientTTY(for target: TmuxTarget?, context: SessionTerminalContext, socketPath: String?) async -> String? {
        guard let target else { return nil }

        if let tty = await TmuxTargetFinder.shared.clientTTY(forSessionName: target.session, socketPath: socketPath) {
            return tty
        }

        return context.tty
    }

    private func terminalLabelCacheKey(for session: SessionState) -> String {
        [
            session.provider.rawValue,
            session.sessionId,
            session.pid.map(String.init) ?? "nopid"
        ].joined(separator: "|")
    }
}
