import { getBaseUrl, type Locale } from "@/lib/i18n";

export type InnerPageKey = "changelog" | "faq" | "compare" | "privacy" | "terms" | "download";

type Section = {
  heading: string;
  paragraphs?: string[];
  bullets?: string[];
};

export type InnerPageContent = {
  title: string;
  description: string;
  eyebrow: string;
  intro: string;
  updatedAt: string;
  sections: Section[];
};

export const INNER_PAGE_COPY: Record<Locale, Record<InnerPageKey, InnerPageContent>> = {
  en: {
    changelog: {
      title: "Code Orb Changelog",
      description: "Track the latest product updates, UX refinements, localization work, and workflow improvements in Code Orb.",
      eyebrow: "Product Updates",
      intro: "A running log of what shipped in Code Orb, with a focus on agent workflow, desktop UX, and local-first productivity.",
      updatedAt: "Updated April 23, 2026",
      sections: [
        {
          heading: "April 2026 - Brand and site refresh",
          bullets: [
            "Renamed the product to Code Orb and aligned the marketing site with the floating-orb direction.",
            "Reworked the homepage demo timeline to auto-play through Monitor, Approve, Ask, and Jump.",
            "Added English and Chinese content support to prepare the site for route-based SEO.",
          ],
        },
        {
          heading: "Orb interaction polish",
          bullets: [
            "Changed the step-progress treatment from a detached bar to an in-pill scan effect.",
            "Tuned the highlight edge into a sharper vertical scan line for clearer motion language.",
            "Improved the loop behavior so the sequence restarts from the first step cleanly.",
          ],
        },
        {
          heading: "What is next",
          paragraphs: [
            "The next phase is deeper route coverage, SEO-focused inner pages, and visual alignment with the shipping macOS app as the product UI evolves.",
          ],
        },
      ],
    },
    faq: {
      title: "Code Orb FAQ",
      description: "Answers to the most common questions about Code Orb, including compatibility, permissions, and local-first workflows.",
      eyebrow: "FAQ",
      intro: "A dedicated FAQ page for search and quick scanning. It covers product fit, supported tools, data handling, and setup expectations.",
      updatedAt: "Updated April 23, 2026",
      sections: [],
    },
    compare: {
      title: "Why teams choose Code Orb",
      description: "See how Code Orb differs from simple notifier utilities and other AI coding overlays.",
      eyebrow: "Compare",
      intro: "Code Orb is designed as a working surface for AI coding agents, not just a passive notification layer.",
      updatedAt: "Updated April 23, 2026",
      sections: [
        {
          heading: "Beyond notifications",
          bullets: [
            "Monitor multiple agents from one persistent floating surface.",
            "Approve permission requests without dropping back into the terminal.",
            "Handle agent questions inline instead of breaking flow and context-switching.",
          ],
        },
        {
          heading: "Built for real terminal workflows",
          bullets: [
            "Jump back to the exact terminal, tab, or split pane instead of hunting for the right window.",
            "Support is aimed at modern AI coding setups across native terminals and IDE-integrated terminals.",
            "The UX is optimized for long-running sessions, not one-off toasts.",
          ],
        },
        {
          heading: "Local-first by default",
          bullets: [
            "Session context, approvals, and terminal metadata stay on-device in the normal flow.",
            "No extra cloud relay or web dashboard is required for the core experience.",
            "The app is native Swift on macOS, with a lightweight footprint instead of a heavy web wrapper.",
          ],
        },
      ],
    },
    download: {
      title: "Download Code Orb for macOS",
      description: "Download the Code Orb trial for macOS and review the current install path, product fit, and system expectations.",
      eyebrow: "Download",
      intro: "Get the current macOS build of Code Orb and review the quickest path to evaluate the floating-orb workflow for AI coding agents.",
      updatedAt: "Updated April 23, 2026",
      sections: [
        {
          heading: "Direct download",
          paragraphs: [
            "The fastest way to try Code Orb is the direct DMG download linked on this page.",
            "If you are evaluating the product for yourself or your team, the website flow is optimized around a frictionless trial-first path.",
          ],
        },
        {
          heading: "What you get",
          bullets: [
            "A native macOS utility focused on monitoring, approvals, questions, and terminal jump for AI coding agents.",
            "A floating-orb workflow designed to reduce context switching while long-running agent sessions continue in the background.",
            "A lightweight local-first experience rather than a cloud dashboard dependency.",
          ],
        },
        {
          heading: "Current fit",
          bullets: [
            "Best suited for macOS users actively working with Claude Code, Codex, Gemini CLI, Cursor, and related coding-agent tools.",
            "Especially useful when you keep several terminal or IDE sessions alive at the same time.",
            "Designed for users who want fast approvals and jump-back controls without leaving the active app.",
          ],
        },
      ],
    },
    privacy: {
      title: "Privacy Policy",
      description: "Read how Code Orb handles local session data, terminal metadata, and site analytics expectations.",
      eyebrow: "Privacy",
      intro: "Code Orb is designed around a local-first product philosophy. This page summarizes the practical expectations for the current website and app experience.",
      updatedAt: "Updated April 23, 2026",
      sections: [
        {
          heading: "Product data",
          paragraphs: [
            "Code Orb is built to keep session content, approvals, and terminal context on your Mac in the normal product flow.",
            "The core value proposition is local visibility and control over your agent workflows, without depending on a hosted relay for everyday usage.",
          ],
        },
        {
          heading: "Website usage",
          paragraphs: [
            "If lightweight analytics, download measurement, or payment services are added, they should be limited to what is needed to operate the site and business.",
            "This marketing site should avoid collecting unnecessary personal information and should prefer privacy-preserving defaults.",
          ],
        },
      ],
    },
    terms: {
      title: "Terms of Use",
      description: "Basic usage terms for accessing the Code Orb website, trial downloads, and software licensing flows.",
      eyebrow: "Terms",
      intro: "These terms are a practical placeholder for the current product and site while the commercial and legal copy is still being refined.",
      updatedAt: "Updated April 23, 2026",
      sections: [
        {
          heading: "Website and download access",
          paragraphs: [
            "You may browse the site, read product information, and download available trial builds for lawful evaluation purposes.",
            "You should not misuse the site, interfere with service availability, or attempt unauthorized access to systems or accounts.",
          ],
        },
        {
          heading: "Licensing and payments",
          paragraphs: [
            "Paid licenses, if offered, are governed by the purchase flow, pricing page, and any additional license terms supplied at checkout.",
            "Trial availability, pricing, and feature packaging may change as the product evolves.",
          ],
        },
        {
          heading: "Product status",
          paragraphs: [
            "Code Orb is an actively evolving software product. Features, integrations, and interface details may change over time as the app matures.",
          ],
        },
      ],
    },
  },
  zh: {
    changelog: {
      title: "Code Orb 更新日志",
      description: "查看 Code Orb 最近的产品更新、交互优化、多语言改造与工作流改进。",
      eyebrow: "产品更新",
      intro: "这里记录 Code Orb 已发布的重要变化，重点关注 agent 工作流、桌面交互和 local-first 体验。",
      updatedAt: "更新于 2026 年 4 月 23 日",
      sections: [
        {
          heading: "2026 年 4 月 - 品牌与官网更新",
          bullets: [
            "产品正式更名为 Code Orb，官网叙事从旧的 Dynamic Island 方向切换到悬浮球方向。",
            "首页演示改成 Monitor、Approve、Ask、Jump 四段自动播放。",
            "先接入中英文内容，为后续基于路由的 SEO 做准备。",
          ],
        },
        {
          heading: "悬浮球交互优化",
          bullets: [
            "将步骤进度从额外进度条改成按钮内部的扫描式高亮。",
            "把前沿效果调成更锐利的竖向扫描线，提升识别度。",
            "优化循环节奏，让最后一步结束后能顺滑回到第一步。",
          ],
        },
        {
          heading: "接下来会做什么",
          paragraphs: [
            "下一阶段会继续补齐多语言路由、SEO 内页，以及与真实 macOS app 更一致的视觉展示。",
          ],
        },
      ],
    },
    faq: {
      title: "Code Orb 常见问题",
      description: "集中回答关于 Code Orb 的常见问题，包括兼容性、权限审批与 local-first 工作流。",
      eyebrow: "FAQ",
      intro: "这是一个更适合搜索和快速阅读的 FAQ 独立页面，覆盖产品定位、支持工具、数据处理和接入方式。",
      updatedAt: "更新于 2026 年 4 月 23 日",
      sections: [],
    },
    compare: {
      title: "为什么选择 Code Orb",
      description: "看看 Code Orb 与普通通知工具、其他 AI 编码浮层工具的差异。",
      eyebrow: "产品对比",
      intro: "Code Orb 不只是一个被动提醒层，而是为 AI 编码 agent 设计的工作界面。",
      updatedAt: "更新于 2026 年 4 月 23 日",
      sections: [
        {
          heading: "不只是通知提醒",
          bullets: [
            "在一个持续存在的悬浮界面里同时监控多个 agent。",
            "权限请求出现时，直接审批，不必切回终端。",
            "agent 提问时可以原地回答，不打断当前工作流。",
          ],
        },
        {
          heading: "真正面向终端工作流",
          bullets: [
            "可以直接跳回准确的终端、标签页或 split pane，而不是靠人工查找窗口。",
            "兼容原生终端和 IDE 内置终端的现代 AI 编码场景。",
            "体验重点放在长会话与多 agent 并行，而不是一次性 toast。",
          ],
        },
        {
          heading: "默认 local-first",
          bullets: [
            "默认流程里，会话上下文、审批信息和终端元数据都留在本机。",
            "核心体验不依赖额外云中转或 web dashboard。",
            "原生 Swift macOS 应用，更轻量，不是笨重的壳应用。",
          ],
        },
      ],
    },
    download: {
      title: "下载适用于 macOS 的 Code Orb",
      description: "下载 Code Orb 的 macOS 试用版，并快速了解当前安装方式、产品适用场景与系统预期。",
      eyebrow: "下载",
      intro: "获取当前可用的 Code Orb macOS 构建，并快速判断这套 AI 编码助手悬浮球工作流是否适合你的团队或个人场景。",
      updatedAt: "更新于 2026 年 4 月 23 日",
      sections: [
        {
          heading: "直接下载",
          paragraphs: [
            "当前体验 Code Orb 最快的方式是直接下载 DMG 安装包。",
            "如果你正在为个人或团队评估产品，当前网站流程优先围绕低门槛试用来设计。",
          ],
        },
        {
          heading: "你会得到什么",
          bullets: [
            "一个原生 macOS 工具，用来处理 AI coding agent 的监控、审批、提问与终端跳转。",
            "一套悬浮球式工作流，尽量减少上下文切换，让后台 agent 会话持续推进。",
            "一个更轻量、local-first 的体验，而不是依赖云端 dashboard。",
          ],
        },
        {
          heading: "当前适合谁",
          bullets: [
            "适合在 macOS 上重度使用 Claude Code、Codex、Gemini CLI、Cursor 等工具的用户。",
            "尤其适合同时维护多个终端或 IDE 会话的场景。",
            "适合希望在当前应用内快速审批和跳回现场的用户。",
          ],
        },
      ],
    },
    privacy: {
      title: "隐私政策",
      description: "了解 Code Orb 如何处理本地会话数据、终端元数据以及网站相关信息。",
      eyebrow: "隐私",
      intro: "Code Orb 围绕 local-first 产品哲学设计。这里先用清晰、实用的方式说明当前网站和应用的隐私边界。",
      updatedAt: "更新于 2026 年 4 月 23 日",
      sections: [
        {
          heading: "产品数据",
          paragraphs: [
            "Code Orb 的目标是在默认产品流程中，让会话内容、审批记录和终端上下文保留在你的 Mac 上。",
            "它的核心价值是让你在本地直接查看和控制 agent 工作流，而不是依赖托管中转。",
          ],
        },
        {
          heading: "网站使用",
          paragraphs: [
            "如果未来接入轻量分析、下载统计或支付服务，也应该仅限于网站运营所需的最小范围。",
            "营销网站不应收集不必要的个人信息，并应尽量采用更克制的默认设置。",
          ],
        },
      ],
    },
    terms: {
      title: "使用条款",
      description: "适用于 Code Orb 网站访问、试用版下载以及软件授权流程的基础使用条款。",
      eyebrow: "条款",
      intro: "在商业与法律文案进一步完善前，这里先提供一版清晰实用的基础条款说明。",
      updatedAt: "更新于 2026 年 4 月 23 日",
      sections: [
        {
          heading: "网站与下载访问",
          paragraphs: [
            "你可以出于合法评估目的浏览网站、阅读产品信息，并下载可用的试用版本。",
            "你不应滥用网站、影响服务可用性，或尝试未授权访问系统与账户。",
          ],
        },
        {
          heading: "授权与支付",
          paragraphs: [
            "如果提供付费授权，则应以支付页面、购买流程以及结算时附带的授权条款为准。",
            "试用策略、定价和功能打包可能会随着产品演进而调整。",
          ],
        },
        {
          heading: "产品状态",
          paragraphs: [
            "Code Orb 仍处于持续迭代中。随着产品成熟，功能、集成范围和界面细节都可能变化。",
          ],
        },
      ],
    },
  },
};

export function getInnerPageContent(locale: Locale, page: InnerPageKey) {
  return INNER_PAGE_COPY[locale][page];
}

export function getInnerPageHref(locale: Locale, page: InnerPageKey) {
  return `${getBaseUrl()}/${locale}/${page}`;
}
