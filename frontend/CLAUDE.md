# CodeOrb Frontend Development Guide

## 重要说明

这是 CodeOrb 的前端子项目，当前是一个基于 Next.js App Router 的站点工程。

在这个目录工作时请遵守：
- 不要直接修改 `node_modules/`、`.next/` 或其他构建产物
- 没有明确要求时，不要改动部署配置或环境变量文件
- 优先在 `src/` 下完成页面、样式和通用工具修改

## Project Overview

`frontend/` 当前是一个轻量级 Next.js 15 项目，用于承载 CodeOrb 的 Web 前端页面。

## Technology Stack

### Core Framework
- **Next.js 15.3.7** - App Router
- **React 18.3** - UI library
- **TypeScript 5.8** - Type safety
- **Tailwind CSS 3.4** - Styling

### Supporting Libraries
- **Biome** - Formatting
- **ESLint** - Linting
- **Lucide React** - Icons
- **class-variance-authority** - Variant helpers
- **tailwind-merge** - Tailwind class merging

## Current Structure

```text
frontend/
├── src/
│   ├── app/
│   │   ├── globals.css
│   │   ├── layout.tsx
│   │   └── page.tsx
│   └── lib/
│       └── utils.ts
├── next.config.js
├── tailwind.config.ts
├── eslint.config.mjs
├── biome.json
└── package.json
```

## Key Files

- `frontend/src/app/page.tsx` - 当前首页入口
- `frontend/src/app/layout.tsx` - 全局布局
- `frontend/src/app/globals.css` - 全局样式
- `frontend/src/lib/utils.ts` - 通用工具函数
- `frontend/package.json` - 依赖与脚本定义

## Development Commands

在 `frontend/` 目录中可用：

```bash
npm run lint
npm run format
npm run dev
npm run build
npm run start
```

默认优先级：
- 完成代码修改后先运行 `npm run lint`
- 仅在任务需要时运行 `npm run format`
- 只有用户明确要求预览、调试或构建时，再运行 `dev` / `build` / `start`

## Coding Guidance

- 页面和布局优先放在 `src/app/`
- 可复用工具函数放在 `src/lib/`
- 优先使用 TypeScript 和函数式 React 组件
- 保持 Tailwind class 简洁，复杂样式抽到工具函数或语义化组件中
- 新增用户可见文案时，注意后续是否需要抽离为多语言资源

## Validation

推荐的最小验证流程：

```bash
cd frontend
npm run lint
```
