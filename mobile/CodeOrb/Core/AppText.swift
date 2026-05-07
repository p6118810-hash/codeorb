//
//  AppText.swift
//  CodeOrb
//
//  Lightweight app text localization for settings and top-level menu UI.
//

import Foundation

private enum AppLanguage: String {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    static var current: AppLanguage {
        switch AppSettings.appLanguageOption {
        case .english:
            return .english
        case .simplifiedChinese:
            return .simplifiedChinese
        case .system:
            break
        }

        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if preferred.hasPrefix("zh") {
            return .simplifiedChinese
        }
        return .english
    }
}

enum AppTextKey: String {
    case menuBack
    case menuLaunchAtLogin
    case menuHooks
    case menuLanguage
    case menuWindowOpacity
    case menuActivityStrip
    case menuActivityStripOptions
    case menuActivityStripAutoHide
    case menuActivityStripAdaptiveWidth
    case menuActivityStripWidthRange
    case menuAutomation
    case menuAutoContinue
    case menuAutoContinueKeywords
    case menuAutoContinueKeywordHint
    case actionClear
    case menuQuit
    case menuScreen
    case menuScreenAutomatic
    case menuScreenAutomaticSublabel
    case menuScreenAuto
    case menuScreenBuiltin
    case menuScreenMain
    case menuNotificationSound
    case menuCodexDirectory
    case menuCodexDirectoryAutoDetect
    case menuCodexDirectoryChooseFolder
    case menuCodexDirectoryDialogTitle
    case menuCodexDirectoryDialogMessage
    case menuAccessibility
    case languageFollowSystem
    case languageEnglish
    case languageSimplifiedChinese
    case stateOn
    case stateOff
    case stateNever
    case actionEnable
    case updateUpToDate
    case updateRetry
    case updateCheck
    case updateChecking
    case updateDownload
    case updateDownloading
    case updateExtracting
    case updateInstallAndRelaunch
    case updateInstalling
    case updateFailed
}

enum AppText {
    static func get(_ key: AppTextKey) -> String {
        let language = AppLanguage.current
        return translations[key]?[language] ?? translations[key]?[.english] ?? key.rawValue
    }

    static func soundName(_ sound: NotificationSound) -> String {
        switch sound {
        case .none: return localized("None", zhHans: "无")
        case .pop: return localized("Pop", zhHans: "Pop")
        case .ping: return localized("Ping", zhHans: "Ping")
        case .tink: return localized("Tink", zhHans: "Tink")
        case .glass: return localized("Glass", zhHans: "Glass")
        case .blow: return localized("Blow", zhHans: "Blow")
        case .bottle: return localized("Bottle", zhHans: "Bottle")
        case .frog: return localized("Frog", zhHans: "Frog")
        case .funk: return localized("Funk", zhHans: "Funk")
        case .hero: return localized("Hero", zhHans: "Hero")
        case .morse: return localized("Morse", zhHans: "Morse")
        case .purr: return localized("Purr", zhHans: "Purr")
        case .sosumi: return localized("Sosumi", zhHans: "Sosumi")
        case .submarine: return localized("Submarine", zhHans: "Submarine")
        case .basso: return localized("Basso", zhHans: "Basso")
        }
    }

    static func activityStripAutoHideLabel(_ option: ActivityStripAutoHideOption) -> String {
        switch option {
        case .never:
            return get(.stateNever)
        case .fiveSeconds:
            return localized("5s", zhHans: "5 秒")
        case .eightSeconds:
            return localized("8s", zhHans: "8 秒")
        case .fifteenSeconds:
            return localized("15s", zhHans: "15 秒")
        case .thirtySeconds:
            return localized("30s", zhHans: "30 秒")
        }
    }

    static func compactActivityStripWidthLabel(_ width: Double) -> String {
        let value = Int(width.rounded())
        return localized("\(value) pt", zhHans: "\(value) 点")
    }

    static func compactActivityStripWidthRangeLabel(minWidth: Double, maxWidth: Double) -> String {
        localized(
            "\(Int(minWidth.rounded()))-\(Int(maxWidth.rounded())) pt",
            zhHans: "\(Int(minWidth.rounded()))-\(Int(maxWidth.rounded())) 点"
        )
    }

    static func floatingWindowOpacityLabel(_ option: FloatingWindowOpacityOption) -> String {
        let percent = Int((option.rawValue * 100).rounded())
        return localized("\(percent)%", zhHans: "\(percent)%")
    }

    static func appLanguageLabel(_ option: AppLanguageOption) -> String {
        switch option {
        case .system:
            return get(.languageFollowSystem)
        case .english:
            return get(.languageEnglish)
        case .simplifiedChinese:
            return get(.languageSimplifiedChinese)
        }
    }

    private static func localized(_ english: String, zhHans: String) -> String {
        AppLanguage.current == .simplifiedChinese ? zhHans : english
    }

