export const LOCALES = ["en", "zh"] as const;

export type Locale = (typeof LOCALES)[number];

export const DEFAULT_LOCALE: Locale = "en";
export const LOCALE_COOKIE_NAME = "code-orb-locale";

export function isLocale(value: string): value is Locale {
  return LOCALES.includes(value as Locale);
}

export function getSiteCopy(locale: string) {
  return SITE_COPY[isLocale(locale) ? locale : DEFAULT_LOCALE];
}

export function getHtmlLang(locale: Locale) {
  return locale === "zh" ? "zh-CN" : "en";
}

export function getBaseUrl() {
  if (process.env.NEXT_PUBLIC_APP_URL) {
    return process.env.NEXT_PUBLIC_APP_URL;
  }

  if (process.env.NODE_ENV === "production") {
    return "https://www.codeorb.app";
  }

  return "http://localhost:3003";
}

export type SiteCopy = {
  metadata: {
    title: string;
    description: string;
  };
  nav: {
    primaryLabel: string;
    changelog: string;
    download: string;
    languageLabel: string;
    locales: Record<Locale, string>;
  };
  hero: {
    kicker: string;
    titleLead: string;
    titleTail: string;
    descriptionLine1: string;
    descriptionLine2: string;
    primaryCta: string;
    secondaryCta: string;
  };
  demo: {
    ariaLabel: string;
    menu: {
      file: string;
      edit: string;
      window: string;
      help: string;
    };
    compactText: string;
    compactBadge: string;
    liveSessions: string;
    onePanel: string;
    permissionRequest: string;
    editAction: string;
    deny: string;
    allow: string;
    asks: string;
    deploymentQuestion: string;
    deploymentOptions: [string, string, string];
    jumpTargets: string;
    doneCta: string;
    sceneTabs: Record<"overview" | "approval" | "ask" | "jump", string>;
    sceneCopy: Record<
      "overview" | "approval" | "ask" | "jump",
      {
        title: string;
        description: string;
      }
    >;
    sessions: {
      fixAuthBug: string;
      backendServer: string;
      optimizeQueries: string;
      youPrompt: string;
      writingMiddleware: string;
      buildingRestEndpoints: string;
      analyzingSlowQueries: string;
      done: string;
      doneJumpHint: string;
    };
    terminal: {
      approval: {
        running: string;
        editFile: string;
      };
      ask: {
        buildComplete: string;
        searchedEnvironments: string;
      };
      overview: {
        lookAtAuth: string;
        searchingPatterns: string;
        readFiles: string;
        issueFound: string;
      };
      shared: {
        updated: string;
        newFile: string;
        passed3: string;
        passed8: string;
      };
    };
  };
  features: Array<{
    title: string;
    description: string;
  }>;
  faq: {
    heading: string;
    items: Array<{
      question: string;
      answer: string;
    }>;
  };
  downloadSection: {
    heading: string;
    subheading: string;
    title: string;
    badge: string;
    list: string[];
    primaryCta: string;
    secondaryCta: string;
  };
  footer: {
    faq: string;
    compare: string;
    privacy: string;
    terms: string;
  };
};

