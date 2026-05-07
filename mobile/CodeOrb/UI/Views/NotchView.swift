//
//  NotchView.swift
//  CodeOrb
//
//  The main dynamic island SwiftUI view with accurate notch shape
//

import AppKit
import CoreGraphics
import SwiftUI

// Corner radius constants
private let cornerRadiusInsets = (
    opened: (top: CGFloat(19), bottom: CGFloat(24)),
    closed: (top: CGFloat(6), bottom: CGFloat(14))
)

struct NotchView: View {
    private let compactOrbVisualDiameter: CGFloat = 64
    // Keep extra halo room on the left edge where clipping is most visible.
    // When the orb is standalone, reserve the same room on the right so the
    // thumbnail looks centered instead of visually cropped.
    private let compactOrbLeadingGlowInset: CGFloat = 24
    private let compactOrbAttachedTrailingGlowInset: CGFloat = 3
    private let compactOrbStandaloneTrailingGlowInset: CGFloat = 24
    private let compactOrbSpacing: CGFloat = 10
    private let compactContainerHorizontalPadding: CGFloat = 12
    private let compactStripHorizontalPadding: CGFloat = 24

    private func compactOrbTrailingGlowInset(hasActivityStrip: Bool) -> CGFloat {
        hasActivityStrip ? compactOrbAttachedTrailingGlowInset : compactOrbStandaloneTrailingGlowInset
    }

    private func compactOrbFootprintWidth(hasActivityStrip: Bool) -> CGFloat {
        compactOrbVisualDiameter + compactOrbLeadingGlowInset + compactOrbTrailingGlowInset(hasActivityStrip: hasActivityStrip)
    }

    private func compactOrbFootprintOffsetX(hasActivityStrip: Bool) -> CGFloat {
        (compactOrbLeadingGlowInset - compactOrbTrailingGlowInset(hasActivityStrip: hasActivityStrip)) * 0.5
    }

    private var compactOrbMinimumWindowWidth: CGFloat {
        compactOrbFootprintWidth(hasActivityStrip: false) + compactContainerHorizontalPadding
    }

    private enum CompactOrbState {
        case waitingForApproval
        case processing
        case waitingForInput
        case idle
    }

    private enum CompactActivityKind: Equatable {
        case approval
        case processing
        case compacting
        case ready
    }

    private struct CompactActivitySummary: Equatable, Identifiable {
        let id: String
        let sourceStableId: String
        let badge: String
        let text: String
        let kind: CompactActivityKind
    }

    @ObservedObject var viewModel: NotchViewModel
    @StateObject private var sessionMonitor = CodexSessionMonitor()
    @StateObject private var activityCoordinator = NotchActivityCoordinator.shared
    @ObservedObject private var updateManager = UpdateManager.shared
    @AppStorage("compactActivityStripEnabled") private var compactActivityStripEnabled = true
    @AppStorage("compactActivityStripAutoHideSeconds") private var compactActivityStripAutoHideSeconds = ActivityStripAutoHideOption.default.rawValue
    @AppStorage("compactActivityStripAdaptiveWidthEnabled") private var compactActivityStripAdaptiveWidthEnabled = true
    @AppStorage("compactActivityStripMinWidth") private var compactActivityStripMinWidth = CompactActivityStripMinWidthOption.default.rawValue
    @AppStorage("compactActivityStripMaxWidth") private var compactActivityStripMaxWidth = CompactActivityStripMaxWidthOption.default.rawValue
    @AppStorage("floatingWindowOpacity") private var floatingWindowOpacity = FloatingWindowOpacityOption.default.rawValue
    @State private var previousPendingIds: Set<String> = []
    @State private var previousWaitingForInputIds: Set<String> = []
    @State private var waitingForInputTimestamps: [String: Date] = [:]  // sessionId -> when it entered waitingForInput
    @State private var isVisible: Bool = false
    @State private var isHovering: Bool = false
    @State private var isBouncing: Bool = false
    @State private var isReadyCelebrating: Bool = false
    @State private var readyCelebrationToken: Int = 0
    @State private var cachedCompactActivitySummaries: [CompactActivitySummary] = []
    @State private var cachedCompactActivityStripWidth: CGFloat = 0
    @State private var compactActivityStripCollapsed = false

    @Namespace private var activityNamespace
    private var waitingForInputVisibilityWindow: TimeInterval {
        compactActivityStripAutoHideSeconds
    }

    /// Whether any tracked session is currently processing or compacting
    private var isAnyProcessing: Bool {
        currentSessions.contains { $0.phase == .processing || $0.phase == .compacting }
    }

    /// Whether any tracked session has a pending permission request
    private var hasPendingPermission: Bool {
        currentSessions.contains { $0.phase.isWaitingForApproval }
    }

    /// Whether any tracked session is waiting for user input right now.
    private var hasWaitingForInput: Bool {
        currentSessions.contains { $0.phase == .waitingForInput }
    }

    /// Whether any session recently entered waiting-for-input, used only for transient celebratory UI.
    private var hasRecentWaitingForInput: Bool {
        currentSessions.contains { shouldShowWaitingSummary(for: $0) }
    }

    // MARK: - Sizing

    private var closedNotchSize: CGSize {
        CGSize(
            width: viewModel.deviceNotchRect.width,
            height: viewModel.deviceNotchRect.height
        )
    }

    /// Extra width for expanding activities (like Dynamic Island)
    private var expansionWidth: CGFloat {
        // Permission indicator adds width on left side only
        let permissionIndicatorWidth: CGFloat = hasPendingPermission ? 18 : 0

        // Expand for processing activity
        if activityCoordinator.expandingActivity.show {
            switch activityCoordinator.expandingActivity.type {
            case .codex:
                let baseWidth = 2 * max(0, closedNotchSize.height - 12) + 20
                return baseWidth + permissionIndicatorWidth
            case .none:
                break
    }
}

        // Expand for pending permissions (left indicator) or waiting for input (checkmark on right)
        if hasPendingPermission {
            return 2 * max(0, closedNotchSize.height - 12) + 20 + permissionIndicatorWidth
        }

        // Waiting for input just shows checkmark on right, no extra left indicator
        if hasRecentWaitingForInput {
            return 2 * max(0, closedNotchSize.height - 12) + 20
        }

        return 0
    }

    private var notchSize: CGSize {
        switch viewModel.status {
        case .closed, .popping:
            return closedNotchSize
        case .opened:
            return viewModel.openedSize
        }
    }

    /// Width of the closed content (notch + any expansion)
    private var closedContentWidth: CGFloat {
        closedNotchSize.width + expansionWidth
    }

    // MARK: - Corner Radii

    private var topCornerRadius: CGFloat {
        viewModel.status == .opened
            ? cornerRadiusInsets.opened.top
            : cornerRadiusInsets.closed.top
    }

    private var bottomCornerRadius: CGFloat {
        viewModel.status == .opened
            ? cornerRadiusInsets.opened.bottom
            : cornerRadiusInsets.closed.bottom
    }