    private static let translations: [AppTextKey: [AppLanguage: String]] = [
        .menuBack: [.english: "Back", .simplifiedChinese: "返回"],
        .menuLaunchAtLogin: [.english: "Launch at Login", .simplifiedChinese: "开机启动"],
        .menuHooks: [.english: "Hooks", .simplifiedChinese: "Hooks"],
        .menuLanguage: [.english: "Language", .simplifiedChinese: "语言"],
        .menuWindowOpacity: [.english: "Window Transparency", .simplifiedChinese: "悬浮窗透明度"],
        .menuActivityStrip: [.english: "Compact Summary", .simplifiedChinese: "缩略摘要"],
        .menuActivityStripOptions: [.english: "Compact Summary Options", .simplifiedChinese: "缩略摘要选项"],
        .menuActivityStripAutoHide: [.english: "Compact Summary Auto-Hide", .simplifiedChinese: "缩略摘要自动隐藏"],
        .menuActivityStripAdaptiveWidth: [.english: "Compact Summary Adaptive Width", .simplifiedChinese: "缩略摘要宽度自适应"],
        .menuActivityStripWidthRange: [.english: "Compact Summary Width", .simplifiedChinese: "缩略摘要宽度"],
        .menuAutomation: [.english: "Automation", .simplifiedChinese: "自动化"],
        .menuAutoContinue: [.english: "Auto Continue", .simplifiedChinese: "自动继续"],
        .menuAutoContinueKeywords: [.english: "Continue Keywords", .simplifiedChinese: "继续关键词"],
        .menuAutoContinueKeywordHint: [.english: "Return to add a keyword", .simplifiedChinese: "按回车添加关键词"],
        .actionClear: [.english: "Clear", .simplifiedChinese: "清空"],
        .menuQuit: [.english: "Quit", .simplifiedChinese: "退出"],
        .menuScreen: [.english: "Screen", .simplifiedChinese: "屏幕"],
        .menuScreenAutomatic: [.english: "Automatic", .simplifiedChinese: "自动"],
        .menuScreenAutomaticSublabel: [.english: "Built-in or Main", .simplifiedChinese: "内建屏幕或主屏幕"],
        .menuScreenAuto: [.english: "Auto", .simplifiedChinese: "自动"],
        .menuScreenBuiltin: [.english: "Built-in", .simplifiedChinese: "内建"],
        .menuScreenMain: [.english: "Main", .simplifiedChinese: "主屏幕"],
        .menuNotificationSound: [.english: "Notification Sound", .simplifiedChinese: "通知声音"],
        .menuCodexDirectory: [.english: "Codex Directory", .simplifiedChinese: "Codex 目录"],
        .menuCodexDirectoryAutoDetect: [.english: "Auto-detect", .simplifiedChinese: "自动检测"],
        .menuCodexDirectoryChooseFolder: [.english: "Choose folder...", .simplifiedChinese: "选择文件夹..."],
        .menuCodexDirectoryDialogTitle: [.english: "Choose Codex Directory", .simplifiedChinese: "选择 Codex 目录"],
        .menuCodexDirectoryDialogMessage: [.english: "Select the folder Codex uses (typically ~/.codex).", .simplifiedChinese: "选择 Codex 使用的目录（通常是 ~/.codex）。"],
        .menuAccessibility: [.english: "Accessibility", .simplifiedChinese: "辅助功能"],
        .languageFollowSystem: [.english: "Follow System", .simplifiedChinese: "跟随系统"],
        .languageEnglish: [.english: "English", .simplifiedChinese: "English"],
        .languageSimplifiedChinese: [.english: "Simplified Chinese", .simplifiedChinese: "简体中文"],
        .stateOn: [.english: "On", .simplifiedChinese: "开启"],
        .stateOff: [.english: "Off", .simplifiedChinese: "关闭"],
        .stateNever: [.english: "Never", .simplifiedChinese: "不隐藏"],
        .actionEnable: [.english: "Enable", .simplifiedChinese: "启用"],
        .updateUpToDate: [.english: "Up to date", .simplifiedChinese: "已是最新版本"],
        .updateRetry: [.english: "Retry", .simplifiedChinese: "重试"],
        .updateCheck: [.english: "Check for Updates", .simplifiedChinese: "检查更新"],
        .updateChecking: [.english: "Checking...", .simplifiedChinese: "检查中..."],
        .updateDownload: [.english: "Download Update", .simplifiedChinese: "下载更新"],
        .updateDownloading: [.english: "Downloading...", .simplifiedChinese: "下载中..."],
        .updateExtracting: [.english: "Extracting...", .simplifiedChinese: "解压中..."],
        .updateInstallAndRelaunch: [.english: "Install & Relaunch", .simplifiedChinese: "安装并重启"],
        .updateInstalling: [.english: "Installing...", .simplifiedChinese: "安装中..."],
        .updateFailed: [.english: "Update failed", .simplifiedChinese: "更新失败"],
    ]
}
