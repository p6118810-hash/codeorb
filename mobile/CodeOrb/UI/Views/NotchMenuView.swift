//
//  NotchMenuView.swift
//  CodeOrb
//
//  Minimal menu matching Dynamic Island aesthetic
//

import ApplicationServices
import Combine
import SwiftUI
import ServiceManagement
import Sparkle

// MARK: - NotchMenuView

struct NotchMenuView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject private var updateManager = UpdateManager.shared
    @ObservedObject private var screenSelector = ScreenSelector.shared
    @ObservedObject private var soundSelector = SoundSelector.shared
    @AppStorage("compactActivityStripEnabled") private var compactActivityStripEnabled = true
    @State private var appLanguage = AppSettings.appLanguageOption
    @State private var floatingWindowOpacity = AppSettings.floatingWindowOpacityOption
    @State private var compactActivityStripAutoHide = AppSettings.compactActivityStripAutoHideOption
    @State private var compactActivityStripAdaptiveWidthEnabled = AppSettings.compactActivityStripAdaptiveWidthEnabled
    @State private var autoContinueEnabled = AppSettings.autoContinueEnabled
    @State private var hooksInstalled: Bool = false
    @State private var launchAtLogin: Bool = false

    var body: some View {
        // ScrollView so the menu gracefully scrolls when content exceeds the
        // panel height (e.g. both picker rows expanded on a small panel).
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 4) {
                // Appearance settings
                ScreenPickerRow(screenSelector: screenSelector)
                SoundPickerRow(soundSelector: soundSelector)
                CodexDirPickerRow()

                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.vertical, 4)

                // System settings
                MenuToggleRow(
                    icon: "power",
                    label: AppText.get(.menuLaunchAtLogin),
                    isOn: launchAtLogin
                ) {
                    do {
                        if launchAtLogin {
                            try SMAppService.mainApp.unregister()
                            launchAtLogin = false
                        } else {
                            try SMAppService.mainApp.register()
                            launchAtLogin = true
                        }
                    } catch {
                        print("Failed to toggle launch at login: \(error)")
                    }
                }

                MenuToggleRow(
                    icon: "arrow.triangle.2.circlepath",
                    label: AppText.get(.menuHooks),
                    isOn: hooksInstalled
                ) {
                    if hooksInstalled {
                        HookInstaller.uninstall()
                        hooksInstalled = false
                    } else {
                        HookInstaller.installIfNeeded()
                        hooksInstalled = true
                    }
                }

                MenuSectionDivider(
                    title: AppText.get(.menuAutomation)
                )

                MenuToggleRow(
                    icon: "forward.end",
                    label: AppText.get(.menuAutoContinue),
                    isOn: autoContinueEnabled
                ) {
                    autoContinueEnabled.toggle()
                    AppSettings.autoContinueEnabled = autoContinueEnabled
                }

                if autoContinueEnabled {
                    AutoContinueKeywordsRow()
                }

                MenuValueRow(
                    icon: "globe",
                    label: AppText.get(.menuLanguage),
                    value: AppText.appLanguageLabel(appLanguage)
                ) {
                    let nextOption = appLanguage.next
                    appLanguage = nextOption
                    AppSettings.appLanguageOption = nextOption
                }

                MenuValueRow(
                    icon: "circle.lefthalf.filled",
                    label: AppText.get(.menuWindowOpacity),
                    value: AppText.floatingWindowOpacityLabel(floatingWindowOpacity)
                ) {
                    let nextOption = floatingWindowOpacity.next
                    floatingWindowOpacity = nextOption
                    AppSettings.floatingWindowOpacityOption = nextOption
                }

                MenuToggleRow(
                    icon: "capsule.righthalf.filled",
                    label: AppText.get(.menuActivityStrip),
                    isOn: compactActivityStripEnabled
                ) {
                    compactActivityStripEnabled.toggle()
                }

                MenuSectionDivider(
                    title: AppText.get(.menuActivityStripOptions)
                )

                MenuValueRow(
                    icon: "timer",
                    label: AppText.get(.menuActivityStripAutoHide),
                    value: AppText.activityStripAutoHideLabel(compactActivityStripAutoHide)
                ) {
                    let nextOption = compactActivityStripAutoHide.next
                    compactActivityStripAutoHide = nextOption
                    AppSettings.compactActivityStripAutoHideOption = nextOption
                }

                MenuToggleRow(
                    icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                    label: AppText.get(.menuActivityStripAdaptiveWidth),
                    isOn: compactActivityStripAdaptiveWidthEnabled
                ) {
                    compactActivityStripAdaptiveWidthEnabled.toggle()
                    AppSettings.compactActivityStripAdaptiveWidthEnabled = compactActivityStripAdaptiveWidthEnabled
                }

                AccessibilityRow(isEnabled: AXIsProcessTrusted())

                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.vertical, 4)

                // About
                UpdateRow(updateManager: updateManager)

                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.vertical, 4)

                MenuRow(
                    icon: "xmark.circle",
                    label: AppText.get(.menuQuit),
                    isDestructive: true
                ) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .id(appLanguage.rawValue)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            refreshStates()
        }
        .onChange(of: viewModel.contentType) { _, newValue in
            if newValue == .menu {
                refreshStates()
            }
        }
    }

    private func refreshStates() {
        hooksInstalled = HookInstaller.isInstalled()
        launchAtLogin = SMAppService.mainApp.status == .enabled
        appLanguage = AppSettings.appLanguageOption
        floatingWindowOpacity = AppSettings.floatingWindowOpacityOption
        compactActivityStripAutoHide = AppSettings.compactActivityStripAutoHideOption
        compactActivityStripAdaptiveWidthEnabled = AppSettings.compactActivityStripAdaptiveWidthEnabled
        autoContinueEnabled = AppSettings.autoContinueEnabled
        screenSelector.refreshScreens()
    }
}

