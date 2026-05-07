//
//  CodexInstancesView.swift
//  CodeOrb
//
//  Minimal instances list matching Dynamic Island aesthetic
//

import Combine
import os.log
import SwiftUI

struct CodexInstancesView: View {
    @ObservedObject var sessionMonitor: CodexSessionMonitor
    @ObservedObject var viewModel: NotchViewModel

    private static let logger = Logger(subsystem: "com.codeorb", category: "InstancesView")

    var body: some View {
        if visibleInstances.isEmpty {
            emptyState
        } else {
            instancesList
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No sessions")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.4))

            Text("Run Codex, Claude Code, or Gemini CLI in terminal")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Instances List

    /// Keep one consistent ordering with the compact strip:
    /// actively running sessions first, then other attention states, and
    /// newest activity first within each bucket.
    private var visibleInstances: [SessionState] {
        sessionMonitor.instances.filter { session in
            session.pid != nil ||
                session.tty != nil ||
                session.phase.isActive ||
                session.phase.isWaitingForApproval
        }
    }

    private var sortedInstances: [SessionState] {
        visibleInstances.sorted { a, b in
            let priorityA = phasePriority(a.phase)
            let priorityB = phasePriority(b.phase)
            if priorityA != priorityB {
                return priorityA < priorityB
            }

            if a.lastActivity != b.lastActivity {
                return a.lastActivity > b.lastActivity
            }

            return a.projectName.localizedCaseInsensitiveCompare(b.projectName) == .orderedAscending
        }
    }

    /// Lower number = higher priority
    private func phasePriority(_ phase: SessionPhase) -> Int {
        switch phase {
        case .processing: return 0
        case .compacting: return 1
        case .waitingForApproval: return 2
        case .waitingForInput: return 3
        case .idle: return 4
        case .ended: return 5
        }
    }

    private var instancesList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(sortedInstances) { session in
                    InstanceRow(
                        session: session,
                        onFocus: { focusSession(session) },
                        onChat: { openChat(session) },
                        onArchive: { archiveSession(session) },
                        onApprove: { approveSession(session) },
                        onReject: { rejectSession(session) }
                    )
                    .id(session.stableId)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Actions

    private func focusSession(_ session: SessionState) {
        Task {
            Self.logger.notice(
                "Focus requested for session \(session.sessionId.prefix(8), privacy: .public) pid=\(session.pid.map(String.init) ?? "nil", privacy: .public) tty=\(session.tty ?? "nil", privacy: .public) storedTmux=\(session.isInTmux, privacy: .public) cwd=\(session.cwd, privacy: .public)"
            )

            await MainActor.run {
                viewModel.notchClose()
            }

            try? await Task.sleep(nanoseconds: 120_000_000)
            let didFocus = await TerminalLocator.shared.focus(session: session)
            Self.logger.notice(
                "Focus result for session \(session.sessionId.prefix(8), privacy: .public): \(didFocus, privacy: .public)"
            )
        }
    }

    private func openChat(_ session: SessionState) {
        viewModel.showChat(for: session)
    }

    private func approveSession(_ session: SessionState) {
        sessionMonitor.approvePermission(sessionId: session.sessionId)
    }

    private func rejectSession(_ session: SessionState) {
        sessionMonitor.denyPermission(sessionId: session.sessionId, reason: nil)
    }

    private func archiveSession(_ session: SessionState) {
        sessionMonitor.archiveSession(sessionId: session.sessionId)
    }
}

// MARK: - Instance Row

struct InstanceRow: View {
    let session: SessionState
    let onFocus: () -> Void
    let onChat: () -> Void
    let onArchive: () -> Void
    let onApprove: () -> Void
    let onReject: () -> Void

    @State private var isHovered = false
    @State private var isLocatorAvailable = false
    @State private var terminalLabel: String?
    @State private var pendingFocusWorkItem: DispatchWorkItem?

    private static let logger = Logger(subsystem: "com.codeorb", category: "InstanceRow")

    private var locatorAvailabilityKey: String {
        [
            session.pid.map(String.init) ?? "nopid",
            session.tty ?? "notty",
            session.transcriptPath ?? "notranscript",
            session.cwd,
            session.provider.rawValue,
            String(Int(session.lastActivity.timeIntervalSince1970))
        ].joined(separator: "|")
    }

    private var optimisticLocatorAvailability: Bool {
        session.pid != nil
            || session.transcriptPath != nil
            || session.tty != nil
            || session.isInTmux
    }

    private let runningColor = Color(red: 0.18, green: 0.76, blue: 0.96)
    private let compactingColor = Color(red: 0.79, green: 0.47, blue: 0.96)

    /// Whether we're showing the approval UI
    private var isWaitingForApproval: Bool {
        session.phase.isWaitingForApproval
    }

    /// Whether the pending tool requires interactive input (not just approve/deny)
    private var isInteractiveTool: Bool {
        guard let toolName = session.pendingToolName else { return false }
        return toolName == "AskUserQuestion"
    }

    /// Status text based on session phase (fallback when no other content)
    private var phaseStatusText: String {
        switch session.phase {
        case .processing:
            return "Processing..."
        case .compacting:
            return "Compacting..."
        case .waitingForInput:
            return "Ready"
        case .waitingForApproval:
            return "Waiting for approval"
        case .idle:
            return "Idle"
        case .ended:
            return "Ended"
        }
    }

    private var conversationLabel: String? {
        let title = session.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title != session.projectName else { return nil }

        if shouldHideConversationLabel(title: title, lastMessage: session.lastMessage) {
            return nil
        }

        return title
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                stateIndicator
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(session.projectName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(2)

                        Text(session.provider.badgeText)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .fixedSize(horizontal: true, vertical: false)

                        if let terminalLabel, !terminalLabel.isEmpty {
                            Text(terminalLabel)
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.44))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.05))
                                .clipShape(Capsule())
                                .frame(maxWidth: 170, alignment: .leading)
                        }

                        Spacer(minLength: 4)

                        if session.usage.totalTokens > 0 {
                            Text(session.usage.formattedTotal)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.3))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    if let conversationLabel {
                        Text(conversationLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.38))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    if isWaitingForApproval, let toolName = session.pendingToolName {
                        HStack(spacing: 4) {
                            Text(MCPToolFormatter.formatToolName(toolName))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(TerminalColors.amber.opacity(0.9))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            if isInteractiveTool {
                                Text("Needs your input")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                                    .lineLimit(1)
                            } else if let input = session.pendingToolInput {
                                Text(input)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    } else if let role = session.lastMessageRole {
                        switch role {
                        case "tool":
                            HStack(spacing: 4) {
                                if let toolName = session.lastToolName {
                                    Text(MCPToolFormatter.formatToolName(toolName))
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.5))
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                if let input = session.lastMessage {
                                    Text(input)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.4))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                        case "user":
                            HStack(spacing: 4) {
                                Text("You:")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                if let msg = session.lastMessage {
                                    Text(msg)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.4))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                        default:
                            if let msg = session.lastMessage {
                                Text(msg)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.4))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    } else if let lastMsg = session.lastMessage {
                        Text(lastMsg)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else {
                        Text(phaseStatusText)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if session.supportsChatHistory {
                    Self.logger.debug(
                        "Row single tap opening panel for session \(session.sessionId.prefix(8), privacy: .public)"
                    )
                    onChat()
                    return
                }

                guard isLocatorAvailable else {
                    Self.logger.debug(
                        "Row single tap ignored for session \(session.sessionId.prefix(8), privacy: .public) because locator is unavailable and chat is unsupported"
                    )
                    return
                }

                Self.logger.debug(
                    "Row single tap falling back to terminal focus for session \(session.sessionId.prefix(8), privacy: .public)"
                )
                scheduleFocus()
            }
            .onTapGesture(count: 2) {
                pendingFocusWorkItem?.cancel()
                guard session.supportsChatHistory else { return }
                Self.logger.debug(
                    "Row double tap opening panel for session \(session.sessionId.prefix(8), privacy: .public)"
                )
                onChat()
            }

            Spacer(minLength: 0)

            // Action icons or approval buttons
            if isWaitingForApproval && isInteractiveTool {
                // Interactive tools like AskUserQuestion - show chat + terminal buttons
                HStack(spacing: 8) {
                    if session.supportsChatHistory {
                        IconButton(icon: "bubble.left") {
                            onChat()
                        }
                    }

                    LocatorButton(
                        isEnabled: isLocatorAvailable,
                        onTap: { onFocus() }
                    )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else if isWaitingForApproval {
                InlineApprovalButtons(
                    onChat: session.supportsChatHistory ? onChat : {},
                    showsChatButton: session.supportsChatHistory,
                    onApprove: onApprove,
                    onReject: onReject
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                HStack(spacing: 8) {
                    if session.supportsChatHistory {
                        IconButton(icon: "bubble.left") {
                            onChat()
                        }
                    }

                    LocatorButton(
                        isEnabled: isLocatorAvailable,
                        onTap: { onFocus() }
                    )

                    // Archive button - only for idle or completed sessions
                    if session.phase == .idle || session.phase == .waitingForInput {
                        IconButton(icon: "archivebox") {
                            onArchive()
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isWaitingForApproval)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
        )
        .onHover { isHovered = $0 }
        .task(id: locatorAvailabilityKey) {
            isLocatorAvailable = optimisticLocatorAvailability
            Self.logger.debug(
                "Locator availability for session \(session.sessionId.prefix(8), privacy: .public): \(isLocatorAvailable, privacy: .public) pid=\(session.pid.map(String.init) ?? "nil", privacy: .public) tty=\(session.tty ?? "nil", privacy: .public) storedTmux=\(session.isInTmux, privacy: .public) transcript=\(session.transcriptPath ?? "nil", privacy: .public) terminalLabel=\(terminalLabel ?? "nil", privacy: .public)"
            )
        }
        .task(id: terminalLabelTaskKey) {
            terminalLabel = await TerminalLocator.shared.cachedTerminalLabel(session: session)

            guard session.pid != nil else { return }
            guard terminalLabel == nil else { return }

            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }

            terminalLabel = await TerminalLocator.shared.terminalLabel(session: session)
        }
    }

    private func scheduleFocus() {
        pendingFocusWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            Self.logger.debug(
                "Deferred focus fired for session \(session.sessionId.prefix(8), privacy: .public)"
            )
            onFocus()
        }
        pendingFocusWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: workItem)
    }

    private func normalizedRowText(_ text: String?) -> String? {
        guard let text else { return nil }

        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()

        return normalized.isEmpty ? nil : normalized
    }

    private func shouldHideConversationLabel(title: String, lastMessage: String?) -> Bool {
        guard let normalizedTitle = normalizedRowText(title),
              let normalizedLastMessage = normalizedRowText(lastMessage) else {
            return false
        }

        return normalizedTitle == normalizedLastMessage
            || normalizedTitle.contains(normalizedLastMessage)
            || normalizedLastMessage.contains(normalizedTitle)
    }

    private var terminalLabelTaskKey: String {
        [
            session.pid.map(String.init) ?? "nopid",
            session.provider.rawValue,
            session.cwd
        ].joined(separator: "|")
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch session.phase {
        case .processing:
            ZStack {
                Circle()
                    .fill(runningColor)
                    .frame(width: 8, height: 8)
                Circle()
                    .stroke(runningColor.opacity(0.35), lineWidth: 3)
                    .frame(width: 12, height: 12)
            }
        case .compacting:
            ZStack {
                Circle()
                    .fill(compactingColor)
                    .frame(width: 8, height: 8)
                Circle()
                    .stroke(compactingColor.opacity(0.35), lineWidth: 3)
                    .frame(width: 12, height: 12)
            }
        case .waitingForApproval:
            ZStack {
                Circle()
                    .fill(TerminalColors.amber)
                    .frame(width: 8, height: 8)
                Circle()
                    .stroke(TerminalColors.amber.opacity(0.35), lineWidth: 3)
                    .frame(width: 12, height: 12)
            }
        case .waitingForInput:
            Circle()
                .fill(TerminalColors.green)
                .frame(width: 8, height: 8)
                .shadow(color: TerminalColors.green.opacity(0.45), radius: 6)
        case .idle, .ended:
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 8, height: 8)
        }
    }

}

// MARK: - Inline Approval Buttons

/// Compact inline approval buttons with staggered animation
struct InlineApprovalButtons: View {
    let onChat: () -> Void
    let showsChatButton: Bool
    let onApprove: () -> Void
    let onReject: () -> Void

    @State private var showChatButton = false
    @State private var showDenyButton = false
    @State private var showAllowButton = false

    var body: some View {
        HStack(spacing: 6) {
            if showsChatButton {
                IconButton(icon: "bubble.left") {
                    onChat()
                }
                .opacity(showChatButton ? 1 : 0)
                .scaleEffect(showChatButton ? 1 : 0.8)
            }

            Button {
                onReject()
            } label: {
                Text("Deny")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .opacity(showDenyButton ? 1 : 0)
            .scaleEffect(showDenyButton ? 1 : 0.8)

            Button {
                onApprove()
            } label: {
                Text("Allow")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .opacity(showAllowButton ? 1 : 0)
            .scaleEffect(showAllowButton ? 1 : 0.8)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.0)) {
                showChatButton = true
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.05)) {
                showDenyButton = true
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.1)) {
                showAllowButton = true
            }
        }
    }
}

