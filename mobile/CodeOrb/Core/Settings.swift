//
//  Settings.swift
//  CodeOrb
//
//  App settings manager using UserDefaults
//

import Foundation

/// Available notification sounds
enum NotificationSound: String, CaseIterable {
    case none = "None"
    case pop = "Pop"
    case ping = "Ping"
    case tink = "Tink"
    case glass = "Glass"
    case blow = "Blow"
    case bottle = "Bottle"
    case frog = "Frog"
    case funk = "Funk"
    case hero = "Hero"
    case morse = "Morse"
    case purr = "Purr"
    case sosumi = "Sosumi"
    case submarine = "Submarine"
    case basso = "Basso"

    /// The system sound name to use with NSSound, or nil for no sound
    var soundName: String? {
        self == .none ? nil : rawValue
    }
}

enum ActivityStripAutoHideOption: Double, CaseIterable {
    case fiveSeconds = 5
    case eightSeconds = 8
    case fifteenSeconds = 15
    case thirtySeconds = 30
    case never = 0

    static let `default`: ActivityStripAutoHideOption = .eightSeconds

    var duration: TimeInterval {
        rawValue
    }

    var next: ActivityStripAutoHideOption {
        let allCases = Self.allCases
        guard let index = allCases.firstIndex(of: self) else {
            return .default
        }
        return allCases[(index + 1) % allCases.count]
    }
}

enum CompactActivityStripMinWidthOption: Double, CaseIterable {
    case narrow = 200
    case balanced = 220
    case medium = 260
    case wide = 300
    case extraWide = 340

    static let `default`: CompactActivityStripMinWidthOption = .balanced

    var next: CompactActivityStripMinWidthOption {
        let allCases = Self.allCases
        guard let index = allCases.firstIndex(of: self) else {
            return .default
        }
        return allCases[(index + 1) % allCases.count]
    }
}

enum CompactActivityStripMaxWidthOption: Double, CaseIterable {
    case compact = 360
    case medium = 440
    case large = 520
    case roomy = 680
    case ultra = 760

    static let `default`: CompactActivityStripMaxWidthOption = .roomy

    var next: CompactActivityStripMaxWidthOption {
        let allCases = Self.allCases
        guard let index = allCases.firstIndex(of: self) else {
            return .default
        }
        return allCases[(index + 1) % allCases.count]
    }
}

enum FloatingWindowOpacityOption: Double, CaseIterable {
    case solid = 1.0
    case high = 0.9
    case medium = 0.8
    case light = 0.7
    case airy = 0.6

    static let `default`: FloatingWindowOpacityOption = .solid

    var next: FloatingWindowOpacityOption {
        let allCases = Self.allCases
        guard let index = allCases.firstIndex(of: self) else {
            return .default
        }
        return allCases[(index + 1) % allCases.count]
    }
}

enum AppLanguageOption: String, CaseIterable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    static let `default`: AppLanguageOption = .system

    var next: AppLanguageOption {
        let allCases = Self.allCases
        guard let index = allCases.firstIndex(of: self) else {
            return .default
        }
        return allCases[(index + 1) % allCases.count]
    }
}