// MARK: - Update Row

struct UpdateRow: View {
    @ObservedObject var updateManager: UpdateManager
    @State private var isHovered = false
    @State private var isSpinning = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    var body: some View {
        Button {
            handleTap()
        } label: {
            HStack(spacing: 10) {
                // Icon
                ZStack {
                    if case .installing = updateManager.state {
                        Image(systemName: "gear")
                            .font(.system(size: 12))
                            .foregroundColor(TerminalColors.blue)
                            .rotationEffect(.degrees(isSpinning ? 360 : 0))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isSpinning)
                            .onAppear { isSpinning = true }
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 12))
                            .foregroundColor(iconColor)
                    }
                }
                .frame(width: 16)

                // Label
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(labelColor)

                Spacer()

                // Right side: progress or status
                rightContent
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered && isInteractive ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.2), value: updateManager.state)
    }

    // MARK: - Right Content

    @ViewBuilder
    private var rightContent: some View {
        switch updateManager.state {
        case .idle:
            Text(appVersion)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))

        case .upToDate:
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(TerminalColors.green)
                Text(AppText.get(.updateUpToDate))
                    .font(.system(size: 11))
                    .foregroundColor(TerminalColors.green)
            }

        case .checking, .installing:
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 12, height: 12)

        case .found(let version, _):
            HStack(spacing: 6) {
                Circle()
                    .fill(TerminalColors.green)
                    .frame(width: 6, height: 6)
                Text("v\(version)")
                    .font(.system(size: 11))
                    .foregroundColor(TerminalColors.green)
            }

        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(width: 60)
                    .tint(TerminalColors.blue)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(TerminalColors.blue)
                    .frame(width: 32, alignment: .trailing)
            }

        case .extracting(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(width: 60)
                    .tint(TerminalColors.amber)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(TerminalColors.amber)
                    .frame(width: 32, alignment: .trailing)
            }

        case .readyToInstall(let version):
            HStack(spacing: 6) {
                Circle()
                    .fill(TerminalColors.green)
                    .frame(width: 6, height: 6)
                Text("v\(version)")
                    .font(.system(size: 11))
                    .foregroundColor(TerminalColors.green)
            }

        case .error:
            Text(AppText.get(.updateRetry))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Computed Properties

    private var icon: String {
        switch updateManager.state {
        case .idle:
            return "arrow.down.circle"
        case .checking:
            return "arrow.down.circle"
        case .upToDate:
            return "checkmark.circle.fill"
        case .found:
            return "arrow.down.circle.fill"
        case .downloading:
            return "arrow.down.circle"
        case .extracting:
            return "doc.zipper"
        case .readyToInstall:
            return "checkmark.circle.fill"
        case .installing:
            return "gear"
        case .error:
            return "exclamationmark.circle"
        }
    }

    private var iconColor: Color {
        switch updateManager.state {
        case .idle:
            return .white.opacity(isHovered ? 1.0 : 0.7)
        case .checking:
            return .white.opacity(0.7)
        case .upToDate:
            return TerminalColors.green
        case .found, .readyToInstall:
            return TerminalColors.green
        case .downloading:
            return TerminalColors.blue
        case .extracting:
            return TerminalColors.amber
        case .installing:
            return TerminalColors.blue
        case .error:
            return Color(red: 1.0, green: 0.4, blue: 0.4)
        }
    }

    private var label: String {
        switch updateManager.state {
        case .idle:
            return AppText.get(.updateCheck)
        case .checking:
            return AppText.get(.updateChecking)
        case .upToDate:
            return AppText.get(.updateCheck)
        case .found:
            return AppText.get(.updateDownload)
        case .downloading:
            return AppText.get(.updateDownloading)
        case .extracting:
            return AppText.get(.updateExtracting)
        case .readyToInstall:
            return AppText.get(.updateInstallAndRelaunch)
        case .installing:
            return AppText.get(.updateInstalling)
        case .error:
            return AppText.get(.updateFailed)
        }
    }

    private var labelColor: Color {
        switch updateManager.state {
        case .idle, .upToDate:
            return .white.opacity(isHovered ? 1.0 : 0.7)
        case .checking, .downloading, .extracting, .installing:
            return .white.opacity(0.9)
        case .found, .readyToInstall:
            return TerminalColors.green
        case .error:
            return Color(red: 1.0, green: 0.4, blue: 0.4)
        }
    }

    private var isInteractive: Bool {
        switch updateManager.state {
        case .idle, .upToDate, .found, .readyToInstall, .error:
            return true
        case .checking, .downloading, .extracting, .installing:
            return false
        }
    }

    // MARK: - Actions

    private func handleTap() {
        switch updateManager.state {
        case .idle, .upToDate, .error:
            updateManager.checkForUpdates()
        case .found:
            updateManager.downloadAndInstall()
        case .readyToInstall:
            updateManager.installAndRelaunch()
        default:
            break
        }
    }
}