    private var currentNotchShape: NotchShape {
        NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius
        )
    }

    // Animation springs
    private let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
    private let closeAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)

    private var windowTitle: String {
        switch viewModel.contentType {
        case .instances:
            return "Sessions"
        case .menu:
            return "Settings"
        case .chat(let session):
            return session.displayTitle
        }
    }

    private var windowSubtitle: String {
        if hasPendingPermission {
            return "A session needs approval"
        }
        if isAnyProcessing {
            return sessionCountSummaryText
        }
        if hasWaitingForInput {
            return "Waiting for your next prompt"
        }
        return "\(activeSessionCount) tracked session\(activeSessionCount == 1 ? "" : "s")"
    }

    private var activeSessionCount: Int {
        currentSessions.count
    }

    private var runningSessionCount: Int {
        currentSessions.filter { $0.phase == .processing || $0.phase == .compacting }.count
    }

    private var runningMascotProviders: [SessionProviderKind] {
        currentSessions
            .filter { $0.phase == .processing || $0.phase == .compacting }
            // Keep orbit assignment stable while the right-side activity text/spinner
            // updates, otherwise planets reshuffle every time lastActivity changes.
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.sessionId < rhs.sessionId
            }
            .map(\.provider)
    }

    private var sessionCountSummaryText: String {
        "\(runningSessionCount) running, \(activeSessionCount) active"
    }

    private var currentSessions: [SessionState] {
        sessionMonitor.instances.filter { session in
            session.pid != nil ||
                session.tty != nil ||
                session.phase.isActive ||
                session.phase.isWaitingForApproval
        }
    }

    private var compactSurfaceOpacity: Double {
        floatingWindowOpacity
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.09, blue: 0.11),
                        Color(red: 0.04, green: 0.05, blue: 0.06),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 24, y: 16)
            .opacity(floatingWindowOpacity)
    }

    private var compactOrbState: CompactOrbState {
        if hasPendingPermission {
            return .waitingForApproval
        }
        if isAnyProcessing {
            return .processing
        }
        if hasWaitingForInput {
            return .waitingForInput
        }
        return .idle
    }

    private var compactOrbStatusColor: Color {
        switch compactOrbState {
        case .waitingForApproval:
            return Color.black.opacity(0.9)
        case .processing:
            return Color.black.opacity(0.9)
        case .waitingForInput:
            return TerminalColors.green
        case .idle:
            return Color.white.opacity(0.35)
        }
    }

    private var compactOrbStatusText: String {
        switch compactOrbState {
        case .waitingForApproval:
            return "ASK"
        case .processing:
            return "RUN"
        case .waitingForInput:
            return "READY"
        case .idle:
            return "IDLE"
        }
    }

    private var orbAccentColor: Color {
        compactOrbStatusColor
    }

    private var compactOrbBadgeText: String? {
        switch compactOrbState {
        case .processing:
            guard runningSessionCount > 0 else { return nil }
            return runningSessionCount > 9 ? "9+" : "\(runningSessionCount)"
        case .waitingForApproval:
            return "!"
        case .waitingForInput:
            return "OK"
        case .idle:
            return nil
        }
    }

    private var compactOrbBadgeColor: Color {
        switch compactOrbState {
        case .waitingForApproval:
            return Color.black.opacity(0.92)
        case .processing:
            return Color.black.opacity(0.92)
        case .waitingForInput:
            return TerminalColors.green
        case .idle:
            return Color.white.opacity(0.28)
        }
    }

    private var compactOrbBadgeTextColor: Color {
        switch compactOrbState {
        case .waitingForApproval, .processing:
            return .white.opacity(0.92)
        case .waitingForInput:
            return .black.opacity(0.88)
        case .idle:
            return .white.opacity(0.9)
        }
    }

    private var compactActivitySummaries: [CompactActivitySummary] {
        cachedCompactActivitySummaries
    }

    private var prioritizedPendingApprovalSession: SessionState? {
        sessionMonitor.pendingInstances.sorted { lhs, rhs in
            if lhs.lastActivity != rhs.lastActivity {
                return lhs.lastActivity > rhs.lastActivity
            }
            return lhs.sessionId < rhs.sessionId
        }.first
    }

    private func computedCompactActivitySummaries() -> [CompactActivitySummary] {
        guard compactActivityStripEnabled else { return [] }

        let prioritizedSessions = currentSessions.sorted { lhs, rhs in
            let lhsPriority = compactSessionPriority(lhs)
            let rhsPriority = compactSessionPriority(rhs)
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.lastActivity > rhs.lastActivity
        }

        return prioritizedSessions.flatMap { session in
            if session.phase == .waitingForInput && !shouldShowWaitingSummary(for: session) {
                return [CompactActivitySummary]()
            }
            return compactActivitySummaries(for: session)
        }
    }

    private func shouldShowWaitingSummary(for session: SessionState) -> Bool {
        guard session.phase == .waitingForInput else { return false }

        if waitingForInputVisibilityWindow <= 0 {
            return true
        }

        guard let enteredAt = waitingForInputTimestamps[session.stableId] else {
            return false
        }

        return Date().timeIntervalSince(enteredAt) < waitingForInputVisibilityWindow
    }

    private var visibleCompactActivitySummaries: [CompactActivitySummary] {
        guard !compactActivityStripCollapsed else { return [] }
        return visibleCompactActivitySummaries(for: compactActivitySummaries)
    }

    private func visibleCompactActivitySummaries(for allSummaries: [CompactActivitySummary]) -> [CompactActivitySummary] {
        let maxVisibleCount = 3

        guard allSummaries.count > maxVisibleCount else { return allSummaries }

        let primarySummaries = allSummaries.filter { $0.kind != .ready }
        let readySummaries = allSummaries
            .enumerated()
            .filter { $0.element.kind == .ready }
            .sorted { lhs, rhs in
                let lhsTimestamp = waitingForInputTimestamps[lhs.element.sourceStableId] ?? .distantPast
                let rhsTimestamp = waitingForInputTimestamps[rhs.element.sourceStableId] ?? .distantPast
                if lhsTimestamp != rhsTimestamp {
                    return lhsTimestamp > rhsTimestamp
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)

        let visiblePrimary = Array(primarySummaries.prefix(maxVisibleCount))
        let remainingSlots = max(0, maxVisibleCount - visiblePrimary.count)

        guard remainingSlots > 0 else { return visiblePrimary }
        return visiblePrimary + Array(readySummaries.prefix(remainingSlots))
    }

    private var hiddenCompactActivityCount: Int {
        guard !compactActivityStripCollapsed else { return 0 }
        return max(0, compactActivitySummaries.count - visibleCompactActivitySummaries.count)
    }

    private var compactActivityFooterText: String? {
        guard !compactActivityStripCollapsed else { return nil }
        guard !compactActivitySummaries.isEmpty else { return nil }
        return sessionCountSummaryText
    }

    private var visibleCompactActivitySummaryIDs: [String] {
        visibleCompactActivitySummaries.map(\.id)
    }

    private func compactActivitySummaries(for session: SessionState) -> [CompactActivitySummary] {
        switch session.phase {
        case .waitingForApproval:
            let badge = session.pendingToolName == "AskUserQuestion" ? "INPUT" : "APPROVE"
            let toolLabel = session.pendingToolName.map(MCPToolFormatter.formatToolName) ?? "Permission"
            let detail = session.pendingToolInput ?? toolLabel
            return [CompactActivitySummary(
                id: "\(session.sessionId)-approval",
                sourceStableId: session.stableId,
                badge: badge,
                text: compactActivityLine(projectName: session.projectName, detail: "\(toolLabel) · \(detail)"),
                kind: .approval
            )]

        case .processing:
            return processingActivitySummaries(for: session)

        case .compacting:
            return [CompactActivitySummary(
                id: "\(session.sessionId)-compacting",
                sourceStableId: session.stableId,
                badge: "PACK",
                text: compactActivityLine(projectName: session.projectName, detail: "Compacting context"),
                kind: .compacting
            )]

        case .waitingForInput:
            return [CompactActivitySummary(
                id: "\(session.sessionId)-ready",
                sourceStableId: session.stableId,
                badge: "READY",
                text: compactActivityLine(
                    projectName: compactProjectName(for: session),
                    detail: compactReadyDetail(for: session)
                ),
                kind: .ready
            )]

        case .idle, .ended:
            return []
        }
    }

    private func processingActivitySummaries(for session: SessionState) -> [CompactActivitySummary] {
        let latestUserPrompt: (summary: CompactActivitySummary, timestamp: Date)? = {
            let latestUserItem = session.chatItems
                .sorted { lhs, rhs in lhs.timestamp > rhs.timestamp }
                .first { item in
                    if case .user = item.type {
                        return true
                    }
                    return false
                }

            if let latestUserItem,
               case .user(let text) = latestUserItem.type,
               let prompt = normalizedCompactText(text) {
                return (
                    CompactActivitySummary(
                        id: "\(session.sessionId)-prompt-\(latestUserItem.id)",
                        sourceStableId: session.stableId,
                        badge: "YOU",
                        text: compactActivityLine(projectName: compactProjectName(for: session), detail: prompt),
                        kind: .processing
                    ),
                    latestUserItem.timestamp
                )
            }

            guard session.lastMessageRole == "user",
                  let prompt = normalizedCompactText(session.lastMessage) else {
                return nil
            }

            return (
                CompactActivitySummary(
                    id: "\(session.sessionId)-prompt",
                    sourceStableId: session.stableId,
                    badge: "YOU",
                    text: compactActivityLine(projectName: compactProjectName(for: session), detail: prompt),
                    kind: .processing
                ),
                session.lastUserMessageDate ?? session.lastActivity
            )
        }()

        let activeTasks = session.subagentState.activeTasks.values.sorted { lhs, rhs in
            lhs.startTime > rhs.startTime
        }

        if !activeTasks.isEmpty {
            let summaries = activeTasks.map { activeTask in
                let description = normalizedCompactText(activeTask.description)
                    ?? normalizedCompactText(session.subagentState.agentDescriptions[activeTask.agentId ?? ""])
                    ?? "Running agent"
                let toolSuffix = activeTask.subagentTools
                    .last(where: { $0.status == .running || $0.status == .waitingForApproval })
                    .map { " · \($0.displayText)" } ?? ""

                return CompactActivitySummary(
                    id: "\(session.sessionId)-task-\(activeTask.taskToolId)",
                    sourceStableId: session.stableId,
                    badge: "RUN",
                    text: compactActivityLine(
                        projectName: compactProjectName(for: session),
                        detail: "\(description)\(toolSuffix)"
                    ),
                    kind: .processing
                )
            }
            return Array(summaries.prefix(3))
        }

        let activeTools = session.toolTracker.inProgress.values.sorted { lhs, rhs in
            lhs.startTime > rhs.startTime
        }

        if !activeTools.isEmpty {
            let summaries = activeTools.map { activeTool in
                let toolSummary = session.chatItems.first { $0.id == activeTool.id }.flatMap { item -> CompactActivitySummary? in
                    guard case .toolCall(let tool) = item.type else { return nil }
                    return compactToolActivitySummary(
                        for: tool,
                        activityId: item.id,
                        session: session
                    )
                }

                return CompactActivitySummary(
                    id: toolSummary?.id ?? "\(session.sessionId)-tool-\(activeTool.id)",
                    sourceStableId: session.stableId,
                    badge: toolSummary?.badge ?? "RUN",
                    text: toolSummary?.text ?? compactActivityLine(
                        projectName: compactProjectName(for: session),
                        detail: MCPToolFormatter.formatToolName(activeTool.name)
                    ),
                    kind: .processing
                )
            }
            return Array(summaries.prefix(3))
        }

        let recentToolSummaries = recentCompactToolActivitySummaries(for: session)
        let latestRecentToolTimestamp = session.chatItems
            .sorted { lhs, rhs in lhs.timestamp > rhs.timestamp }
            .first { item in
                if case .toolCall = item.type {
                    return true
                }
                return false
            }?
            .timestamp

        if let latestUserPrompt,
           latestRecentToolTimestamp == nil || latestUserPrompt.timestamp >= latestRecentToolTimestamp! {
            return [latestUserPrompt.summary]
        }

        if !recentToolSummaries.isEmpty {
            return Array(recentToolSummaries.prefix(1))
        }

        if let latestUserPrompt {
            return [latestUserPrompt.summary]
        }

        let fallbackDetail = processingDetail(for: session)
        return [
            CompactActivitySummary(
                id: "\(session.sessionId)-processing",
                sourceStableId: session.stableId,
                badge: "RUN",
                text: compactActivityLine(projectName: compactProjectName(for: session), detail: fallbackDetail),
                kind: .processing
            )
        ]
    }

    private var compactWindowTargetSize: CGSize {
        let hasActivityStrip = !visibleCompactActivitySummaries.isEmpty
        return CGSize(
            width: hasActivityStrip
                ? compactOrbFootprintWidth(hasActivityStrip: true) + compactOrbSpacing + compactActivityStripWidth + compactContainerHorizontalPadding
                : compactOrbMinimumWindowWidth,
            height: 140
        )
    }

    private var compactActivityStripWidth: CGFloat {
        cachedCompactActivityStripWidth
    }

    private func measuredCompactActivityStripWidth(
        for summaries: [CompactActivitySummary],
        hiddenCount: Int
    ) -> CGFloat {
        guard !summaries.isEmpty else { return 0 }

        let badgeFont = NSFont.systemFont(ofSize: 9, weight: .black)
        let textFont = NSFont.systemFont(ofSize: 11, weight: .medium)
        let overflowFont = NSFont.systemFont(ofSize: 10, weight: .semibold)
        let footerFont = NSFont.systemFont(ofSize: 10, weight: .semibold)

        let rowWidths = summaries.map { summary in
            measuredCompactBadgeWidth(summary.badge, font: badgeFont)
                + 8
                + measuredCompactTextWidth(summary.text, font: textFont)
        }

        let overflowWidth: CGFloat
        if hiddenCount > 0 {
            overflowWidth = measuredCompactTextWidth("+\(hiddenCount) more active", font: overflowFont) + 4
        } else {
            overflowWidth = 0
        }

        let footerWidth = compactActivityFooterText.map {
            measuredCompactTextWidth($0, font: footerFont) + 4
        } ?? 0

        let contentWidth = max(rowWidths.max() ?? 0, overflowWidth, footerWidth)
        let contentDrivenMinWidth: CGFloat
        if hiddenCount > 0 || summaries.count >= 3 {
            contentDrivenMinWidth = 300
        } else if summaries.count == 2 {
            contentDrivenMinWidth = 260
        } else {
            contentDrivenMinWidth = 220
        }
        let configuredMinWidth = CGFloat(compactActivityStripMinWidth)
        let configuredMaxWidth = max(CGFloat(compactActivityStripMaxWidth), configuredMinWidth)
        let minWidth = compactActivityStripAdaptiveWidthEnabled
            ? max(contentDrivenMinWidth, configuredMinWidth)
            : configuredMaxWidth

        // Let the strip grow with content, but keep a firm upper bound so the
        // compact window does not sprawl too far across the notch area.
        let screenWidth = max(viewModel.screenRect.width, minWidth)
        let preferredMaxWidth = min(screenWidth * 0.62, screenWidth - 180)
        let maxWidth = max(minWidth, min(preferredMaxWidth, configuredMaxWidth))
        let baseWidth = compactActivityStripAdaptiveWidthEnabled
            ? (contentWidth + compactStripHorizontalPadding)
            : maxWidth
        let measuredWidth = min(max(baseWidth, minWidth), maxWidth)

        // Quantize width changes a bit so the compact window doesn't jitter on
        // every single character update.
        return ceil(measuredWidth / 8) * 8
    }

    private func refreshCompactActivityDisplay() {
        let allSummaries = computedCompactActivitySummaries()
        let visibleSummaries = visibleCompactActivitySummaries(for: allSummaries)
        let hiddenCount = max(0, allSummaries.count - visibleSummaries.count)
        let measuredWidth = measuredCompactActivityStripWidth(for: visibleSummaries, hiddenCount: hiddenCount)

        if cachedCompactActivitySummaries != allSummaries {
            cachedCompactActivitySummaries = allSummaries
        }

        if cachedCompactActivityStripWidth != measuredWidth {
            cachedCompactActivityStripWidth = measuredWidth
        }
    }

    private func measuredCompactBadgeWidth(_ text: String, font: NSFont) -> CGFloat {
        measuredCompactTextWidth(text, font: font) + 16
    }

    private func measuredCompactTextWidth(_ text: String, font: NSFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return ceil((text as NSString).size(withAttributes: attributes).width)
    }

    private func compactSessionPriority(_ session: SessionState) -> Int {
        switch session.phase {
        case .processing:
            return 0
        case .compacting:
            return 1
        case .waitingForApproval:
            return 2
        case .waitingForInput:
            return hasRecentWaitingForInput ? 3 : 4
        case .idle:
            return 5
        case .ended:
            return 6
        }
    }

    private func compactActivityLine(projectName: String, detail: String) -> String {
        "\(projectName) · \(detail)"
    }

    private func compactProjectName(for session: SessionState) -> String {
        let trimmed = session.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let normalizedCwd = URL(fileURLWithPath: session.cwd).standardizedFileURL.path

        if trimmed.isEmpty {
            return session.provider.displayName
        }

        if normalizedCwd == homeDirectory.path,
           trimmed.caseInsensitiveCompare(homeDirectory.lastPathComponent) == .orderedSame {
            return "Home"
        }

        return trimmed
    }

    private func compactReadyDetail(for session: SessionState) -> String {
        let latestConversationText = session.chatItems
            .sorted { lhs, rhs in lhs.timestamp > rhs.timestamp }
            .compactMap { item -> String? in
                switch item.type {
                case .user(let text):
                    return compactReadySummaryText(text, skipAutomationLogs: false)
                case .assistant(let text), .thinking(let text):
                    return compactReadySummaryText(text, skipAutomationLogs: true)
                case .toolCall, .image, .interrupted:
                    return nil
                }
            }
            .first

        if let latestConversationText {
            return latestConversationText
        }

        if let latestMessage = compactReadyFallbackMessage(for: session) {
            return latestMessage
        }

        if let firstPrompt = normalizedCompactText(session.firstUserMessage) {
            return firstPrompt
        }

        return "Ready for your next prompt"
    }

    private func compactReadyFallbackMessage(for session: SessionState) -> String? {
        guard let lastMessage = session.lastMessage else { return nil }

        switch session.lastMessageRole {
        case "user":
            return normalizedCompactText(lastMessage)
        case "assistant":
            return compactReadySummaryText(lastMessage, skipAutomationLogs: true)
        case "tool":
            return nil
        default:
            return compactReadySummaryText(lastMessage, skipAutomationLogs: true)
        }
    }

    private func compactReadySummaryText(_ text: String, skipAutomationLogs: Bool) -> String? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            guard let normalized = normalizedCompactText(line) else { continue }
            if skipAutomationLogs && looksLikeAutomationLog(normalized) {
                continue
            }
            return normalized
        }

        guard let normalized = normalizedCompactText(text) else {
            return nil
        }

        if skipAutomationLogs && looksLikeAutomationLog(normalized) {
            return nil
        }

        return normalized
    }

    private func looksLikeAutomationLog(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        if trimmed.contains("│") || trimmed.hasPrefix("• ") || trimmed.hasPrefix("└") {
            return true
        }

        let patterns = [
            #"^(?i)(ran|read|updated|edited|created|deleted|moved|checked|compiled|built|opened|restarted|registered|called|searched|fetched|wrote|using)\b"#,
            #"^[A-Z]{3,12}(?:\s|·)"#,
            #"^(?i)(tool|read|edit|web|cmd|agent|task|plan|todo|think|term|ask|info|fail)\s*[·:]"#,
        ]

        return patterns.contains { pattern in
            trimmed.range(of: pattern, options: .regularExpression) != nil
        }
    }

    private func recentCompactToolActivitySummaries(for session: SessionState) -> [CompactActivitySummary] {
        let orderedItems = session.chatItems.sorted { lhs, rhs in lhs.timestamp > rhs.timestamp }
        let mapped: [CompactActivitySummary] = orderedItems.compactMap { item in
            guard case .toolCall(let tool) = item.type else { return nil }
            return compactToolActivitySummary(
                for: tool,
                activityId: item.id,
                session: session
            )
        }

        let deduplicated = mapped.reduce(into: [CompactActivitySummary]()) { partialResult, summary in
            guard !partialResult.contains(where: { $0.text == summary.text }) else { return }
            partialResult.append(summary)
        }

        return Array(deduplicated.prefix(2))
    }

    private func compactAssistantBadge(for text: String, provider: SessionProviderKind) -> String {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let planningPrefixes = [
            "i'll", "i will", "i'm going to", "let me", "next", "continuing", "continue",
            "我继续", "我会", "我来", "我先", "接着", "继续", "下一步", "先把", "我准备"
        ]
        if planningPrefixes.contains(where: { normalized.hasPrefix($0) }) {
            return "PLAN"
        }

        let thinkingPrefixes = [
            "checking", "looking into", "investigating", "let's see",
            "我看看", "我查下", "我看下", "我排查", "我确认下", "我确认一下"
        ]
        if thinkingPrefixes.contains(where: { normalized.hasPrefix($0) }) {
            return "THINK"
        }

        let notePrefixes = [
            "done", "fixed", "updated", "rebuilt", "restarted",
            "好了", "已", "已经", "修好了", "改好了", "重启了", "构建好了"
        ]
        if notePrefixes.contains(where: { normalized.hasPrefix($0) }) {
            return "NOTE"
        }

        switch provider {
        case .codex:
            return "CODEX"
        case .claude:
            return "CLAUDE"
        case .gemini:
            return "GEMINI"
        }
    }

    private func compactToolActivitySummary(
        for tool: ToolCallItem,
        activityId: String,
        session: SessionState
    ) -> CompactActivitySummary? {
        if shouldHideCompactToolActivity(for: tool) {
            return nil
        }

        guard let detail = compactToolActivityDetail(for: tool) else { return nil }
        return CompactActivitySummary(
            id: "\(session.sessionId)-activity-\(activityId)",
            sourceStableId: session.stableId,
            badge: compactToolActivityBadge(for: tool),
            text: compactActivityLine(projectName: compactProjectName(for: session), detail: detail),
            kind: .processing
        )
    }

    private func compactToolActivityBadge(for tool: ToolCallItem) -> String {
        compactToolActivityClassification(for: tool).badge
    }

    private func compactToolActivityDetail(for tool: ToolCallItem) -> String? {
        let preview = normalizedCompactText(tool.inputPreview)
        let label = MCPToolFormatter.formatToolName(tool.name)

        if tool.status == .waitingForApproval {
            return "Awaiting approval for \(preview ?? label)"
        }

        if tool.status == .interrupted {
            return "Stopped \(preview ?? label)"
        }

        if tool.status == .error {
            return compactFailedToolDetail(for: tool, label: label, preview: preview)
        }

        if let browserDetail = compactBrowserToolDetail(for: tool) {
            return browserDetail
        }

        switch tool.name {
        case "apply_patch":
            return compactApplyPatchDetail(for: tool)
        case "exec_command", "run_shell_command":
            return compactExecCommandDetail(for: tool)
        case "write_stdin":
            let hasChars = !(tool.input["chars"] ?? "").isEmpty
            return hasChars ? "terminal input" : "terminal output"
        case "Read", "read_file", "read_many_files", "list_directory":
            return preview ?? "file"
        case "Grep", "Glob", "grep_search", "glob":
            return preview ?? "files"
        case "Edit", "NotebookEdit", "replace":
            return preview ?? "file"
        case "Write", "write_file":
            return preview ?? "file"
        case "Bash", "SlashCommand":
            return preview ?? "command"
        case "AgentOutputTool", "complete_task":
            let detail = normalizedCompactText(tool.input["description"]) ?? preview ?? "agent"
            return detail
        case "Task", "Agent":
            let detail = normalizedCompactText(tool.input["description"]) ?? "agent task"
            return detail
        case "WebSearch", "google_web_search":
            return preview ?? "web"
        case "WebFetch", "web_fetch":
            return preview ?? "resource"
        case "update_plan":
            let structured = MCPToolFormatter.formatArgs(tool.input)
            return normalizedCompactText(structured) ?? preview ?? "plan update"
        case "TodoWrite", "TodoRead", "write_todos":
            return "todos"
        case "ask_user":
            return normalizedCompactText(tool.input["question"]) ?? preview ?? "user input"
        case "activate_skill":
            return preview ?? "skill"
        case "update_topic":
            return preview ?? "status update"
        case "tracker_create_task", "tracker_get_task", "tracker_list_tasks", "tracker_update_task", "tracker_add_dependency", "tracker_visualize":
            return preview ?? "task tracker"
        case "save_memory":
            return preview ?? "memory"
        case "get_internal_docs":
            return preview ?? "docs"
        case "enter_plan_mode", "exit_plan_mode":
            return preview ?? "plan mode"
        default:
            if let preview {
                return preview
            }
            return label
        }
    }

    private func compactFailedToolDetail(
        for tool: ToolCallItem,
        label: String,
        preview: String?
    ) -> String {
        switch tool.name {
        case "exec_command", "run_shell_command", "Bash", "SlashCommand", "BashOutput", "KillShell":
            let subject = compactFailureSubject(
                compactExecCommandDetail(for: tool),
                fallback: "command"
            )
            return "Failed \(subject)"
        default:
            return "Failed \(compactFailureSubject(preview, fallback: label))"
        }
    }

    private func compactFailureSubject(_ preview: String?, fallback: String) -> String {
        guard let preview = normalizedCompactText(preview) else {
            return fallback
        }

        let homeName = FileManager.default.homeDirectoryForCurrentUser.lastPathComponent
        if preview.caseInsensitiveCompare(homeName) == .orderedSame {
            return "home folder"
        }

        return preview
    }

    private func shouldHideCompactToolActivity(for tool: ToolCallItem) -> Bool {
        if tool.name == "write_stdin", (tool.input["chars"] ?? "").isEmpty {
            return true
        }
        return false
    }

    private func compactToolActivityClassification(for tool: ToolCallItem) -> (badge: String, category: String) {
        if isCompactBrowserTool(tool.name) {
            return ("WEB", "browser")
        }

        switch tool.name {
        case "apply_patch":
            return ("EDIT", "patch")
        case "exec_command", "run_shell_command":
            return compactExecCommandClassification(for: tool)
        case "write_stdin":
            return ("TERM", "terminal")
        case "Read", "read_file", "read_many_files", "list_directory":
            return ("READ", "read")
        case "Grep", "Glob", "grep_search", "glob":
            return ("READ", "inspect")
        case "Edit", "Write", "NotebookEdit", "replace", "write_file":
            return ("EDIT", "edit")
        case "Bash", "SlashCommand", "BashOutput", "KillShell":
            return ("CMD", "command")
        case "Task", "Agent", "AgentOutputTool", "complete_task":
            return ("AGENT", "agent")
        case "WebSearch", "WebFetch", "google_web_search", "web_fetch":
            return ("WEB", "web")
        case "TodoWrite", "TodoRead", "write_todos":
            return ("TODO", "todo")
        case "AskUserQuestion", "ask_user":
            return ("ASK", "input")
        case "activate_skill", "save_memory", "get_internal_docs":
            return ("THINK", "memory")
        case "enter_plan_mode", "exit_plan_mode":
            return ("PLAN", "plan")
        case "update_topic":
            return ("INFO", "status")
        case "tracker_create_task", "tracker_get_task", "tracker_list_tasks", "tracker_update_task", "tracker_add_dependency", "tracker_visualize":
            return ("TASK", "tracker")
        default:
            return (tool.status == .error ? "FAIL" : "TOOL", "tool")
        }
    }

    private func isCompactBrowserTool(_ toolName: String) -> Bool {
        let action = compactBrowserToolActionName(toolName)
        return toolName.hasPrefix("chrome-devtools.")
            || toolName.hasPrefix("browser.")
            || toolName.contains("chrome_devtools")
            || toolName.contains("browser_bridge")
            || compactBrowserActionNames.contains(action)
    }

    private func compactBrowserToolDetail(for tool: ToolCallItem) -> String? {
        guard isCompactBrowserTool(tool.name) else { return nil }

        let action = compactBrowserToolActionName(tool.name)
        let selectorPreview = compactBrowserSelectorPreview(tool.input)
        let targetText = normalizedCompactText(tool.input["text"])
        let urlText = normalizedCompactText(tool.input["url"])

        switch action {
        case "take_snapshot":
            return "page snapshot"
        case "take_screenshot":
            return "page screenshot"
        case "click", "click_element":
            return selectorPreview.map { "click \($0)" } ?? "page click"
        case "hover":
            return selectorPreview.map { "hover \($0)" } ?? "page hover"
        case "drag":
            return "drag page element"
        case "fill", "fill_form", "type_text", "press_key":
            return selectorPreview.map { "input \($0)" } ?? "page input"
        case "navigate_page", "new_page":
            if let urlText {
                return compactBrowserURLDetail(urlText)
            }
            if let navigationType = normalizedCompactText(tool.input["type"]) {
                return compactBrowserNavigationDetail(type: navigationType)
            }
            return "browser page"
        case "wait_for":
            return targetText.map { "wait for \($0)" } ?? "page update"
        case "get_network_request", "list_network_requests":
            return "network request"
        case "get_console_message", "list_console_messages", "get_console_logs":
            return "console logs"
        case "get_page_content", "get_dom_structure":
            return "page structure"
        case "get_element_text":
            return selectorPreview.map { "read \($0)" } ?? "page text"
        case "get_all_links":
            return "page links"
        case "get_all_images":
            return "page images"
        case "get_page_info", "list_pages", "select_page":
            return "browser tabs"
        default:
            return "browser activity"
        }
    }

    private func compactBrowserToolActionName(_ toolName: String) -> String {
        if let suffix = toolName.split(separator: ".").last {
            let dottedSuffix = String(suffix)
            if compactBrowserActionNames.contains(dottedSuffix) {
                return dottedSuffix
            }
        }

        if let range = toolName.range(of: "chrome_devtools__") {
            return String(toolName[range.upperBound...])
        }

        if let range = toolName.range(of: "browser_bridge__") {
            return String(toolName[range.upperBound...])
        }

        if let suffix = toolName.components(separatedBy: "__").last,
           compactBrowserActionNames.contains(suffix) {
            return suffix
        }

        return toolName
    }

    private var compactBrowserActionNames: Set<String> {
        [
            "take_snapshot",
            "take_screenshot",
            "click",
            "click_element",
            "hover",
            "drag",
            "fill",
            "fill_form",
            "type_text",
            "press_key",
            "navigate_page",
            "new_page",
            "wait_for",
            "get_network_request",
            "list_network_requests",
            "get_console_message",
            "list_console_messages",
            "get_console_logs",
            "get_page_content",
            "get_dom_structure",
            "get_element_text",
            "get_all_links",
            "get_all_images",
            "get_page_info",
            "list_pages",
            "select_page",
        ]
    }

    private func compactBrowserSelectorPreview(_ input: [String: String]) -> String? {
        if let selector = normalizedCompactText(input["selector"]), !selector.isEmpty {
            return selector
        }

        if let text = normalizedCompactText(input["text"]), !text.isEmpty {
            return text
        }

        return nil
    }

    private func compactBrowserURLDetail(_ urlText: String) -> String {
        guard let url = URL(string: urlText), let host = url.host, !host.isEmpty else {
            return "browser page"
        }
        return host
    }

    private func compactBrowserNavigationDetail(type: String) -> String {
        switch type.lowercased() {
        case "reload":
            return "reload page"
        case "back":
            return "back page"
        case "forward":
            return "forward page"
        default:
            return "browser page"
        }
    }

    private func compactApplyPatchDetail(for tool: ToolCallItem) -> String {
        let patchText = tool.input["patch"]
            ?? tool.input["input"]
            ?? tool.input.values.first
            ?? ""
        let (action, fileName) = compactPatchTarget(from: patchText)

        switch action {
        case .update:
            return fileName ?? "file"
        case .add:
            return fileName ?? "new file"
        case .delete:
            return fileName ?? "deleted file"
        case .move:
            return fileName ?? "moved file"
        case .unknown:
            return "patch"
        }
    }

    private func compactExecCommandDetail(for tool: ToolCallItem) -> String {
        let rawCommand = normalizedCompactText(tool.input["cmd"])
            ?? normalizedCompactText(tool.input["command"])
            ?? normalizedCompactText(tool.result)
        guard let rawCommand else {
            return tool.status == .success ? "Ran command" : "Running command"
        }

        let command = compactNormalizedShellCommand(rawCommand)
        let commandPreview = compactCommandPreview(from: command)

        let lowered = command.lowercased()
        let fileName = compactCommandFileName(from: command)

        if let lookupTarget = compactCommandLookupTarget(from: command) {
            return "\(lookupTarget) availability"
        }

        if lowered.contains("xcodebuild") {
            return "xcodebuild"
        }

        if lowered.contains("apply_patch") || lowered.contains("python") || lowered.contains("perl") || lowered.contains("ruby") {
            if let fileName {
                return fileName
            }
            return "files"
        }

        if lowered.contains("sed -n") || lowered.contains("cat ") || lowered.contains("rg ") || lowered.contains("find ") || lowered.contains("git status") {
            if let fileName {
                return fileName
            }
            return "project files"
        }

        let commandName = compactCommandName(from: command)
        if commandName == "command" || commandName == "shell command" {
            return commandPreview
        }
        if compactShouldShowFullCommandPreview(command, commandName: commandName) {
            return commandPreview
        }
        return commandName
    }

    private func compactExecCommandClassification(for tool: ToolCallItem) -> (badge: String, category: String) {
        let rawCommand = normalizedCompactText(tool.input["cmd"])
            ?? normalizedCompactText(tool.input["command"])
            ?? normalizedCompactText(tool.result)
            ?? ""
        let command = compactNormalizedShellCommand(rawCommand)
        let lowered = command.lowercased()

        if compactCommandLookupTarget(from: command) != nil {
            return ("CHECK", "check")
        }

        if lowered.contains("apply_patch") || lowered.contains("python") || lowered.contains("perl") || lowered.contains("ruby") {
            return ("EDIT", "edit")
        }

        if lowered.contains("sed -n") || lowered.contains("cat ") || lowered.contains("rg ") || lowered.contains("find ") || lowered.contains("git status") {
            return ("READ", "read")
        }

        return ("CMD", "command")
    }

    private enum CompactPatchAction {
        case update
        case add
        case delete
        case move
        case unknown
    }

    private func compactPatchTarget(from patchText: String) -> (CompactPatchAction, String?) {
        let lines = patchText.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.hasPrefix("*** Update File: ") {
                return (.update, compactPatchFileName(from: trimmed, prefix: "*** Update File: "))
            }

            if trimmed.hasPrefix("*** Add File: ") {
                return (.add, compactPatchFileName(from: trimmed, prefix: "*** Add File: "))
            }

            if trimmed.hasPrefix("*** Delete File: ") {
                return (.delete, compactPatchFileName(from: trimmed, prefix: "*** Delete File: "))
            }

            if trimmed.hasPrefix("*** Move to: ") {
                return (.move, compactPatchFileName(from: trimmed, prefix: "*** Move to: "))
            }
        }

        return (.unknown, nil)
    }

    private func compactPatchFileName(from line: String, prefix: String) -> String? {
        let path = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    private func compactCommandName(from command: String) -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "command" }

        let separators = CharacterSet(charactersIn: " |;&\n\t")
        let firstToken = trimmed.components(separatedBy: separators).first ?? trimmed
        if firstToken.hasSuffix("/zsh") || firstToken.hasSuffix("/bash") || firstToken.hasSuffix("/sh") {
            return "shell command"
        }
        return firstToken
    }

    private func compactNormalizedShellCommand(_ command: String) -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let wrappers = [
            "/bin/zsh -lc ",
            "/usr/bin/zsh -lc ",
            "zsh -lc ",
            "/bin/bash -lc ",
            "/usr/bin/bash -lc ",
            "bash -lc ",
            "/bin/sh -lc ",
            "sh -lc ",
            "/usr/bin/env "
        ]

        for wrapper in wrappers where trimmed.hasPrefix(wrapper) {
            return String(trimmed.dropFirst(wrapper.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return trimmed
    }

    private func compactCommandLookupTarget(from command: String) -> String? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = ["command -v ", "which "]

        for pattern in patterns where trimmed.hasPrefix(pattern) {
            let remainder = trimmed.dropFirst(pattern.count)
            let separators = CharacterSet(charactersIn: " |;&\n\t")
            let target = remainder.components(separatedBy: separators).first?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if let target, !target.isEmpty {
                return target
            }
        }

        return nil
    }

    private func compactCommandPreview(from command: String) -> String {
        let cleaned = command
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.count > 64 else { return cleaned }
        return "\(cleaned.prefix(61))..."
    }

    private func compactShouldShowFullCommandPreview(_ command: String, commandName: String) -> Bool {
        guard commandName != "command", commandName != "shell command" else {
            return true
        }

        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if trimmed.contains("\n") {
            return true
        }

        let separators = [" || ", " && ", "; ", " | "]
        if separators.contains(where: { trimmed.contains($0) }) {
            return true
        }

        let firstSpaceIndex = trimmed.firstIndex(of: " ")
        if let firstSpaceIndex {
            let firstToken = String(trimmed[..<firstSpaceIndex])
            return firstToken == commandName
        }

        return false
    }

    private func compactCommandFileName(from command: String) -> String? {
        let matches = command.matches(of: /[A-Za-z0-9_\/.~ -]+\.[A-Za-z0-9]+/)
        guard let match = matches.last else { return nil }
        let rawPath = String(match.output)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard !rawPath.isEmpty else { return nil }
        return URL(fileURLWithPath: rawPath).lastPathComponent
    }

    private func processingDetail(for session: SessionState) -> String {
        let activeTasks = session.subagentState.activeTasks.values.sorted { lhs, rhs in
            lhs.startTime > rhs.startTime
        }

        if let activeTask = activeTasks.first {
            let description = normalizedCompactText(activeTask.description) ?? "Running agent"
            let extras = activeTasks.count > 1 ? " · +\(activeTasks.count - 1) more" : ""
            return "\(description)\(extras)"
        }

        let activeTools = session.toolTracker.inProgress.values.sorted { lhs, rhs in
            lhs.startTime > rhs.startTime
        }

        if let activeTool = activeTools.first {
            let toolLabel = MCPToolFormatter.formatToolName(activeTool.name)
            let extras = activeTools.count > 1 ? " · +\(activeTools.count - 1) more" : ""
            return "\(toolLabel)\(extras)"
        }

        if let toolName = session.lastToolName {
            let toolLabel = MCPToolFormatter.formatToolName(toolName)
            if let message = session.lastMessageRole == "user"
                ? normalizedCompactText(session.lastMessage)
                : normalizedCompactText(session.lastMessage) {
                return "\(toolLabel) · \(message)"
            }
            return toolLabel
        }

        if let message = session.lastMessageRole == "user"
            ? normalizedCompactText(session.lastMessage)
            : normalizedCompactText(session.lastMessage) {
            return message
        }

        return "Working"
    }

    private func normalizedCompactText(_ text: String?) -> String? {
        MCPToolFormatter.summarizeDisplayText(text)
    }

    private func compactActivityColor(for kind: CompactActivityKind) -> Color {
        switch kind {
        case .approval:
            return Color.black.opacity(0.88)
        case .processing:
            return Color.black.opacity(0.88)
        case .compacting:
            return Color(red: 0.79, green: 0.47, blue: 0.96)
        case .ready:
            return TerminalColors.green
        }
    }

    private func compactActivityBadgeColor(for summary: CompactActivitySummary) -> Color {
        switch summary.badge.uppercased() {
        case "YOU":
            return TerminalColors.blue
        case "EDIT", "WRITE":
            return TerminalColors.magenta
        case "READ", "CHECK":
            return TerminalColors.cyan
        case "READY":
            return TerminalColors.green
        case "APPROVE", "INPUT":
            return Color.black.opacity(0.88)
        case "FAIL":
            return TerminalColors.red
        case "PACK":
            return TerminalColors.magenta
        case "RUN", "CMD":
            return Color.black.opacity(0.88)
        case "TOOL":
            return TerminalColors.dim
        default:
            return compactActivityColor(for: summary.kind)
        }
    }

    private func compactActivityBadgeTextColor(for summary: CompactActivitySummary) -> Color {
        switch summary.badge.uppercased() {
        case "APPROVE", "INPUT", "RUN", "CMD":
            return .white.opacity(0.9)
        default:
            return compactActivityBadgeColor(for: summary)
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.status == .opened {
                expandedPanel
            } else {
                compactOrb
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .onAppear {
            sessionMonitor.startMonitoring()
            refreshCompactActivityDisplay()
            updateCompactWindowFootprint()
            Task(priority: .utility) {
                await TerminalLocator.shared.prewarmTerminalLabels(for: sessionMonitor.instances)
            }
        }
        .onChange(of: viewModel.status) { oldStatus, newStatus in
            handleStatusChange(from: oldStatus, to: newStatus)
        }
        .onChange(of: sessionMonitor.pendingInstances) { _, sessions in
            handlePendingSessionsChange(sessions)
        }
        .onChange(of: sessionMonitor.instances) { _, instances in
            handleProcessingChange()
            handleWaitingForInputChange(instances)
            AutoContinueManager.shared.handleNewWaitingSessions(instances.filter { $0.phase == .waitingForInput })
            refreshCompactActivityDisplay()
            Task(priority: .utility) {
                await TerminalLocator.shared.prewarmTerminalLabels(for: instances)
            }
        }
        .onChange(of: compactActivitySummaries) { _, _ in
            if compactActivitySummaries.isEmpty && compactActivityStripCollapsed {
                compactActivityStripCollapsed = false
            }
            guard viewModel.status != .opened else { return }
            updateCompactWindowFootprint()
        }
        .onChange(of: compactActivityStripCollapsed) { _, _ in
            guard viewModel.status != .opened else { return }
            updateCompactWindowFootprint()
        }
        .onChange(of: compactActivityStripEnabled) { _, _ in
            refreshCompactActivityDisplay()
            guard viewModel.status != .opened else { return }
            updateCompactWindowFootprint()
        }
        .onChange(of: compactActivityStripAutoHideSeconds) { _, _ in
            handleProcessingChange()
            refreshCompactActivityDisplay()
            guard viewModel.status != .opened else { return }
            updateCompactWindowFootprint()
        }
        .onChange(of: compactActivityStripAdaptiveWidthEnabled) { _, _ in
            refreshCompactActivityDisplay()
            guard viewModel.status != .opened else { return }
            updateCompactWindowFootprint()
        }
        .onChange(of: compactActivityStripMinWidth) { _, _ in
            refreshCompactActivityDisplay()
            guard viewModel.status != .opened else { return }
            updateCompactWindowFootprint()
        }
        .onChange(of: compactActivityStripMaxWidth) { _, _ in
            refreshCompactActivityDisplay()
            guard viewModel.status != .opened else { return }
            updateCompactWindowFootprint()
        }
    }

    private var expandedPanel: some View {
        VStack(spacing: 0) {
            floatingHeader
            Divider()
                .background(Color.white.opacity(0.08))
            contentView
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(panelBackground)
        .padding(12)
    }

    private var floatingHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 34, height: 34)
                AgentMascotIcon(
                    kind: .solarSystem,
                    size: 24,
                    animate: isAnyProcessing,
                    planetProviders: runningMascotProviders
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(windowTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(windowSubtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            headerButton(icon: "minus") {
                viewModel.notchClose()
            }

            if case .chat = viewModel.contentType {
                headerButton(icon: "sidebar.left") {
                    viewModel.exitChat()
                }
            } else if viewModel.contentType == .menu {
                headerButton(icon: "chevron.left") {
                    viewModel.toggleMenu()
                }
            }

            headerButton(icon: viewModel.contentType == .menu ? "xmark" : "slider.horizontal.3") {
                viewModel.toggleMenu()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var compactOrb: some View {
        let hasActivityStrip = !visibleCompactActivitySummaries.isEmpty

        return HStack(spacing: visibleCompactActivitySummaries.isEmpty ? 0 : 10) {
            compactOrbCore
                .overlay {
                    if isReadyCelebrating {
                        CompactReadyGlowPulse(token: readyCelebrationToken, color: TerminalColors.green)
                    }
                }
                // Reserve some canvas around the orb so the blur/shadow halo
                // does not get clipped when the compact window hugs its bounds.
                .frame(width: compactOrbFootprintWidth(hasActivityStrip: hasActivityStrip), alignment: .center)
                .offset(x: compactOrbFootprintOffsetX(hasActivityStrip: hasActivityStrip))

            if !visibleCompactActivitySummaries.isEmpty {
                compactActivityStrip(visibleCompactActivitySummaries, overflowCount: hiddenCompactActivityCount)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .animation(nil, value: visibleCompactActivitySummaryIDs)
                    .animation(nil, value: hiddenCompactActivityCount)
                    .transaction { transaction in
                        transaction.animation = nil
                    }
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .gesture(WindowDragGesture())
        .onTapGesture(count: 2) {
            viewModel.notchOpen(reason: .click)
        }
        .onTapGesture(count: 1) {
            handleCompactOrbTap()
        }
    }

    private var compactOrbCore: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.035, green: 0.04, blue: 0.05).opacity(compactSurfaceOpacity),
                            Color.black.opacity(compactSurfaceOpacity),
                        ],
                        center: .topLeading,
                        startRadius: 8,
                        endRadius: 52
                    )
                )
            Circle()
                .fill(compactOrbStatusColor.opacity(0.05))
                .scaleEffect(0.92)
                .blur(radius: 10)

            Circle()
                .strokeBorder(orbAccentColor.opacity(0.72), lineWidth: 0.75)
                .overlay {
                    Circle()
                        .strokeBorder(orbAccentColor.opacity(0.08), lineWidth: 1.2)
                        .blur(radius: 3)
                }

            AgentMascotIcon(
                kind: .solarSystem,
                size: 28,
                animate: isAnyProcessing,
                planetProviders: runningMascotProviders
            )
                .opacity(1)
                .transaction { transaction in
                    transaction.animation = nil
                }

            if let badgeText = compactOrbBadgeText {
                ZStack {
                    Circle()
                        .fill(compactOrbBadgeColor)
                    Text(badgeText)
                        .font(.system(size: badgeText.count > 1 ? 7 : 9, weight: .black, design: .rounded))
                        .foregroundColor(compactOrbBadgeTextColor)
                }
                .frame(width: 20, height: 20)
                .overlay {
                    Circle()
                        .stroke(Color.black.opacity(0.36), lineWidth: 1)
                }
                .offset(x: 21, y: -21)
            }
        }
        .frame(width: compactOrbVisualDiameter, height: compactOrbVisualDiameter)
        .shadow(color: orbAccentColor.opacity(isAnyProcessing ? 0.35 : 0.18), radius: 18, y: 8)
    }

    private func compactActivityStrip(_ summaries: [CompactActivitySummary], overflowCount: Int) -> some View {
        let accent = compactActivityColor(for: summaries.first?.kind ?? .processing)

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(summaries) { summary in
                compactActivityRow(summary)
                    .transition(.identity)
            }

            if let footerText = compactActivityFooterText {
                Text(footerText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.58))
                    .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: compactActivityStripWidth, alignment: .leading)
        .animation(nil, value: summaries.map(\.id))
        .animation(nil, value: overflowCount)
        .transaction { transaction in
            transaction.animation = nil
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.78 * compactSurfaceOpacity))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: accent.opacity(0.2), radius: 12, y: 4)
    }

    private func compactActivityRow(_ summary: CompactActivitySummary) -> some View {
        let accent = compactActivityBadgeColor(for: summary)

        return HStack(spacing: 8) {
            Text(summary.badge)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(0.5)
                .foregroundColor(compactActivityBadgeTextColor(for: summary))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
                .background(
                    Capsule(style: .continuous)
                        .fill(accent.opacity(0.14))
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(accent.opacity(0.35), lineWidth: 1)
                }

            Text(summary.text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.88))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
        }
    }

    private func headerButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.78))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notch Layout

    private var isProcessing: Bool {
        activityCoordinator.expandingActivity.show && activityCoordinator.expandingActivity.type == .codex
    }

    /// Whether to show the expanded closed state (processing, pending permission, or waiting for input)
    private var showClosedActivity: Bool {
        isProcessing || hasPendingPermission || hasRecentWaitingForInput
    }

    @ViewBuilder
    private var notchLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row - always present, contains the mascot and spinner that persist across states
            headerRow
                .frame(height: max(24, closedNotchSize.height))

            // Main content only when opened
            if viewModel.status == .opened {
                contentView
                    .frame(width: notchSize.width - 24) // Fixed width to prevent reflow
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.8, anchor: .top)
                                .combined(with: .opacity)
                                .animation(.smooth(duration: 0.35)),
                            removal: .opacity.animation(.easeOut(duration: 0.15))
                        )
                    )
            }
        }
    }

    // MARK: - Header Row (persists across states)

    @ViewBuilder
    private var headerRow: some View {
        HStack(spacing: 0) {
            // Left side - mascot + optional permission indicator (visible when processing, pending, or waiting for input)
            if showClosedActivity {
                HStack(spacing: 4) {
                    AgentMascotIcon(
                        kind: .solarSystem,
                        size: 20,
                        animate: isProcessing,
                        planetProviders: runningMascotProviders
                    )
                        .matchedGeometryEffect(id: "mascot", in: activityNamespace, isSource: showClosedActivity)

                    // Permission indicator only (amber) - waiting for input shows checkmark on right
                    if hasPendingPermission {
                        PermissionIndicatorIcon(size: 14, color: Color.black.opacity(0.9))
                            .matchedGeometryEffect(id: "status-indicator", in: activityNamespace, isSource: showClosedActivity)
                    }
                }
                .frame(width: viewModel.status == .opened ? nil : sideWidth + (hasPendingPermission ? 18 : 0))
                .padding(.leading, viewModel.status == .opened ? 8 : 0)
            }

            // Center content
            if viewModel.status == .opened {
                // Opened: show header content
                openedHeaderContent
            } else if !showClosedActivity {
                // Closed without activity: empty space
                Rectangle()
                    .fill(.clear)
                    .frame(width: closedNotchSize.width - 20)
            } else {
                // Closed with activity: black spacer (with optional bounce)
                Rectangle()
                    .fill(.black)
                    .frame(width: closedNotchSize.width - cornerRadiusInsets.closed.top + (isBouncing ? 16 : 0))
            }

            // Right side - spinner when processing/pending, checkmark when waiting for input
            if showClosedActivity {
                if isProcessing || hasPendingPermission {
                    if hasPendingPermission {
                        Button {
                            approveMostRecentPendingPermission()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(TerminalColors.green.opacity(0.16))
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(TerminalColors.green)
                            }
                            .frame(width: 14, height: 14)
                        }
                        .buttonStyle(.plain)
                        .matchedGeometryEffect(id: "spinner", in: activityNamespace, isSource: showClosedActivity)
                        .frame(width: viewModel.status == .opened ? 20 : sideWidth)
                        .padding(.trailing, viewModel.status == .opened ? 0 : 4)
                        .help("Approve permission")
                    } else {
                        ProcessingSpinner()
                            .matchedGeometryEffect(id: "spinner", in: activityNamespace, isSource: showClosedActivity)
                            .frame(width: viewModel.status == .opened ? 20 : sideWidth)
                            .padding(.trailing, viewModel.status == .opened ? 0 : 4)
                    }
                } else if hasRecentWaitingForInput {
                    // Checkmark for waiting-for-input on the right side
                    ReadyForInputIndicatorIcon(size: 14, color: TerminalColors.green)
                        .matchedGeometryEffect(id: "spinner", in: activityNamespace, isSource: showClosedActivity)
                        .frame(width: viewModel.status == .opened ? 20 : sideWidth)
                        .padding(.trailing, viewModel.status == .opened ? 0 : 4)
                }
            }
        }
        .frame(height: closedNotchSize.height)
    }

    private var sideWidth: CGFloat {
        max(0, closedNotchSize.height - 12) + 10
    }

    // MARK: - Opened Header Content

    @ViewBuilder
    private var openedHeaderContent: some View {
        HStack(spacing: 12) {
            // Show static mascot only if not showing activity in headerRow
            // (headerRow handles mascot + indicator when showClosedActivity is true)
            if !showClosedActivity {
                AgentMascotIcon(
                    kind: .solarSystem,
                    size: 20,
                    planetProviders: runningMascotProviders
                )
                    .matchedGeometryEffect(id: "mascot", in: activityNamespace, isSource: !showClosedActivity)
                    .padding(.leading, 8)
            }

            Spacer()

            // Menu toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.toggleMenu()
                    if viewModel.contentType == .menu {
                        updateManager.markUpdateSeen()
                    }
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: viewModel.contentType == .menu ? "xmark" : "line.3.horizontal")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())

                    // Green dot for unseen update
                    if updateManager.hasUnseenUpdate && viewModel.contentType != .menu {
                        Circle()
                            .fill(TerminalColors.green)
                            .frame(width: 6, height: 6)
                            .offset(x: -2, y: 2)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Content View (Opened State)

    @ViewBuilder
    private var contentView: some View {
        Group {
            switch viewModel.contentType {
            case .instances:
                CodexInstancesView(
                    sessionMonitor: sessionMonitor,
                    viewModel: viewModel
                )
            case .menu:
                NotchMenuView(viewModel: viewModel)
            case .chat(let session):
                ChatView(
                    sessionId: session.sessionId,
                    initialSession: session,
                    sessionMonitor: sessionMonitor,
                    viewModel: viewModel
                )
                // Force a fresh ChatView when switching sessions — otherwise
                // @State (history, session, scroll position) leaks from the
                // previous session and the view shows the wrong conversation.
                // Keyed on sessionId only (not the whole SessionState) so
                // per-event updates still reuse the view.
                .id(session.sessionId)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Event Handlers

    private func handleProcessingChange() {
        if isAnyProcessing || hasPendingPermission {
            // Show Codex activity when processing or waiting for permission.
            activityCoordinator.showActivity(type: .codex)
            isVisible = true
        } else if hasRecentWaitingForInput {
            // Keep visible for waiting-for-input but hide the processing spinner
            activityCoordinator.hideActivity()
            isVisible = true
        } else {
            // Hide activity when done
            activityCoordinator.hideActivity()

            // Delay hiding the notch until animation completes
            // Don't hide on non-notched devices - users need a visible target
            if viewModel.status == .closed && viewModel.hasPhysicalNotch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !isAnyProcessing && !hasPendingPermission && !hasRecentWaitingForInput && viewModel.status == .closed {
                        isVisible = false
                    }
                }
            }
        }
    }

    private func handleStatusChange(from oldStatus: NotchStatus, to newStatus: NotchStatus) {
        refreshCompactActivityDisplay()
        if newStatus != .opened {
            updateCompactWindowFootprint()
        }

        switch newStatus {
        case .opened, .popping:
            isVisible = true
            // Clear waiting-for-input timestamps only when manually opened (user acknowledged)
            if viewModel.openReason == .click || viewModel.openReason == .hover {
                waitingForInputTimestamps.removeAll()
                refreshCompactActivityDisplay()
            }
        case .closed:
            // Don't hide on non-notched devices - users need a visible target
            guard viewModel.hasPhysicalNotch else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if viewModel.status == .closed && !isAnyProcessing && !hasPendingPermission && !hasRecentWaitingForInput && !activityCoordinator.expandingActivity.show {
                    isVisible = false
                }
            }
        }
    }

    private func handlePendingSessionsChange(_ sessions: [SessionState]) {
        let currentIds = Set(sessions.map { $0.stableId })
        let newPendingIds = currentIds.subtracting(previousPendingIds)

        if !newPendingIds.isEmpty &&
           viewModel.status == .closed &&
           !TerminalVisibilityDetector.isTerminalVisibleOnCurrentSpace() {
            viewModel.notchOpen(reason: .notification)
        }

        previousPendingIds = currentIds
    }

    private func handleWaitingForInputChange(_ instances: [SessionState]) {
        // Get sessions that are now waiting for input
        let waitingForInputSessions = instances.filter { $0.phase == .waitingForInput }
        let currentIds = Set(waitingForInputSessions.map { $0.stableId })
        let newWaitingIds = currentIds.subtracting(previousWaitingForInputIds)

        // Track timestamps for newly waiting sessions
        let now = Date()
        for session in waitingForInputSessions where newWaitingIds.contains(session.stableId) {
            waitingForInputTimestamps[session.stableId] = now
        }

        // Clean up timestamps for sessions no longer waiting
        let staleIds = Set(waitingForInputTimestamps.keys).subtracting(currentIds)
        for staleId in staleIds {
            waitingForInputTimestamps.removeValue(forKey: staleId)
        }

        // Bounce the notch when a session newly enters waitingForInput state
        if !newWaitingIds.isEmpty {
            triggerReadyCelebration()

            // Get the sessions that just entered waitingForInput
            let newlyWaitingSessions = waitingForInputSessions.filter { newWaitingIds.contains($0.stableId) }

            AutoContinueManager.shared.handleNewWaitingSessions(newlyWaitingSessions)

            // Play notification sound if the session is not actively focused
            if let soundName = AppSettings.notificationSound.soundName {
                // Check if we should play sound (async check for tmux pane focus)
                Task {
                    let shouldPlaySound = await shouldPlayNotificationSound(for: newlyWaitingSessions)
                    if shouldPlaySound {
                        _ = await MainActor.run {
                            NSSound(named: soundName)?.play()
                        }
                    }
                }
            }

            // Trigger bounce animation to get user's attention
            DispatchQueue.main.async {
                isBouncing = true
                // Bounce back after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isBouncing = false
                }
            }

            if waitingForInputVisibilityWindow > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + waitingForInputVisibilityWindow) {
                    handleProcessingChange()
                    refreshCompactActivityDisplay()
                }
            }

        }

        previousWaitingForInputIds = currentIds
    }

    private func triggerReadyCelebration() {
        readyCelebrationToken += 1
        let token = readyCelebrationToken

        isReadyCelebrating = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            guard token == readyCelebrationToken else { return }
            isReadyCelebrating = false
        }
    }

    private func updateCompactWindowFootprint() {
        let targetSize = compactWindowTargetSize
        viewModel.setCompactWindowSize(targetSize)
    }

    private func handleCompactOrbTap() {
        if hasPendingPermission {
            approveMostRecentPendingPermission()
            return
        }

        guard !compactActivitySummaries.isEmpty else { return }
        compactActivityStripCollapsed.toggle()
    }

    private func approveMostRecentPendingPermission() {
        guard let session = prioritizedPendingApprovalSession,
              session.activePermission != nil else {
            return
        }
        sessionMonitor.approvePermission(sessionId: session.sessionId)
    }

    /// Determine if notification sound should play for the given sessions
    /// Returns true if ANY session is not actively focused
    private func shouldPlayNotificationSound(for sessions: [SessionState]) async -> Bool {
        for session in sessions {
            guard let pid = session.pid else {
                // No PID means we can't check focus, assume not focused
                return true
            }

            let isFocused = await TerminalVisibilityDetector.isSessionFocused(sessionPid: pid)
            if !isFocused {
                return true
            }
        }

        return false
    }
}