enum AppSettings {
    private static let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let notificationSound = "notificationSound"
        static let codexDirectoryPath = "codexDirectoryPath"
        static let legacyCodexDirectoryPathKey = "claudeDirectoryName" // old UserDefaults key
        static let compactActivityStripEnabled = "compactActivityStripEnabled"
        static let compactActivityStripAutoHideSeconds = "compactActivityStripAutoHideSeconds"
        static let compactActivityStripAdaptiveWidthEnabled = "compactActivityStripAdaptiveWidthEnabled"
        static let compactActivityStripMinWidth = "compactActivityStripMinWidth"
        static let compactActivityStripMaxWidth = "compactActivityStripMaxWidth"
        static let floatingWindowOpacity = "floatingWindowOpacity"
        static let appLanguage = "appLanguage"
        static let autoContinueEnabled = "autoContinueEnabled"
        static let autoContinueKeywords = "autoContinueKeywords"
    }

    // MARK: - Notification Sound

    /// The sound to play when Codex finishes and is ready for input
    static var notificationSound: NotificationSound {
        get {
            guard let rawValue = defaults.string(forKey: Keys.notificationSound),
                  let sound = NotificationSound(rawValue: rawValue) else {
                return .pop // Default to Pop
            }
            return sound
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.notificationSound)
        }
    }

    // MARK: - Codex Directory

    /// The name of the Codex config directory under the user's home folder.
    /// Defaults to ".codex" (standard Codex installation).
    /// Change to a custom directory for alternative distributions.
    static var codexDirectoryPath: String {
        get {
            let value = defaults.string(forKey: Keys.codexDirectoryPath)
                ?? defaults.string(forKey: Keys.legacyCodexDirectoryPathKey)
                ?? ""
            return value.isEmpty ? ".codex" : value
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            defaults.set(trimmed, forKey: Keys.codexDirectoryPath)
            defaults.removeObject(forKey: Keys.legacyCodexDirectoryPathKey)
        }
    }

    // MARK: - Compact Activity Strip

    /// Whether the compact floating orb shows the right-side activity strip.
    /// Defaults to true.
    static var compactActivityStripEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.compactActivityStripEnabled) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.compactActivityStripEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.compactActivityStripEnabled)
        }
    }

    /// How long READY items should remain visible in the compact right-side strip.
    /// `0` means never auto-hide.
    static var compactActivityStripAutoHideOption: ActivityStripAutoHideOption {
        get {
            let seconds = defaults.object(forKey: Keys.compactActivityStripAutoHideSeconds) as? Double
            return ActivityStripAutoHideOption(rawValue: seconds ?? ActivityStripAutoHideOption.default.rawValue) ?? .default
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.compactActivityStripAutoHideSeconds)
        }
    }

    static var compactActivityStripAutoHideDuration: TimeInterval {
        compactActivityStripAutoHideOption.duration
    }

    static var compactActivityStripAdaptiveWidthEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.compactActivityStripAdaptiveWidthEnabled) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.compactActivityStripAdaptiveWidthEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.compactActivityStripAdaptiveWidthEnabled)
        }
    }

    static var compactActivityStripMinWidthOption: CompactActivityStripMinWidthOption {
        get {
            let rawValue = defaults.object(forKey: Keys.compactActivityStripMinWidth) as? Double
            return CompactActivityStripMinWidthOption(rawValue: rawValue ?? CompactActivityStripMinWidthOption.default.rawValue) ?? .default
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.compactActivityStripMinWidth)
        }
    }

    static var compactActivityStripMaxWidthOption: CompactActivityStripMaxWidthOption {
        get {
            let rawValue = defaults.object(forKey: Keys.compactActivityStripMaxWidth) as? Double
            return CompactActivityStripMaxWidthOption(rawValue: rawValue ?? CompactActivityStripMaxWidthOption.default.rawValue) ?? .default
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.compactActivityStripMaxWidth)
        }
    }

    // MARK: - Floating Window

    static var floatingWindowOpacityOption: FloatingWindowOpacityOption {
        get {
            let rawValue = defaults.object(forKey: Keys.floatingWindowOpacity) as? Double
            return FloatingWindowOpacityOption(rawValue: rawValue ?? FloatingWindowOpacityOption.default.rawValue) ?? .default
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.floatingWindowOpacity)
        }
    }

    static var floatingWindowOpacity: Double {
        floatingWindowOpacityOption.rawValue
    }

    // MARK: - Language

    static var appLanguageOption: AppLanguageOption {
        get {
            let rawValue = defaults.string(forKey: Keys.appLanguage)
            return AppLanguageOption(rawValue: rawValue ?? AppLanguageOption.default.rawValue) ?? .default
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.appLanguage)
        }
    }

    // MARK: - Auto Continue

    static var autoContinueEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.autoContinueEnabled) == nil {
                return false
            }
            return defaults.bool(forKey: Keys.autoContinueEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.autoContinueEnabled)
        }
    }

    static var autoContinueKeywords: String {
        get {
            guard defaults.object(forKey: Keys.autoContinueKeywords) != nil else {
                return defaultAutoContinueKeywords
            }
            return defaults.string(forKey: Keys.autoContinueKeywords) ?? ""
        }
        set {
            defaults.set(newValue, forKey: Keys.autoContinueKeywords)
        }
    }

    static let defaultAutoContinueKeywords = "继续, continue, go on, keep going, proceed, 是否继续, 要继续吗, shall I continue, should I continue"
}
