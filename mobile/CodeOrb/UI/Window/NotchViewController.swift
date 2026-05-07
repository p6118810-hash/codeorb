//
//  NotchViewController.swift
//  CodeOrb
//
//  Hosts the SwiftUI dashboard view in AppKit.
//

import AppKit
import SwiftUI

class NotchViewController: NSViewController {
    private let viewModel: NotchViewModel
    private var hostingView: NSHostingView<NotchView>!

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        hostingView = NSHostingView(rootView: NotchView(viewModel: viewModel))
        if #available(macOS 13.0, *) {
            hostingView.sizingOptions = []
        }
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false
        hostingView.layer?.masksToBounds = false
        self.view = hostingView
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
    }
}
