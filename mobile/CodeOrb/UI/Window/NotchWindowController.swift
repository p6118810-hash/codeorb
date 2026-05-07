//
//  NotchWindowController.swift
//  CodeOrb
//
//  Controls the floating dashboard window lifecycle.
//

import AppKit
import Combine
import SwiftUI

class NotchWindowController: NSWindowController, NSWindowDelegate {
    private static let compactOrbVisualDiameter: CGFloat = 64
    private static let compactOrbGlowInset: CGFloat = 24
    private static let compactContainerHorizontalPadding: CGFloat = 12

    private static var compactOrbFootprintWidth: CGFloat {
        compactOrbVisualDiameter + (compactOrbGlowInset * 2)
    }

    private static var compactMinimumWindowWidth: CGFloat {
        compactOrbFootprintWidth + compactContainerHorizontalPadding
    }

    private static var compactOrbAnchorOffsetX: CGFloat {
        (compactContainerHorizontalPadding / 2) + (compactOrbFootprintWidth / 2)
    }

    let viewModel: NotchViewModel
    private let screen: NSScreen
    private let compactWindowHeight: CGFloat = 140
    private let minimumExpandedSize = CGSize(width: 460, height: 420)
    private let expandedFrameInset: CGFloat = 16
    private var expandedFrame: NSRect
    private var compactAnchorCenter: CGPoint
    private var pendingWindowState: NotchStatus?
    private var pendingWindowStateWorkItem: DispatchWorkItem?
    private var hasPresentedExpandedState = false
    private var cancellables = Set<AnyCancellable>()
    private let windowStateCoalescingDelay: TimeInterval = 0.015

    init(screen: NSScreen, animateOnLaunch: Bool = true) {
        self.screen = screen

        let screenFrame = screen.visibleFrame
        let notchSize = screen.notchSize

        let defaultSize = CGSize(width: 560, height: 720)
        let defaultExpandedFrame = NSRect(
            x: screenFrame.maxX - defaultSize.width - 40,
            y: screenFrame.midY - defaultSize.height / 2,
            width: defaultSize.width,
            height: defaultSize.height
        )
        self.expandedFrame = defaultExpandedFrame
        let windowHeight = defaultSize.height
        let initialCompactSize = CGSize(width: Self.compactMinimumWindowWidth, height: compactWindowHeight)
        let windowFrame = NSRect(
            x: defaultExpandedFrame.midX - Self.compactOrbAnchorOffsetX,
            y: defaultExpandedFrame.midY - (compactWindowHeight / 2),
            width: initialCompactSize.width,
            height: initialCompactSize.height
        )
        self.compactAnchorCenter = CGPoint(
            x: windowFrame.minX + Self.compactOrbAnchorOffsetX,
            y: windowFrame.midY
        )

        let deviceNotchRect = CGRect(
            x: (screenFrame.width - notchSize.width) / 2,
            y: 0,
            width: notchSize.width,
            height: notchSize.height
        )

        // Create view model
        self.viewModel = NotchViewModel(
            deviceNotchRect: deviceNotchRect,
            screenRect: screenFrame,
            windowHeight: windowHeight,
            hasPhysicalNotch: screen.hasPhysicalNotch
        )

        // Create the window
        let notchWindow = NotchPanel(
            contentRect: windowFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init(window: notchWindow)

        let hostingController = NotchViewController(viewModel: viewModel)
        notchWindow.contentViewController = hostingController
        notchWindow.delegate = self

        notchWindow.setFrame(windowFrame, display: true)
        notchWindow.title = "CodeOrb"
        notchWindow.makeKeyAndOrderFront(nil)

        bindWindowState()
        applyWindowState(for: viewModel.status, animated: false)

        if animateOnLaunch {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func bindWindowState() {
        viewModel.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.scheduleWindowStateApplication(for: status)
            }
            .store(in: &cancellables)

        viewModel.$contentType
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.viewModel.status == .opened else { return }
                self.scheduleWindowStateApplication(for: .opened)
            }
            .store(in: &cancellables)

        viewModel.$compactWindowSize
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.viewModel.status != .opened else { return }
                // Route compact size changes back through the same scheduler as
                // status updates so collapse only applies once with the final
                // width, instead of shrinking and then nudging again.
                self.scheduleWindowStateApplication(for: self.viewModel.status)
            }
            .store(in: &cancellables)
    }

    private func scheduleWindowStateApplication(for status: NotchStatus) {
        pendingWindowState = status
        pendingWindowStateWorkItem?.cancel()
        let runApplication = { [weak self] in
            guard let self, self.pendingWindowState == status else { return }
            self.pendingWindowState = nil
            self.pendingWindowStateWorkItem = nil
            self.applyWindowState(for: status, animated: true)
        }
        let workItem = DispatchWorkItem(block: runApplication)
        pendingWindowStateWorkItem = workItem
        // Coalesce the burst of SwiftUI/AppKit state changes that happen when
        // swapping between compact and expanded content, so the panel frame
        // lands in one step instead of briefly visiting an intermediate rect.
        DispatchQueue.main.asyncAfter(deadline: .now() + windowStateCoalescingDelay, execute: workItem)
    }

