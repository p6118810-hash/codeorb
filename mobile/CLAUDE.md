# CodeOrb Mobile Development Guide

## 重要说明

这里的 `mobile/` 实际上是 CodeOrb 的 macOS 客户端工程，而不是 iOS / Android 通用移动端工程。

在这个目录工作时请遵守：
- 不要直接修改 `build/`、`releases/` 中的构建产物，除非用户明确要求
- 不要改动签名、密钥或发布脚本的敏感参数，除非任务明确涉及发布流程
- 优先修改 `CodeOrb/` 下的源码，而不是 Xcode 派生产物

## Project Overview

CodeOrb 是一个 macOS 菜单栏应用，用于把 Codex CLI 会话状态以 Dynamic Island / Notch 风格展示出来。

核心能力包括：
- 监听 Codex 会话与工具调用
- 通过本地 hook 与 socket 接收事件
- 在菜单栏和悬浮 Notch 界面中展示会话状态
- 支持 chat 历史、tmux 定位、窗口聚焦与更新流程

## Technology Stack

- **SwiftUI** - 主要界面
- **AppKit** - 菜单栏、窗口和系统交互
- **Xcode project** - `CodeOrb.xcodeproj`
- **Python helper** - `Resources/codeorb-state.py`
- **Shell scripts** - `mobile/scripts/`

## Current Structure

```text
mobile/
├── CodeOrb/
│   ├── App/           # App 入口、窗口管理、屏幕观察
│   ├── Core/          # 设置、几何、核心状态模型
│   ├── Events/        # 事件监听
│   ├── Models/        # 会话、消息、工具结果模型
│   ├── Services/      # Hooks、Session、Tmux、Window、Update 等服务
│   ├── UI/            # 组件、视图、窗口控制器
│   ├── Utilities/     # 辅助工具
│   └── Resources/     # entitlements 与辅助脚本
├── CodeOrb.xcodeproj/
├── scripts/
├── README.md
└── releases/
```

## Key Files

- `mobile/CodeOrb/App/CodeOrbApp.swift` - 应用入口
- `mobile/CodeOrb/App/AppDelegate.swift` - App 生命周期与系统集成
- `mobile/CodeOrb/Services/Session/CodexSessionMonitor.swift` - 会话监控
- `mobile/CodeOrb/Services/Hooks/HookInstaller.swift` - Codex hooks 安装
- `mobile/CodeOrb/Services/Tmux/TmuxController.swift` - tmux 控制
- `mobile/CodeOrb/UI/Views/NotchView.swift` - Notch 主视图
- `mobile/scripts/build.sh` - 构建脚本
- `mobile/scripts/create-release.sh` - 发布包脚本

## Development Commands

常见命令以 `README.md` 和 `scripts/` 为准。

构建示例：

```bash
cd mobile
xcodebuild -scheme CodeOrb -configuration Release build
```

如果任务只是代码修改，默认不要主动运行发布流程；只有在用户要求验证构建、打包或发版时，再使用：
- `mobile/scripts/build.sh`
- `mobile/scripts/create-release.sh`
- `xcodebuild ...`

## Coding Guidance

- SwiftUI 视图放在 `UI/`，跨视图业务逻辑尽量放到 `Services/` 或 `Core/`
- 涉及系统窗口、焦点、菜单栏交互时，优先检查 `App/`、`Window/`、`Utilities/`
- tmux、hook、socket、会话解析等流程修改时，优先保证状态流向清晰、可回溯
- 不要把临时调试代码留在发布路径中

## Validation

如果需要最小化验证，优先：
- 检查改动是否只落在源码目录
- 如用户要求，再执行一次受控构建