private struct CompactReadyGlowPulse: View {
    let token: Int
    let color: Color

    private let duration: TimeInterval = 1.65
    @State private var startedAt = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startedAt)
            ZStack {
                readyHalo(progress: ringProgress(elapsed: elapsed, delay: 0.0), opacity: 0.88, maxSize: 192)
                readyHalo(progress: ringProgress(elapsed: elapsed, delay: 0.26), opacity: 0.58, maxSize: 172)
                readyHalo(progress: ringProgress(elapsed: elapsed, delay: 0.52), opacity: 0.42, maxSize: 152)

                Circle()
                    .fill(color.opacity(max(0, 0.58 - ringProgress(elapsed: elapsed, delay: 0.0) * 0.58)))
                    .frame(width: 10, height: 10)
                    .blur(radius: 4)
            }
        }
        .frame(width: 192, height: 192)
        .blendMode(.screen)
        .allowsHitTesting(false)
        .onAppear { startedAt = .now }
        .onChange(of: token) { _, _ in
            startedAt = .now
        }
    }

    private func readyHalo(progress: CGFloat, opacity: Double, maxSize: CGFloat) -> some View {
        let eased = 1 - pow(1 - progress, 2.4)
        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(opacity * Double(1 - eased)),
                        color.opacity(opacity * 0.56 * Double(1 - eased)),
                        color.opacity(opacity * 0.2 * Double(1 - eased)),
                        .clear,
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: maxSize * 0.5
                )
            )
            .frame(width: 10 + eased * (maxSize - 10), height: 10 + eased * (maxSize - 10))
            .blur(radius: 4 + eased * 10)
    }

    private func ringProgress(elapsed: TimeInterval, delay: TimeInterval) -> CGFloat {
        let raw = (elapsed - delay) / (duration - delay)
        return min(max(CGFloat(raw), 0), 1)
    }
}