    private func applyWindowState(for status: NotchStatus, animated: Bool) {
        guard let window else { return }

        let targetFrame: NSRect
        switch status {
        case .opened:
            if !isExpandedFrame(window.frame) {
                compactAnchorCenter = compactOrbCenter(in: window.frame)
                if !hasPresentedExpandedState {
                    let preferredSize = preferredExpandedWindowSize
                    expandedFrame = NSRect(
                        x: window.frame.midX - preferredSize.width / 2,
                        y: window.frame.midY - preferredSize.height / 2,
                        width: preferredSize.width,
                        height: preferredSize.height
                    )
                }
            }
            window.styleMask.insert(.resizable)
            let minimumSize = minimumExpandedWindowSize
            let maximumSize = maximumExpandedSize
            window.minSize = NSSize(width: minimumSize.width, height: minimumSize.height)
            window.maxSize = NSSize(width: maximumSize.width, height: maximumSize.height)
            targetFrame = clampedExpandedFrame(preferredFrame: expandedFrame, around: window.frame.center, minimumSize: minimumSize, maximumSize: maximumSize)
            expandedFrame = targetFrame
            hasPresentedExpandedState = true
            window.isMovableByWindowBackground = true
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)

        case .closed, .popping:
            let compactSize = currentCompactWindowSize
            if isExpandedFrame(window.frame) {
                expandedFrame = window.frame
            }
            window.styleMask.remove(.resizable)
            window.minSize = NSSize(width: compactSize.width, height: compactSize.height)
            window.maxSize = NSSize(width: compactSize.width, height: compactSize.height)
            targetFrame = compactFrame(anchoredTo: compactAnchorCenter, size: compactSize)
            window.isMovableByWindowBackground = true
        }

        // Avoid AppKit frame animation here: the hosting view is already
        // animating its internal layout, and animating the NSWindow frame at
        // the same time has repeatedly triggered update-constraints crashes.
        window.setFrame(targetFrame, display: true)
    }

    private var currentCompactWindowSize: CGSize {
        let visibleFrame = screen.visibleFrame
        return CGSize(
            width: min(max(viewModel.compactWindowSize.width, Self.compactMinimumWindowWidth), visibleFrame.width - 16),
            height: min(compactWindowHeight, visibleFrame.height - 16)
        )
    }

    private func compactOrbCenter(in frame: NSRect) -> CGPoint {
        CGPoint(
            x: frame.minX + Self.compactOrbAnchorOffsetX,
            y: frame.midY
        )
    }

    private func compactFrame(anchoredTo orbCenter: CGPoint, size: CGSize) -> NSRect {
        let visibleFrame = screen.visibleFrame
        let origin = CGPoint(
            x: min(max(orbCenter.x - Self.compactOrbAnchorOffsetX, visibleFrame.minX + 8), visibleFrame.maxX - size.width - 8),
            y: min(max(orbCenter.y - (size.height / 2), visibleFrame.minY + 8), visibleFrame.maxY - size.height - 8)
        )
        return NSRect(origin: origin, size: size)
    }

    private var minimumExpandedWindowSize: CGSize {
        CGSize(
            width: max(minimumExpandedSize.width, viewModel.openedSize.width + 24),
            height: max(minimumExpandedSize.height, viewModel.openedSize.height + 24)
        )
    }

    private var preferredExpandedWindowSize: CGSize {
        minimumExpandedWindowSize
    }

    private func isExpandedFrame(_ frame: NSRect) -> Bool {
        frame.height > compactWindowHeight + 20
    }

    private var maximumExpandedSize: CGSize {
        let visibleFrame = screen.visibleFrame
        return CGSize(
            width: max(minimumExpandedWindowSize.width, visibleFrame.width - (expandedFrameInset * 2)),
            height: max(minimumExpandedWindowSize.height, visibleFrame.height - (expandedFrameInset * 2))
        )
    }

    private func clampedExpandedFrame(
        preferredFrame: NSRect,
        around center: CGPoint,
        minimumSize: CGSize,
        maximumSize: CGSize
    ) -> NSRect {
        let visibleFrame = screen.visibleFrame
        var frame = preferredFrame

        if frame.width <= 0 || frame.height <= 0 {
            frame.size = minimumSize
        }

        frame.size.width = min(max(frame.width, minimumSize.width), maximumSize.width)
        frame.size.height = min(max(frame.height, minimumSize.height), maximumSize.height)

        if frame.origin == .zero {
            frame.origin = CGPoint(
                x: center.x - frame.width / 2,
                y: center.y - frame.height / 2
            )
        }

        frame.origin.x = min(max(frame.origin.x, visibleFrame.minX + expandedFrameInset), visibleFrame.maxX - frame.width - expandedFrameInset)
        frame.origin.y = min(max(frame.origin.y, visibleFrame.minY + expandedFrameInset), visibleFrame.maxY - frame.height - expandedFrameInset)
        return frame
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window, viewModel.status == .opened else { return }
        expandedFrame = window.frame
    }

    func windowDidResize(_ notification: Notification) {
        guard let window, viewModel.status == .opened else { return }
        expandedFrame = window.frame
    }

    func windowDidMove(_ notification: Notification) {
        guard let window else { return }
        if viewModel.status == .opened {
            expandedFrame.origin = window.frame.origin
        } else {
            compactAnchorCenter = compactOrbCenter(in: window.frame)
        }
    }
}

private extension NSRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
