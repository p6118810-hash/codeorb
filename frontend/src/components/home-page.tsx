"use client";

import { ChevronRight, Crosshair, Minus, MessageSquare, SlidersHorizontal, Trash2, X } from "lucide-react";
import Link from "next/link";
import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { usePathname, useRouter } from "next/navigation";
import {
  LOCALE_COOKIE_NAME,
  LOCALES,
  SITE_COPY,
  getHtmlLang,
  type Locale,
  type SiteCopy,
} from "@/lib/i18n";

type HeroWord = {
  label: string;
  color: string;
};

type DemoScene = "overview" | "approval" | "ask" | "jump";
type JumpTargetId = "mobile" | "frontend" | "backend";
type SessionAction = "comment" | "target" | "trash";
type SessionRow = {
  id: string;
  status: "active" | "idle" | "warn";
  name: string;
  tool: string;
  terminal: string;
  preview: string;
  metric: string;
  actions: SessionAction[];
  jumpTargetId?: JumpTargetId;
};

const HERO_WORDS: HeroWord[] = [
  { label: "Claude Code", color: "#d97757" },
  { label: "Codex", color: "#22c55e" },
  { label: "Gemini CLI", color: "#3b82f6" },
  { label: "Cursor", color: "#a855f7" },
  { label: "OpenCode", color: "#f59e0b" },
  { label: "Kiro", color: "#14b8a6" },
];

function useReducedMotion() {
  const [reduced, setReduced] = useState(false);

  useEffect(() => {
    const media = window.matchMedia("(prefers-reduced-motion: reduce)");
    const update = () => setReduced(media.matches);
    update();
    media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
  }, []);

  return reduced;
}

function HeroWordCycle() {
  const reducedMotion = useReducedMotion();
  const [index, setIndex] = useState(0);
  const [visible, setVisible] = useState(true);

  useEffect(() => {
    if (reducedMotion) return;

    const interval = window.setInterval(() => {
      setVisible(false);
      window.setTimeout(() => {
        setIndex((prev) => (prev + 1) % HERO_WORDS.length);
        setVisible(true);
      }, 180);
    }, 2500);

    return () => window.clearInterval(interval);
  }, [reducedMotion]);

  const active = HERO_WORDS[index];

  return (
    <span
      className={`vi-hero-word ${visible ? "is-visible" : "is-hidden"}`}
      style={{ color: active.color }}
    >
      {active.label}
    </span>
  );
}

function PixelIcon({ scene }: { scene: DemoScene }) {
  if (scene === "overview") {
    return (
      <svg className="vi-scene-icon" viewBox="0 0 8 8" aria-hidden="true">
        <rect x="0" y="0" width="3" height="3" fill="currentColor" />
        <rect x="5" y="0" width="3" height="3" fill="currentColor" />
        <rect x="0" y="5" width="3" height="3" fill="currentColor" />
        <rect x="5" y="5" width="3" height="3" fill="currentColor" />
      </svg>
    );
  }

  if (scene === "approval") {
    return (
      <svg className="vi-scene-icon" viewBox="0 0 8 8" aria-hidden="true">
        <rect x="2" y="1" width="4" height="1" fill="currentColor" />
        <rect x="1" y="2" width="6" height="1" fill="currentColor" />
        <rect x="1" y="3" width="6" height="1" fill="currentColor" />
        <rect x="1" y="4" width="6" height="1" fill="currentColor" />
        <rect x="2" y="5" width="4" height="1" fill="currentColor" />
        <rect x="3" y="6" width="2" height="1" fill="currentColor" />
      </svg>
    );
  }

  if (scene === "ask") {
    return (
      <svg className="vi-scene-icon" viewBox="0 0 8 8" aria-hidden="true">
        <rect x="1" y="1" width="6" height="1" fill="currentColor" />
        <rect x="0" y="2" width="8" height="1" fill="currentColor" />
        <rect x="0" y="3" width="8" height="1" fill="currentColor" />
        <rect x="0" y="4" width="6" height="1" fill="currentColor" />
        <rect x="1" y="5" width="4" height="1" fill="currentColor" />
        <rect x="2" y="6" width="2" height="1" fill="currentColor" />
      </svg>
    );
  }

  return (
    <svg className="vi-scene-icon" viewBox="0 0 8 8" aria-hidden="true">
      <rect x="1" y="3" width="3" height="1" fill="currentColor" />
      <rect x="4" y="2" width="1" height="3" fill="currentColor" />
      <rect x="5" y="1" width="1" height="1" fill="currentColor" />
      <rect x="5" y="5" width="1" height="1" fill="currentColor" />
      <rect x="6" y="0" width="1" height="1" fill="currentColor" />
      <rect x="6" y="6" width="1" height="1" fill="currentColor" />
    </svg>
  );
}