// MARK: - Accessibility Permission Row

struct AccessibilityRow: View {
    let isEnabled: Bool

    @State private var isHovered = false
    @State private var refreshTrigger = false

    private var currentlyEnabled: Bool {
        // Re-check on each render when refreshTrigger changes
        _ = refreshTrigger
        return isEnabled
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.raised")
                .font(.system(size: 12))
                .foregroundColor(textColor)
                .frame(width: 16)

            Text(AppText.get(.menuAccessibility))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(textColor)

            Spacer()

            if isEnabled {
                Circle()
                    .fill(TerminalColors.green)
                    .frame(width: 6, height: 6)

                Text(AppText.get(.stateOn))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            } else {
                Button(action: openAccessibilitySettings) {
                    Text(AppText.get(.actionEnable))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.white)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.white.opacity(0.08) : Color.clear)
        )
        .onHover { isHovered = $0 }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshTrigger.toggle()
        }
    }

    private var textColor: Color {
        .white.opacity(isHovered ? 1.0 : 0.7)
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct MenuRow: View {
    let icon: String
    let label: String
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(textColor)
                    .frame(width: 16)

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textColor)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var textColor: Color {
        if isDestructive {
            return Color(red: 1.0, green: 0.4, blue: 0.4)
        }
        return .white.opacity(isHovered ? 1.0 : 0.7)
    }
}

