# Mobile Agents Guide

详细说明见 `mobile/CLAUDE.md`。

## Agent Rules

- `mobile/` 是 macOS 客户端工程，不是通用 H5 或 React Native 项目
- 代码修改优先落在 `mobile/CodeOrb/`，不要编辑 `mobile/build/` 或 `mobile/releases/` 产物
- 涉及构建、签名、打包时，优先参考 `mobile/README.md` 与 `mobile/scripts/`
- 除非用户明确要求，否则不要主动执行发布脚本或生成新的 release 文件