function DemoSection({ copy, locale }: { copy: SiteCopy; locale: Locale }) {
  const reducedMotion = useReducedMotion();
  const [activeScene, setActiveScene] = useState<DemoScene>("overview");
  const [activeJumpTarget, setActiveJumpTarget] = useState<JumpTargetId>("frontend");
  const [jumpPulse, setJumpPulse] = useState(0);
  const [playFrom, setPlayFrom] = useState<DemoScene>("overview");
  const [playCycle, setPlayCycle] = useState(0);
  const [jumpCursorPosition, setJumpCursorPosition] = useState({ left: 0, top: 0 });
  const [jumpCursorReady, setJumpCursorReady] = useState(false);
  const [timelinePhase, setTimelinePhase] = useState<Record<DemoScene, "idle" | "done" | "active">>({
    overview: "active",
    approval: "idle",
    ask: "idle",
    jump: "idle",
  });

  const timeoutsRef = useRef<number[]>([]);
  const jumpTargetRef = useRef<JumpTargetId>("frontend");
  const jumpStageRef = useRef<HTMLDivElement | null>(null);
  const jumpButtonRefs = useRef<Record<JumpTargetId, HTMLButtonElement | null>>({
    frontend: null,
    mobile: null,
    backend: null,
  });

  const clearTimers = () => {
    timeoutsRef.current.forEach((id) => window.clearTimeout(id));
    timeoutsRef.current = [];
  };

  const setSceneState = (scene: DemoScene) => {
    setActiveScene(scene);
    setTimelinePhase({
      overview: scene === "overview" ? "active" : scene === "approval" || scene === "ask" || scene === "jump" ? "done" : "idle",
      approval: scene === "approval" ? "active" : scene === "ask" || scene === "jump" ? "done" : "idle",
      ask: scene === "ask" ? "active" : scene === "jump" ? "done" : "idle",
      jump: scene === "jump" ? "active" : "idle",
    });
  };

  const resetDemo = (scene: DemoScene) => {
    clearTimers();
    setSceneState(scene);
    if (scene === "jump") {
      setJumpPulse((prev) => prev + 1);
    }
    setPlayFrom(scene);
    setPlayCycle((prev) => prev + 1);
  };

  useEffect(() => {
    if (reducedMotion) {
      setSceneState("overview");
      return;
    }

    const sequence: DemoScene[] = ["overview", "approval", "ask", "jump"];
    const durations: Record<DemoScene, number> = {
      overview: 4600,
      approval: 4600,
      ask: 4600,
      jump: 7200,
    };

    const queue = (delay: number, fn: () => void) => {
      const id = window.setTimeout(fn, delay);
      timeoutsRef.current.push(id);
    };

    const startLoop = (startScene: DemoScene) => {
      clearTimers();
      const startIndex = sequence.indexOf(startScene);
      let elapsed = 0;

      sequence.forEach((_, offset) => {
        const scene = sequence[(startIndex + offset) % sequence.length];
        queue(elapsed, () => setSceneState(scene));
        elapsed += durations[scene];
      });

      queue(elapsed, () => {
        setPlayFrom("overview");
        setPlayCycle((prev) => prev + 1);
      });
    };

    startLoop(playFrom);
    return clearTimers;
  }, [playCycle, playFrom, reducedMotion]);

  useEffect(() => {
    jumpTargetRef.current = activeJumpTarget;
  }, [activeJumpTarget]);

  useLayoutEffect(() => {
    if (activeScene !== "jump") {
      setJumpCursorReady(false);
      return;
    }

    const measureCursor = () => {
      const stage = jumpStageRef.current;
      const targetButton = jumpButtonRefs.current[activeJumpTarget];
      if (!stage || !targetButton) return;

      const stageRect = stage.getBoundingClientRect();
      const buttonRect = targetButton.getBoundingClientRect();
      setJumpCursorPosition({
        left: buttonRect.left - stageRect.left + buttonRect.width / 2,
        top: buttonRect.top - stageRect.top + buttonRect.height / 2,
      });
      setJumpCursorReady(true);
    };

    setJumpCursorReady(false);

    let firstFrame = 0;
    let secondFrame = 0;
    firstFrame = window.requestAnimationFrame(() => {
      secondFrame = window.requestAnimationFrame(measureCursor);
    });

    const resizeObserver = new ResizeObserver(measureCursor);
    if (jumpStageRef.current) {
      resizeObserver.observe(jumpStageRef.current);
    }
    Object.values(jumpButtonRefs.current).forEach((button) => {
      if (button) resizeObserver.observe(button);
    });

    window.addEventListener("resize", measureCursor);

    return () => {
      window.cancelAnimationFrame(firstFrame);
      window.cancelAnimationFrame(secondFrame);
      resizeObserver.disconnect();
      window.removeEventListener("resize", measureCursor);
    };
  }, [activeScene, activeJumpTarget]);

  useEffect(() => {
    if (reducedMotion || activeScene !== "jump") return;

    setJumpPulse((prev) => prev + 1);
    const order: JumpTargetId[] = ["frontend", "mobile", "backend"];
    const id = window.setInterval(() => {
      const currentIndex = order.indexOf(jumpTargetRef.current);
      const nextTarget = order[(currentIndex + 1) % order.length];
      jumpTargetRef.current = nextTarget;
      setActiveJumpTarget(nextTarget);
      setJumpPulse((prev) => prev + 1);
    }, 2000);

    return () => window.clearInterval(id);
  }, [activeScene, reducedMotion]);

  const sceneCopy = copy.demo.sceneCopy[activeScene];

  const timelineDurations: Record<DemoScene, string> = {
    overview: "4600ms",
    approval: "4600ms",
    ask: "4600ms",
    jump: "7200ms",
  };

  const sessionRows: Record<"overview" | "approval", SessionRow[]> = {
    overview: [
      {
        id: "mobile",
        status: "active",
        name: "mobile",
        tool: "CODEX",
        terminal: "iTerm2",
        preview:
          locale === "zh"
            ? "我先按 `brainstorming` 的思路快速收敛一下..."
            : "Let me quickly narrow this down with a brainstorming-first pass...",
        metric: "61.1M",
        actions: ["comment", "target"],
        jumpTargetId: "mobile",
      },
      {
        id: "frontend",
        status: "active",
        name: "frontend",
        tool: "CODEX",
        terminal: "iTerm2",
        preview:
          locale === "zh"
            ? "我直接把中间 demo 重做成你图里那种“左侧悬浮球 + 右侧黑色任务面板”的动态展示..."
            : "I rewired the central demo into the orb-plus-task-panel layout from your reference...",
        metric: "19.3M",
        actions: ["comment", "target"],
        jumpTargetId: "frontend",
      },
      {
        id: "backend",
        status: "idle",
        name: "backend",
        tool: "CODEX",
        terminal: "iTerm2",
        preview:
          locale === "zh"
            ? "这次问题我已经处理掉了，根因和结果都确认了。"
            : "I already resolved the issue and verified both root cause and outcome.",
        metric: "43.9M",
        actions: ["comment", "target", "trash"],
        jumpTargetId: "backend",
      },
    ],
    approval: [
      {
        id: "backend-approval",
        status: "warn",
        name: "backend",
        tool: locale === "zh" ? "待审批" : "APPROVE",
        terminal: "src/auth/middleware.ts",
        preview:
          locale === "zh"
            ? "工具希望编辑 middleware 里的 token 校验逻辑。"
            : "The tool wants to edit token validation inside middleware.",
        metric: "now",
        actions: ["target"],
        jumpTargetId: "backend",
      },
      {
        id: "mobile-approval",
        status: "active",
        name: "mobile",
        tool: "CODEX",
        terminal: "iTerm2",
        preview:
          locale === "zh"
            ? "最新 app UI 需要截图和录屏素材给视频使用。"
            : "Need the latest app screenshots and recordings for the product video.",
        metric: "61.1M",
        actions: ["comment"],
      },
    ],
  };

  const askThread = {
    title:
      locale === "zh"
        ? "我先不猜了，直接把当前活跃会话和 Ghostty surface 做一轮本地对照，看..."
        : "I will stop guessing and compare the active session with the Ghostty surface locally...",
    bubble:
      locale === "zh"
        ? "点了还是没跳转，而且是先加载的 iTerm2 这类标签，然后才加载的列表，这个也得优化一下。"
        : "It still does not jump after clicking, and it loads the iTerm2-style tabs before the list. That also needs cleanup.",
    summary:
      locale === "zh"
        ? "我先不猜了，直接把当前活跃会话和 Ghostty surface 做一轮本地对照，看看是“没匹配上”，还是“匹配上但没真正 focus”。顺手把列表首屏延迟也一起定位。"
        : "I am going to compare the active session with the Ghostty surface locally to see whether it is a match failure or a focus failure, and I will trace the initial list delay in the same pass.",
    events:
      locale === "zh"
        ? [
            { label: "update_plan", status: "Completed" },
            { label: "exec_command", status: "Completed" },
            { label: "write_stdin", status: "Completed" },
            { label: "exec_command", status: "Completed" },
            { label: "write_stdin", status: "Completed" },
          ]
        : [
            { label: "update_plan", status: "Completed" },
            { label: "exec_command", status: "Completed" },
            { label: "write_stdin", status: "Completed" },
            { label: "exec_command", status: "Completed" },
            { label: "write_stdin", status: "Completed" },
          ],
    working: locale === "zh" ? "Working." : "Working.",
    inputPlaceholder:
      locale === "zh"
        ? "Open Codex in tmux to enable messaging"
        : "Open Codex in tmux to enable messaging",
  };

  const jumpTerminals: Record<
    JumpTargetId,
    {
      id: JumpTargetId;
      title: string;
      location: string;
      app: string;
      badge: string;
      target: string;
      summary: string;
      tabs: string[];
      activeTab: number;
      footer: string;
      lines: string[];
    }
  > = {
    frontend: {
      id: "frontend",
      title: locale === "zh" ? "frontend 终端" : "frontend terminal",
      location:
        locale === "zh"
          ? "/Users/admin/WebstormProjects/code-orb-workspace/frontend"
          : "/Users/admin/WebstormProjects/code-orb-workspace/frontend",
      app: "iTerm2 · tab 02",
      badge: "tab 02",
      target: locale === "zh" ? "已聚焦 iTerm2 tab 02" : "Focused iTerm2 tab 02",
      summary: locale === "zh" ? "跳转到官网 hero 动效会话" : "Jumped to the site hero animation session",
      tabs:
        locale === "zh"
          ? ["hero-demo", "landing-i18n", "video-shotlist"]
          : ["hero-demo", "landing-i18n", "video-shotlist"],
      activeTab: 0,
      footer: locale === "zh" ? "定位完成：frontend / hero-demo" : "Jump complete: frontend / hero-demo",
      lines:
        locale === "zh"
          ? [
              "> rg -n \"vi-orb\" src/components/home-page.tsx src/app/globals.css",
              "找到目标按钮，准备切到 demo jump 动效片段。",
              "已聚焦 hero demo 对应终端，继续调整动画。",
            ]
          : [
              "> rg -n \"vi-orb\" src/components/home-page.tsx src/app/globals.css",
              "Located the target button and switched to the demo jump animation slice.",
              "Focused the hero demo terminal so the animation work can continue.",
            ],
    },
    mobile: {
      id: "mobile",
      title: locale === "zh" ? "mobile 素材终端" : "mobile assets terminal",
      location: "/Users/admin/WebstormProjects/code-orb-mobile",
      app: "iTerm2 · tab 05",
      badge: "tab 05",
      target: locale === "zh" ? "已聚焦 iTerm2 tab 05" : "Focused iTerm2 tab 05",
      summary: locale === "zh" ? "跳转到 app 录屏与截图素材会话" : "Jumped to the app capture and screenshot session",
      tabs:
        locale === "zh"
          ? ["latest-ui", "recordings", "export-cuts"]
          : ["latest-ui", "recordings", "export-cuts"],
      activeTab: 0,
      footer: locale === "zh" ? "定位完成：mobile / latest-ui" : "Jump complete: mobile / latest-ui",
      lines:
        locale === "zh"
          ? [
              "> open app/references/latest-ui.mov",
              "已打开展开态与设置页录屏素材。",
              "同步准备视频剪辑所需的 app 截图与过场素材。",
            ]
          : [
              "> open app/references/latest-ui.mov",
              "Opened the expanded and settings screen captures.",
              "Preparing the app screenshots and transition assets for video editing.",
            ],
    },
    backend: {
      id: "backend",
      title: locale === "zh" ? "backend auth pane" : "backend auth pane",
      location: "/Users/admin/WebstormProjects/code-orb-workspace/backend/src/auth",
      app: "Warp · split pane B",
      badge: "pane B",
      target: locale === "zh" ? "已聚焦 Warp pane B" : "Focused Warp pane B",
      summary: locale === "zh" ? "跳转到 auth 修复对应 split pane" : "Jumped to the auth fix split pane",
      tabs:
        locale === "zh"
          ? ["auth-fix", "middleware", "logs"]
          : ["auth-fix", "middleware", "logs"],
      activeTab: 1,
      footer: locale === "zh" ? "定位完成：backend / middleware" : "Jump complete: backend / middleware",
      lines:
        locale === "zh"
          ? [
              "> sed -n '1,120p' middleware.ts",
              "已回到 token 校验逻辑所在 pane。",
              "继续处理权限审批后需要落地的中间件改动。",
            ]
          : [
              "> sed -n '1,120p' middleware.ts",
              "Returned to the pane with the token validation logic.",
              "Continuing the middleware change after the approval action.",
            ],
    },
  };

  const activeJumpTerminal = jumpTerminals[activeJumpTarget];
  const jumpTerminalOrder: JumpTargetId[] = ["frontend", "mobile", "backend"];
  const jumpRows = jumpTerminalOrder.map((targetId) => {
    const terminal = jumpTerminals[targetId];
    return {
      id: `jump-row-${targetId}`,
      jumpTargetId: targetId,
      status: targetId === activeJumpTarget ? "active" : targetId === "backend" ? "warn" : "idle",
      name: targetId,
      tool: "CODEX",
      terminal: terminal.app.includes("Warp") ? "Warp" : "iTerm2",
      preview: terminal.summary,
      metric: terminal.badge,
    };
  });

  const activateJumpTarget = (targetId: JumpTargetId, switchScene = false) => {
    jumpTargetRef.current = targetId;
    setActiveJumpTarget(targetId);
    setJumpPulse((prev) => prev + 1);
    if (switchScene) {
      clearTimers();
      setSceneState("jump");
      setPlayFrom("jump");
    }
  };

  const renderRowAction = (action: SessionAction, row: SessionRow, index: number, scene: DemoScene) => {
    const Icon = action === "comment" ? MessageSquare : action === "target" ? Crosshair : Trash2;
    const isTarget = action === "target" && row.jumpTargetId;
    const isFocusedJump = scene === "jump" && isTarget && row.jumpTargetId === activeJumpTarget;

    return (
      <button
        key={`${action}-${index}`}
        type="button"
        className={`vi-orb-action-button ${isFocusedJump ? "is-armed" : ""}`}
        aria-label={action}
        onClick={
          isTarget
            ? () => activateJumpTarget(row.jumpTargetId as JumpTargetId, scene !== "jump")
            : undefined
        }
      >
        <Icon size={17} strokeWidth={2.1} />
      </button>
    );
  };

  return (
    <section className="vi-demo-shell" aria-label={copy.demo.ariaLabel}>
      <div className="vi-orb-stage">
        <div className={`vi-orb-demo is-${activeScene}`}>
          <div className="vi-orb-node-wrap">
            <div className="vi-orb-badge">{activeScene === "overview" ? 2 : activeScene === "jump" ? 1 : 1}</div>
            <div className="vi-orb-node">
              <span className="vi-orb-orbit orbit-a">
                <span className="vi-orb-particle particle-a" />
              </span>
              <span className="vi-orb-orbit orbit-b">
                <span className="vi-orb-particle particle-b" />
              </span>
              <span className="vi-orb-core" />
              <span className="vi-orb-haze" />
            </div>
          </div>

          <div className="vi-orb-surface">
            <div className="vi-orb-surface-header">
              <div className="vi-orb-surface-heading">
                <h3>
                  {activeScene === "jump"
                    ? copy.demo.jumpTargets
                    : activeScene === "ask"
                      ? copy.demo.asks
                      : "Sessions"}
                </h3>
                <p>
                  {activeScene === "jump"
                    ? locale === "zh"
                      ? "点击定位按钮，精确跳回对应终端。"
                      : "Click locate and jump back to the exact terminal."
                    : activeScene === "ask"
                      ? locale === "zh"
                        ? "2 个运行中，12 个活跃"
                        : "2 running, 12 active"
                    : locale === "zh"
                      ? "2 个运行中，12 个活跃"
                      : "2 running, 12 active"}
                </p>
              </div>
              <div className="vi-orb-surface-controls">
                <button type="button" className="vi-orb-top-button" aria-label="minimize">
                  <Minus size={18} strokeWidth={2.4} />
                </button>
                {activeScene === "jump" ? (
                  <>
                    <button type="button" className="vi-orb-top-button" aria-label="back">
                      <ChevronRight size={18} strokeWidth={2.4} style={{ transform: "rotate(180deg)" }} />
                    </button>
                    <button type="button" className="vi-orb-top-button" aria-label="close">
                      <X size={18} strokeWidth={2.4} />
                    </button>
                  </>
                ) : activeScene === "ask" ? (
                  <>
                    <button type="button" className="vi-orb-top-button" aria-label="conversation">
                      <MessageSquare size={18} strokeWidth={2.1} />
                    </button>
                    <button type="button" className="vi-orb-top-button" aria-label="settings">
                      <SlidersHorizontal size={18} strokeWidth={2.2} />
                    </button>
                  </>
                ) : (
                  <button type="button" className="vi-orb-top-button" aria-label="settings">
                    <SlidersHorizontal size={18} strokeWidth={2.2} />
                  </button>
                )}
              </div>
            </div>
            <div className="vi-orb-surface-divider" />
            <div key={activeScene} className="vi-orb-surface-body">
              {activeScene === "jump" ? (
                <div className="vi-orb-jump-layout">
                  <div ref={jumpStageRef} className="vi-orb-terminal-stage">
                    <div className="vi-orb-jump-menubar">
                      <div className="vi-orb-jump-menubar-left">
                        <span className="vi-orb-jump-apple">●</span>
                        <strong>Code Orb</strong>
                        <span>{locale === "zh" ? "文件" : "File"}</span>
                        <span>{locale === "zh" ? "编辑" : "Edit"}</span>
                        <span>{locale === "zh" ? "窗口" : "Window"}</span>
                      </div>
                      <div className="vi-orb-jump-menubar-right">
                        <span>{locale === "zh" ? "Fri 11:51 PM" : "Fri 11:51 PM"}</span>
                      </div>
                    </div>
                    <div className="vi-orb-jump-island">
                      <span className="vi-orb-jump-island-dot" />
                      <span className="vi-orb-jump-island-text">{activeJumpTerminal.summary}</span>
                      <span className="vi-orb-jump-island-count">3</span>
                    </div>
                    <div className="vi-orb-jump-panel">
                      <div className="vi-orb-jump-panel-head">
                        <div>
                          <strong>Sessions</strong>
                          <span>{locale === "zh" ? "1 个运行中，6 个活跃" : "1 running, 6 active"}</span>
                        </div>
                      </div>
                      <div className="vi-orb-jump-panel-list">
                        {jumpRows.map((row) => (
                          <div
                            key={row.id}
                            className={`vi-orb-jump-row is-${row.status} ${
                              row.jumpTargetId === activeJumpTarget ? "is-targeted" : ""
                            }`}
                          >
                            <div className={`vi-orb-session-status is-${row.status}`} />
                            <div className="vi-orb-session-main">
                              <div className="vi-orb-session-topline">
                                <span className="vi-orb-session-name">{row.name}</span>
                                <span className="vi-orb-session-chip">{row.tool}</span>
                                <span className="vi-orb-session-chip is-terminal">{row.terminal}</span>
                              </div>
                              <div className="vi-orb-session-preview">{row.preview}</div>
                            </div>
                            <div className="vi-orb-session-meta">{row.metric}</div>
                            <button
                              type="button"
                              ref={(element) => {
                                jumpButtonRefs.current[row.jumpTargetId] = element;
                              }}
                              className={`vi-orb-jump-target-button ${
                                row.jumpTargetId === activeJumpTarget ? "is-active" : ""
                              }`}
                              onClick={() => activateJumpTarget(row.jumpTargetId)}
                              aria-label={`jump-${row.jumpTargetId}`}
                            >
                              <Crosshair size={17} strokeWidth={2.1} />
                            </button>
                          </div>
                        ))}
                      </div>
                    </div>
                    <div
                      className={`vi-orb-jump-cursor ${jumpCursorReady ? "is-visible" : "is-hidden"}`}
                      aria-hidden="true"
                      style={{ left: `${jumpCursorPosition.left}px`, top: `${jumpCursorPosition.top}px` }}
                    >
                      <span key={`${activeJumpTarget}-${jumpPulse}`} className="vi-orb-jump-cursor-ring" />
                      <span className="vi-orb-jump-cursor-arrow" />
                    </div>
                    <div className="vi-orb-terminal-deck">
                      {jumpTerminalOrder.map((terminalId) => {
                        const terminal = jumpTerminals[terminalId];
                        const isActive = terminalId === activeJumpTarget;
                        return (
                          <button
                            key={terminalId}
                            type="button"
                            className={`vi-orb-terminal-card terminal-${terminalId} ${isActive ? "is-active" : "is-dim"}`}
                            onClick={() => activateJumpTarget(terminalId)}
                          >
                            <div className="vi-orb-terminal-head">
                              <div className="vi-orb-terminal-head-copy">
                                <strong>{terminal.title}</strong>
                                <span>{terminal.app}</span>
                              </div>
                              <span className={`vi-orb-terminal-mini-badge ${isActive ? "is-active" : ""}`}>
                                {terminalId}
                              </span>
                            </div>
                            <div className="vi-orb-terminal-window">
                              <div className="vi-orb-terminal-window-bar">
                                <div className="vi-orb-terminal-lights" aria-hidden="true">
                                  <span className="is-red" />
                                  <span className="is-yellow" />
                                  <span className="is-green" />
                                </div>
                                <div className="vi-orb-terminal-app">{terminal.app}</div>
                                <div className="vi-orb-terminal-focus-badge">
                                  {isActive ? copy.demo.doneCta : terminal.badge}
                                </div>
                              </div>
                              <div className="vi-orb-terminal-tabs">
                                {terminal.tabs.map((tab, index) => (
                                  <span
                                    key={tab}
                                    className={`vi-orb-terminal-tab ${index === terminal.activeTab ? "is-active" : ""}`}
                                  >
                                    {tab}
                                  </span>
                                ))}
                              </div>
                              <div className="vi-orb-terminal-path">{terminal.location}</div>
                              <div className="vi-orb-terminal-body">
                                {terminal.lines.map((line) => (
                                  <div key={line} className="vi-orb-terminal-line">
                                    {line}
                                  </div>
                                ))}
                              </div>
                              <div className="vi-orb-terminal-footer">{terminal.footer}</div>
                            </div>
                          </button>
                        );
                      })}
                    </div>
                  </div>
                </div>
              ) : activeScene === "ask" ? (
                <div className="vi-orb-ask-panel">
                  <div className="vi-orb-ask-focus">
                    <button type="button" className="vi-orb-ask-back" aria-label="back">
                      <ChevronRight size={22} strokeWidth={2.5} style={{ transform: "rotate(180deg)" }} />
                    </button>
                    <div>
                      <div className="vi-orb-ask-focus-title">
                        {locale === "zh" ? "Ghostty focus 对照" : "Ghostty focus check"}
                      </div>
                      <div className="vi-orb-ask-focus-subtitle">{askThread.title}</div>
                    </div>
                  </div>
                  <div className="vi-orb-ask-thread">
                    <div className="vi-orb-ask-bubble">
                      <span>{locale === "zh" ? "用户" : "User"}</span>
                      <p>{askThread.bubble}</p>
                    </div>
                    <div className="vi-orb-ask-summary">
                      <span className="vi-orb-ask-summary-dot" />
                      <p>{askThread.summary}</p>
                    </div>
                  </div>
                  <div className="vi-orb-ask-events">
                    <div className="vi-orb-ask-events-title">{locale === "zh" ? "活动记录" : "Activity"}</div>
                    {askThread.events.map((event, index) => (
                      <div key={`${event.label}-${event.status}-${index}`} className="vi-orb-ask-event">
                        <span className="vi-orb-ask-event-dot" />
                        <span className="vi-orb-ask-event-label">{event.label}</span>
                        <span className="vi-orb-ask-event-status">{event.status}</span>
                        <span className="vi-orb-ask-event-chevron">
                          <ChevronRight size={18} strokeWidth={2.1} />
                        </span>
                      </div>
                    ))}
                  </div>
                  <div className="vi-orb-ask-working">{askThread.working}</div>
                  <div className="vi-orb-ask-input">
                    <span>{askThread.inputPlaceholder}</span>
                    <button type="button" className="vi-orb-ask-send" aria-label="send">
                      <ChevronRight size={20} strokeWidth={2.8} style={{ transform: "rotate(-90deg)" }} />
                    </button>
                  </div>
                </div>
              ) : (
                <div className="vi-orb-session-list">
                  {sessionRows[activeScene].map((row) => (
                    <div key={row.id} className={`vi-orb-session-row is-${row.status}`}>
                      <div className={`vi-orb-session-status is-${row.status}`} />
                      <div className="vi-orb-session-main">
                        <div className="vi-orb-session-topline">
                          <span className="vi-orb-session-name">{row.name}</span>
                          <span className="vi-orb-session-chip">{row.tool}</span>
                          <span className="vi-orb-session-chip is-terminal">{row.terminal}</span>
                        </div>
                        <div className="vi-orb-session-preview">{row.preview}</div>
                      </div>
                      <div className="vi-orb-session-meta">{row.metric}</div>
                      <div className="vi-orb-session-actions">
                        {row.actions.map((action, index) => renderRowAction(action, row, index, activeScene))}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      </div>

      <div className="vi-scene-bar">
        <div className="vi-scene-pills">
          {(["overview", "approval", "ask", "jump"] as DemoScene[]).map((scene) => (
            <button
              key={scene}
              type="button"
              className={`vi-scene-pill ${activeScene === scene ? "is-active" : ""} ${timelinePhase[scene] === "done" ? "is-done" : ""} ${timelinePhase[scene] === "active" ? "is-ticking" : ""}`}
              style={{ ["--act-duration" as string]: timelineDurations[scene] }}
              onClick={() => resetDemo(scene)}
            >
              <PixelIcon scene={scene} />
              <span>{copy.demo.sceneTabs[scene]}</span>
            </button>
          ))}
        </div>
        <div className="vi-scene-copy">
          <h2>{sceneCopy.title}</h2>
          <p>{sceneCopy.description}</p>
        </div>
      </div>
    </section>
  );
}

function Header({
  copy,
  locale,
  onLocaleChange,
}: {
  copy: SiteCopy;
  locale: Locale;
  onLocaleChange: (locale: Locale) => void;
}) {
  return (
    <header className="vi-header">
      <div className="vi-nav-shell">
        <a href="#top" className="vi-brand">
          <img
            src="https://ext.same-assets.com/2389589190/2261140702.png"
            alt="Code Orb"
            className="vi-brand-icon"
          />
          <span className="vi-brand-text">CODE ORB</span>
        </a>

        <nav className="vi-nav-links" aria-label={copy.nav.primaryLabel}>
          <a href={`/${locale}/changelog`}>{copy.nav.changelog}</a>
          <div className="vi-language-switcher" aria-label={copy.nav.languageLabel} role="group">
            {LOCALES.map((option) => (
              <button
                key={option}
                type="button"
                className={`vi-language-button ${locale === option ? "is-active" : ""}`}
                aria-pressed={locale === option}
                aria-label={`${copy.nav.languageLabel}: ${copy.nav.locales[option]}`}
                onClick={() => onLocaleChange(option)}
              >
                {copy.nav.locales[option]}
              </button>
            ))}
          </div>
          <a className="vi-download-link" href={`/${locale}/download`}>
            {copy.nav.download}
          </a>
        </nav>
      </div>
    </header>
  );
}

function HeroSection({ copy, locale }: { copy: SiteCopy; locale: Locale }) {
  return (
    <section className="vi-hero" id="top">
      <div className="vi-hero-content">
        <p className="vi-hero-kicker">{copy.hero.kicker}</p>
        <h1>
          {copy.hero.titleLead}
          <br />
          {copy.hero.titleTail} <HeroWordCycle />
        </h1>
        <p className="vi-hero-description">
          {copy.hero.descriptionLine1}
          <br />
          {copy.hero.descriptionLine2}
        </p>
        <div className="vi-hero-actions">
          <a className="vi-cta-primary" href={`/${locale}/download`}>
            {copy.hero.primaryCta}
          </a>
          <a className="vi-cta-secondary" href="#download">
            {copy.hero.secondaryCta}
          </a>
        </div>
      </div>
    </section>
  );
}

function FeatureGrid({ copy }: { copy: SiteCopy }) {
  return (
    <section className="vi-section vi-features">
      <div className="vi-feature-grid">
        {copy.features.map((feature) => (
          <article key={feature.title} className="vi-feature-card">
            <div className="vi-feature-icon" aria-hidden="true">
              <span />
            </div>
            <h3>{feature.title}</h3>
            <p>{feature.description}</p>
          </article>
        ))}
      </div>
    </section>
  );
}

function FAQSection({ copy }: { copy: SiteCopy }) {
  const [openIndex, setOpenIndex] = useState(0);

  useEffect(() => {
    setOpenIndex(0);
  }, [copy]);

  return (
    <section className="vi-section vi-faq" id="changelog">
      <div className="vi-section-heading centered">
        <h2>{copy.faq.heading}</h2>
      </div>
      <div className="vi-faq-list">
        {copy.faq.items.map((faq, index) => {
          const isOpen = openIndex === index;
          return (
            <article key={faq.question} className={`vi-faq-item ${isOpen ? "is-open" : ""}`}>
              <button type="button" onClick={() => setOpenIndex(isOpen ? -1 : index)}>
                <span>{faq.question}</span>
                <span>{isOpen ? "-" : "+"}</span>
              </button>
              <div className="vi-faq-answer"><div><p>{faq.answer}</p></div></div>
            </article>
          );
        })}
      </div>
    </section>
  );
}

function DownloadSection({ copy }: { copy: SiteCopy }) {
  return (
    <section className="vi-section vi-pricing" id="download">
      <div className="vi-section-heading centered narrow">
        <h2>{copy.downloadSection.heading}</h2>
        <p>{copy.downloadSection.subheading}</p>
      </div>

      <div className="vi-pricing-card">
        <div className="vi-pricing-header">
          <div>
            <div className="vi-pricing-title">{copy.downloadSection.title}</div>
            <div className="vi-pricing-badge">{copy.downloadSection.badge}</div>
          </div>
          <img src="https://ext.same-assets.com/2389589190/2261140702.png" alt="Code Orb" />
        </div>

        <ul className="vi-pricing-list">
          {copy.downloadSection.list.map((item) => (
            <li key={item}>
              <span className="check">OK</span>
              <span>{item}</span>
            </li>
          ))}
        </ul>

        <a className="vi-buy-button" href="https://dl.vibeisland.app/VibeIsland.dmg">
          {copy.downloadSection.primaryCta}
        </a>
        <Link className="vi-trial-link" href="/faq">
          {copy.downloadSection.secondaryCta}
        </Link>
      </div>
    </section>
  );
}

function Footer({ copy, locale }: { copy: SiteCopy; locale: Locale }) {
  return (
    <footer className="vi-footer">
      <div className="vi-footer-inner">
        <p>
          © 2026 Code Orb · <a href="https://x.com/edwardluox">Edward Luo</a>
        </p>
        <div className="vi-footer-links">
          <a href={`/${locale}/faq`}>{copy.footer.faq}</a>
          <a href={`/${locale}/compare`}>{copy.footer.compare}</a>
          <a href={`/${locale}/privacy`}>{copy.footer.privacy}</a>
          <a href={`/${locale}/terms`}>{copy.footer.terms}</a>
        </div>
      </div>
    </footer>
  );
}

export function HomePage({ locale }: { locale: Locale }) {
  const router = useRouter();
  const pathname = usePathname();
  const copy = useMemo(() => SITE_COPY[locale], [locale]);

  useEffect(() => {
    document.documentElement.lang = getHtmlLang(locale);
    document.cookie = `${LOCALE_COOKIE_NAME}=${locale}; path=/; max-age=31536000; samesite=lax`;
  }, [locale]);

  const handleLocaleChange = (nextLocale: Locale) => {
    if (nextLocale === locale) return;

    const segments = pathname.split("/");
    if (LOCALES.includes(segments[1] as Locale)) {
      segments[1] = nextLocale;
    } else {
      segments.splice(1, 0, nextLocale);
    }

    const nextPath = segments.join("/") || `/${nextLocale}`;
    router.push(nextPath);
  };

  return (
    <main className="vi-page">
      <Header copy={copy} locale={locale} onLocaleChange={handleLocaleChange} />
      <HeroSection copy={copy} locale={locale} />
      <DemoSection copy={copy} locale={locale} />
      <FeatureGrid copy={copy} />
      <FAQSection copy={copy} />
      <DownloadSection copy={copy} />
      <Footer copy={copy} locale={locale} />
    </main>
  );
}