struct MenuToggleRow: View {
    let icon: String
    let label: String
    let isOn: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(textColor)
                    .frame(width: 16)

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textColor)

                Spacer()

                Circle()
                    .fill(isOn ? TerminalColors.green : Color.white.opacity(0.3))
                    .frame(width: 6, height: 6)

                Text(isOn ? AppText.get(.stateOn) : AppText.get(.stateOff))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var textColor: Color {
        .white.opacity(isHovered ? 1.0 : 0.7)
    }
}

struct MenuValueRow: View {
    let icon: String
    let label: String
    let value: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(textColor)
                    .frame(width: 16)

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textColor)

                Spacer()

                Text(value)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.22))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var textColor: Color {
        .white.opacity(isHovered ? 1.0 : 0.7)
    }
}

struct MenuSectionDivider: View {
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(sectionLine)
                .frame(height: 1)

            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .foregroundColor(.white.opacity(0.36))

            Rectangle()
                .fill(sectionLine)
                .frame(height: 1)
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    private var sectionLine: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.04),
                Color.white.opacity(0.12),
                Color.white.opacity(0.04),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

struct AutoContinueKeywordsRow: View {
    @State private var tags: [String] = Self.parseKeywords(AppSettings.autoContinueKeywords)
    @State private var draft = ""
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(textColor)
                    .frame(width: 16)

                Text(AppText.get(.menuAutoContinueKeywords))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textColor)

                Spacer()

                if !tags.isEmpty || !draft.isEmpty {
                    Button(action: clearAll) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 9, weight: .semibold))
                            Text(AppText.get(.actionClear))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.86))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(red: 1.0, green: 0.2, blue: 0.2).opacity(0.1))
                        )
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.16), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                if !tags.isEmpty {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 72), spacing: 6, alignment: .leading)],
                        alignment: .leading,
                        spacing: 6
                    ) {
                        ForEach(tags, id: \.self) { tag in
                            AutoContinueKeywordTag(title: tag) {
                                removeTag(tag)
                            }
                        }
                    }
                }

                TextField("Keyword + Return", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.82))
                    .onSubmit {
                        commitDraft()
                    }
                    .onChange(of: draft) { _, newValue in
                        guard newValue.contains(",") || newValue.contains("\n") else { return }
                        commit(raw: newValue)
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.black.opacity(0.28))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }

            Text(AppText.get(.menuAutoContinueKeywordHint))
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.32))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.white.opacity(0.08) : Color.clear)
        )
        .onHover { isHovered = $0 }
        .onAppear {
            tags = Self.parseKeywords(AppSettings.autoContinueKeywords)
        }
    }

    private var textColor: Color {
        .white.opacity(isHovered ? 1.0 : 0.7)
    }

    private func commitDraft() {
        commit(raw: draft)
    }

    private func commit(raw: String) {
        let newTags = Self.parseKeywords(raw)
        guard !newTags.isEmpty else {
            draft = ""
            return
        }

        for tag in newTags where !tags.contains(tag) {
            tags.append(tag)
        }
        draft = ""
        persist()
    }

    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        persist()
    }

    private func clearAll() {
        tags.removeAll()
        draft = ""
        persist()
    }

    private func persist() {
        AppSettings.autoContinueKeywords = tags.joined(separator: ", ")
    }

    private static func parseKeywords(_ raw: String) -> [String] {
        raw.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private struct AutoContinueKeywordTag: View {
    let title: String
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.82))
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .black))
                    .foregroundColor(.white.opacity(isHovered ? 0.85 : 0.48))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(isHovered ? 0.14 : 0.09))
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .onHover { isHovered = $0 }
    }
}