export const SITE_COPY: Record<Locale, SiteCopy> = {
  en: {
    metadata: {
      title: "Code Orb - Floating Orb for Your AI Agents",
      description:
        "macOS floating orb for AI agents. Monitor Claude Code, Codex, Gemini CLI, Cursor, Kimi Code and more - real-time status, notifications, permissions, terminal jump. Zero config.",
    },
    nav: {
      primaryLabel: "Primary",
      changelog: "Changelog",
      download: "Download",
      languageLabel: "Language",
      locales: {
        en: "EN",
        zh: "中文",
      },
    },
    hero: {
      kicker: "Code Orb for AI coding agents on macOS",
      titleLead: "The floating orb",
      titleTail: "for your",
      descriptionLine1: "Stay in flow while your agents keep working.",
      descriptionLine2: "Monitor, approve, and jump back - right from the orb.",
      primaryCta: "Download for Free",
      secondaryCta: "See what is included",
    },
    demo: {
      ariaLabel: "Product demo",
      menu: {
        file: "File",
        edit: "Edit",
        window: "Window",
        help: "Help",
      },
      compactText: "fix auth bug",
      compactBadge: "3",
      liveSessions: "Live sessions",
      onePanel: "One panel for every agent.",
      permissionRequest: "Permission Request",
      editAction: "Edit",
      deny: "Deny",
      allow: "Allow",
      asks: "Claude asks",
      deploymentQuestion: "Which deployment target?",
      deploymentOptions: ["Production", "Staging", "Local only"],
      jumpTargets: "Jump targets",
      doneCta: "Done - click to jump",
      sceneTabs: {
        overview: "Monitor",
        approval: "Approve",
        ask: "Ask",
        jump: "Jump",
      },
      sceneCopy: {
        overview: {
          title: "Every agent. One orb.",
          description: "Claude Code, Codex, Gemini CLI, and Cursor - all in a single view.",
        },
        approval: {
          title: "Approve without switching apps.",
          description: "Allow or deny permissions without leaving your flow.",
        },
        ask: {
          title: "Make decisions from the orb.",
          description: "When an agent needs input, pick an option and keep moving.",
        },
        jump: {
          title: "Jump back instantly.",
          description: "Return to the exact terminal, tab, or split pane in one click.",
        },
      },
      sessions: {
        fixAuthBug: "fix auth bug",
        backendServer: "backend server",
        optimizeQueries: "optimize queries",
        youPrompt: "You: fix the auth bug in middleware",
        writingMiddleware: "Writing middleware.ts",
        buildingRestEndpoints: "Building the REST endpoints.",
        analyzingSlowQueries: "Analyzing the slow queries.",
        done: "done",
        doneJumpHint: "Done - click to jump",
      },
      terminal: {
        approval: {
          running: "Running...",
          editFile: "Edit file",
        },
        ask: {
          buildComplete: "Build complete. Ready to deploy.",
          searchedEnvironments: "Searched for 3 environments",
        },
        overview: {
          lookAtAuth: "Let me look at the auth module.",
          searchingPatterns: "Searching for 6 patterns...",
          readFiles: "Read 2 files",
          issueFound: "Found the issue - token validation skips expiry check.",
        },
        shared: {
          updated: "Updated (+8 -23)",
          newFile: "New file (47 lines)",
          passed3: "3 passed",
          passed8: "8 passed",
        },
      },
    },
    features: [
      {
        title: "Zero Config",
        description:
          "One launch, done. Auto-configures hooks for Claude Code, Codex, Gemini CLI, Cursor, OpenCode, Droid, Qoder, Copilot, CodeBuddy, and Kiro.",
      },
      {
        title: "Every Agent",
        description:
          "Claude Code, Codex, Gemini CLI, Cursor, OpenCode, Droid, Qoder, Copilot, CodeBuddy, Kiro, and Kimi Code - eleven agents, one orb, one glance.",
      },
      {
        title: "13+ Terminals",
        description:
          "iTerm2, Ghostty, Warp, Terminal.app, VS Code, and Cursor - precise jump to the exact tab and split pane.",
      },
      {
        title: "Sound Alerts",
        description:
          "8-bit synthesized sounds for every event. Import custom sound packs or craft your own.",
      },
      {
        title: "Plan Review",
        description:
          "Preview plans with full Markdown rendering before approving. Give feedback without leaving the orb.",
      },
      {
        title: "Pure Swift",
        description:
          "Native macOS app, no Electron. Built for Apple Silicon, under 50MB RAM. Fast, light, invisible.",
      },
      {
        title: "Usage Tracking",
        description:
          "See your remaining Claude, Codex, and Kimi quota at a glance. Resets in real time, no extra setup.",
      },
      {
        title: "SSH Remote",
        description:
          "Run agents on remote servers, monitor from your Mac. One-click deploy, auto-reconnect, multi-server.",
      },
      {
        title: "Fully Local",
        description:
          "Everything stays on your Mac. No cloud, no accounts, no telemetry. Just a direct connection between your agents and the orb.",
      },
    ],
    faq: {
      heading: "Frequently asked questions",
      items: [
        {
          question: "Which terminals are supported?",
          answer:
            "iTerm2, Terminal.app, Ghostty, Warp, Alacritty, Kitty, and VS Code / Cursor / Windsurf integrated terminals. Precise jump - including split panes and tmux sessions - works with iTerm2, Ghostty, Terminal.app, Warp, and IDE terminals.",
        },
        {
          question: "What AI coding tools does Code Orb support?",
          answer:
            "Code Orb supports Claude Code, Codex, Gemini CLI, Cursor, OpenCode, Droid, Qoder, Copilot, CodeBuddy, Kiro, and Kimi Code in one unified floating orb.",
        },
        {
          question: "Can I approve Claude Code permissions without switching to the terminal?",
          answer:
            "Yes. When a tool asks for permission, the orb expands with Allow and Deny controls so you can respond without leaving your current app.",
        },
        {
          question: "Does my data leave my machine?",
          answer:
            "No. Session content, terminal metadata, and approvals stay local on your Mac. There is no cloud relay in the normal flow.",
        },
        {
          question: "How does zero-config setup work?",
          answer:
            "On first launch, Code Orb configures supported tools locally, so you do not need API keys, manual edits, or a separate account.",
        },
        {
          question: "Can I install via Homebrew?",
          answer:
            "Yes. The reference site promotes a Homebrew cask install option alongside the direct DMG download.",
        },
        {
          question: "Does it use a lot of resources?",
          answer:
            "No. The app is positioned as a native Swift utility with low idle CPU usage and under 50 MB of RAM.",
        },
        {
          question: "Does it work on external monitors?",
          answer:
            "Yes. On machines without a physical notch, the experience becomes a compact floating orb at the top center of the display.",
        },
        {
          question: "How is Code Orb different from other AI agent overlays?",
          answer:
            "The pitch is broader tool support, richer approvals and question answering, precise terminal jump, plan review, and local-first operation in a native macOS app.",
        },
      ],
    },
    downloadSection: {
      heading: "Free download, full workflow",
      subheading: "Everything you need to monitor, approve, ask, and jump back.",
      title: "Code Orb",
      badge: "Free access",
      list: [
        "Claude Code, Codex & Gemini CLI support",
        "GUI approval & question answering",
        "Precise terminal jump (13+ terminals)",
        "Unlimited sessions & future updates",
        "Native Swift - under 50MB RAM",
      ],
      primaryCta: "Download for Free",
      secondaryCta: "View the FAQ ->",
    },
    footer: {
      faq: "FAQ",
      compare: "Compare",
      privacy: "Privacy",
      terms: "Terms",
    },
  },
  zh: {
    metadata: {
      title: "Code Orb - AI 代码助手悬浮球",
      description:
        "面向 AI agent 的 macOS 悬浮球。集中监控 Claude Code、Codex、Gemini CLI、Cursor、Kimi Code 等工具，实时查看状态、通知、权限请求与终端跳转，零配置开箱即用。",
    },
    nav: {
      primaryLabel: "主导航",
      changelog: "更新日志",
      download: "下载",
      languageLabel: "语言",
      locales: {
        en: "EN",
        zh: "中文",
      },
    },
    hero: {
      kicker: "Code Orb：为 AI 编码助手打造的 macOS 悬浮球",
      titleLead: "属于你的悬浮球",
      titleTail: "适配你的",
      descriptionLine1: "让你专注当前工作，agent 在后台持续推进。",
      descriptionLine2: "监控、审批、跳回终端，全都在悬浮球里完成。",
      primaryCta: "免费下载",
      secondaryCta: "查看包含内容",
    },
    demo: {
      ariaLabel: "产品演示",
      menu: {
        file: "文件",
        edit: "编辑",
        window: "窗口",
        help: "帮助",
      },
      compactText: "修复鉴权 bug",
      compactBadge: "3",
      liveSessions: "实时会话",
      onePanel: "一个面板，查看所有 agent。",
      permissionRequest: "权限请求",
      editAction: "编辑",
      deny: "拒绝",
      allow: "允许",
      asks: "Claude 提问",
      deploymentQuestion: "选择部署目标？",
      deploymentOptions: ["生产环境", "预发布", "仅本地"],
      jumpTargets: "跳转目标",
      doneCta: "已完成，点击跳回",
      sceneTabs: {
        overview: "监控",
        approval: "审批",
        ask: "提问",
        jump: "跳转",
      },
      sceneCopy: {
        overview: {
          title: "所有 agent，一眼掌握。",
          description: "Claude Code、Codex、Gemini CLI、Cursor 都能在一个视图里统一查看。",
        },
        approval: {
          title: "不用切应用也能审批。",
          description: "权限请求出现时，直接在当前流程里允许或拒绝。",
        },
        ask: {
          title: "在悬浮球里直接做决定。",
          description: "当 agent 需要输入时，立刻选择并继续推进。",
        },
        jump: {
          title: "一键跳回现场。",
          description: "精确回到对应终端、标签页或 split pane。",
        },
      },
      sessions: {
        fixAuthBug: "修复鉴权 bug",
        backendServer: "后端服务",
        optimizeQueries: "优化查询",
        youPrompt: "你：修复 middleware 里的鉴权 bug",
        writingMiddleware: "正在写入 middleware.ts",
        buildingRestEndpoints: "正在构建 REST 接口。",
        analyzingSlowQueries: "正在分析慢查询。",
        done: "完成",
        doneJumpHint: "已完成，点击跳回",
      },
      terminal: {
        approval: {
          running: "执行中...",
          editFile: "编辑文件",
        },
        ask: {
          buildComplete: "构建完成，准备部署。",
          searchedEnvironments: "已检查 3 个环境",
        },
        overview: {
          lookAtAuth: "我先看一下鉴权模块。",
          searchingPatterns: "正在搜索 6 个模式...",
          readFiles: "已读取 2 个文件",
          issueFound: "找到问题了：token 校验跳过了过期检查。",
        },
        shared: {
          updated: "已更新 (+8 -23)",
          newFile: "新文件 (47 行)",
          passed3: "3 项通过",
          passed8: "8 项通过",
        },
      },
    },
    features: [
      {
        title: "零配置",
        description:
          "启动一次就完成接入。自动为 Claude Code、Codex、Gemini CLI、Cursor、OpenCode、Droid、Qoder、Copilot、CodeBuddy 和 Kiro 配置 hooks。",
      },
      {
        title: "支持所有 Agent",
        description:
          "Claude Code、Codex、Gemini CLI、Cursor、OpenCode、Droid、Qoder、Copilot、CodeBuddy、Kiro、Kimi Code —— 11 个 agent，一个悬浮球，一眼看清。",
      },
      {
        title: "支持 13+ 终端",
        description:
          "支持 iTerm2、Ghostty、Warp、Terminal.app、VS Code 和 Cursor，精确跳回对应标签页与 split pane。",
      },
      {
        title: "声音提醒",
        description:
          "每类事件都有 8-bit 合成提示音，也可以导入自定义音效包。",
      },
      {
        title: "方案预审",
        description:
          "审批前可完整预览 Markdown 方案，在悬浮球里直接反馈意见。",
      },
      {
        title: "纯 Swift 原生",
        description:
          "原生 macOS 应用，不用 Electron。针对 Apple Silicon 优化，内存占用低于 50MB，轻快而安静。",
      },
      {
        title: "用量追踪",
        description:
          "Claude、Codex、Kimi 的剩余额度一目了然，实时刷新，无需额外配置。",
      },
      {
        title: "SSH 远程",
        description:
          "agent 可以跑在远程服务器上，你在 Mac 上统一查看。一键部署、自动重连、多机支持。",
      },
      {
        title: "完全本地",
        description:
          "所有内容都留在你的 Mac 上。没有云中转、没有账号体系、没有遥测，只有 agent 与悬浮球的本地直连。",
      },
    ],
    faq: {
      heading: "常见问题",
      items: [
        {
          question: "支持哪些终端？",
          answer:
            "支持 iTerm2、Terminal.app、Ghostty、Warp、Alacritty、Kitty，以及 VS Code / Cursor / Windsurf 内置终端。精确跳转（包括 split pane 和 tmux session）可用于 iTerm2、Ghostty、Terminal.app、Warp 以及 IDE 终端。",
        },
        {
          question: "Code Orb 支持哪些 AI 编码工具？",
          answer:
            "Code Orb 支持 Claude Code、Codex、Gemini CLI、Cursor、OpenCode、Droid、Qoder、Copilot、CodeBuddy、Kiro 和 Kimi Code，统一汇聚到一个悬浮球里。",
        },
        {
          question: "Claude Code 请求权限时，可以不切回终端直接审批吗？",
          answer:
            "可以。工具请求权限时，悬浮球会展开显示 Allow / Deny 控件，你无需离开当前应用。",
        },
        {
          question: "我的数据会离开本机吗？",
          answer:
            "不会。会话内容、终端元数据和审批记录都保留在本地，默认流程里没有云端中转。",
        },
        {
          question: "零配置接入是怎么实现的？",
          answer:
            "首次启动时，Code Orb 会在本地自动配置支持的工具，因此你不需要 API Key、手动修改文件或单独注册账号。",
        },
        {
          question: "可以通过 Homebrew 安装吗？",
          answer:
            "可以。官网同时提供 Homebrew cask 安装和直接下载 DMG 的方式。",
        },
        {
          question: "资源占用大吗？",
          answer:
            "不大。它定位为原生 Swift 工具，空闲 CPU 占用低，内存低于 50MB。",
        },
        {
          question: "外接显示器上能用吗？",
          answer:
            "可以。在没有物理刘海的设备上，它会以顶部居中的紧凑悬浮球形式运行。",
        },
        {
          question: "Code Orb 和其他 AI agent 浮层产品有什么不同？",
          answer:
            "它的核心优势是支持更多工具、更完整的审批与问答流程、精确终端跳转、方案预审，以及 native + local-first 的 macOS 体验。",
        },
      ],
    },
    downloadSection: {
      heading: "免费下载，完整工作流",
      subheading: "监控、审批、提问、跳转，一次到位。",
      title: "Code Orb",
      badge: "免费使用",
      list: [
        "支持 Claude Code、Codex 与 Gemini CLI",
        "图形化审批与问题回答",
        "精确终端跳转（13+ 终端）",
        "无限会话与后续更新",
        "原生 Swift，内存低于 50MB",
      ],
      primaryCta: "免费下载",
      secondaryCta: "查看常见问题 ->",
    },
    footer: {
      faq: "常见问题",
      compare: "对比",
      privacy: "隐私",
      terms: "条款",
    },
  },
};
