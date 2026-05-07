<div align="center">
  <img src="CodeOrb/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" alt="Logo" width="100" height="100">
  <h3 align="center">CodeOrb for Codex</h3>
  <p align="center">
    A macOS menu bar app that brings Dynamic Island-style notifications to Codex CLI sessions.
    <br />
    <br />
    <a href="https://github.com/p6118810-hash/codeorb/releases/latest" target="_blank" rel="noopener noreferrer">
      <img src="https://img.shields.io/github/v/release/p6118810-hash/codeorb?style=rounded&color=white&labelColor=000000&label=release" alt="Release Version" />
    </a>
    <a href="https://github.com/p6118810-hash/codeorb/releases" target="_blank" rel="noopener noreferrer">
      <img alt="GitHub Downloads" src="https://img.shields.io/github/downloads/p6118810-hash/codeorb/total?style=rounded&color=white&labelColor=000000">
    </a>
  </p>
</div>

> **🟢 Actively maintained**
>
> Launched v1.2 in December 2025, then took a 4-month break. v1.3 (April 2026) works through the backlog of contributor PRs and bug reports and kicks off a regular cadence again. Open PRs and issues are being reviewed — thanks for your patience.

## Features

- **Notch UI** — Animated overlay that expands from the MacBook notch
- **Live Session Monitoring** — Track multiple Codex sessions in real-time
- **Turn Activity** — Watch prompts, tools, and completion state without living in the terminal
- **Chat History** — View full conversation history with markdown rendering
- **Auto-Setup** — Codex hooks install automatically on first launch

## Requirements

- macOS 15.6+
- Codex CLI

## Install

Download the latest release or build from source:

```bash
xcodebuild -scheme CodeOrb -configuration Release build
```

## How It Works

CodeOrb installs hooks into `~/.codex/hooks.json` and enables `features.codex_hooks` in `~/.codex/config.toml`. The hook bridge forwards Codex session events to the app over a Unix socket.

The app also reads Codex rollout transcripts from `~/.codex/sessions/` so the notch can show recent prompts, tool calls, assistant replies, and turn completion state.

## Analytics

CodeOrb uses Mixpanel to collect anonymous usage data:

- **App Launched** — App version, build number, macOS version
- **Session Started** — When a new Codex session is detected

No personal data or conversation content is collected.

## License

Apache 2.0