// MARK: - Icon Button

struct IconButton: View {
    let icon: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isHovered ? .white.opacity(0.8) : .white.opacity(0.4))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.borderless)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Compact Terminal Button (inline in description)

struct CompactTerminalButton: View {
    let isEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            if isEnabled {
                onTap()
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "terminal")
                    .font(.system(size: 8, weight: .medium))
                Text("Go to Terminal")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isEnabled ? .white.opacity(0.9) : .white.opacity(0.3))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isEnabled ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Locator Button

struct LocatorButton: View {
    let isEnabled: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    private static let logger = Logger(subsystem: "com.codeorb", category: "LocatorButton")

    var body: some View {
        Button {
            Self.logger.notice("Locator button tapped enabled=\(isEnabled, privacy: .public)")
            onTap()
        } label: {
            ZStack {
                Image(systemName: "scope")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(iconColor)

                Circle()
                    .fill(iconColor)
                    .frame(width: 3.5, height: 3.5)
            }
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
            .scaleEffect(isEnabled && isHovered ? 1.06 : 1.0)
            .offset(y: isEnabled && isHovered ? -0.5 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.72), value: isHovered)
        }
        .buttonStyle(.borderless)
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onHover {
            isHovered = $0
            if $0 {
                Self.logger.debug("Locator button hovered enabled=\(isEnabled, privacy: .public)")
            }
        }
    }

    private var iconColor: Color {
        if !isEnabled {
            return .white.opacity(0.26)
        }
        return isHovered ? .white.opacity(0.92) : .white.opacity(0.72)
    }

    private var backgroundColor: Color {
        if !isEnabled {
            return Color.white.opacity(0.03)
        }
        return isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.06)
    }

    private var borderColor: Color {
        if !isEnabled {
            return Color.white.opacity(0.04)
        }
        return isHovered ? Color.white.opacity(0.16) : Color.white.opacity(0.08)
    }
}
