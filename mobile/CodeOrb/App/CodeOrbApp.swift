//
//  CodeOrbApp.swift
//  CodeOrb
//
//  Dynamic Island for monitoring Codex instances
//

import SwiftUI

@main
struct CodeOrbApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We use a completely custom window, so no default scene needed
        Settings {
            EmptyView()
        }
    }
}
