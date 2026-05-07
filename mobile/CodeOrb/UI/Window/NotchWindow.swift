//
//  NotchWindow.swift
//  CodeOrb
//
//  Floating utility panel for the Codex dashboard.
//

import AppKit

class NotchPanel: NSPanel {
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: style,
            backing: backingStoreType,
            defer: flag
        )

        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = true
        minSize = NSSize(width: 76, height: 76)
        maxSize = NSSize(width: 76, height: 76)

        if style.contains(.titled) {
            titleVisibility = .hidden
            titlebarAppearsTransparent = true
        }

        collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces, .ignoresCycle]
        level = .floating
        allowsToolTipsWhenApplicationIsInactive = true
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        hidesOnDeactivate = false

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
