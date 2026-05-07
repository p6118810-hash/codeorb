# Frontend Agents Guide

详细说明见 `frontend/CLAUDE.md`。

## Agent Rules

- 这是一个 Next.js 15 App Router 项目，优先在 `frontend/src/` 内修改源码
- 不要编辑 `frontend/node_modules/`、`frontend/.next/` 或锁文件之外的生成产物
- 完成前端改动后，默认运行 `cd frontend && npm run lint`
- 除非用户明确要求，否则不要主动启动开发服务器或执行生产构建
- 新增结构时，优先沿用 `src/app/` 与 `src/lib/` 的现有分层
