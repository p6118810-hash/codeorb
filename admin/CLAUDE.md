# CodeOrb Admin Workspace Guide

## 重要说明

当前 `admin/` 目录还没有正式的业务源码，现有内容主要是本地工具状态目录 `.setting.zhd/`。

在这个目录工作时请遵守：
- 不要修改 `.setting.zhd/` 下的日志或缓存文件，除非用户明确要求
- 不要擅自为 `admin/` 启动新服务、安装依赖或初始化脚手架
- 如果任务需要新增后台项目，请先围绕 `admin/` 目录落盘，不要把文件散落到其他子项目中

## Workspace Status

`admin/` 目前是预留目录，可用于未来的管理后台、运营面板或内部工具。

当前可见内容：
- `.setting.zhd/` - 本地工具状态和日志

## Directory Rules

如果后续在本目录中落地代码，请优先遵守这些约定：
- 源码放在 `admin/src/` 或框架默认源码目录
- 静态资源放在 `admin/public/` 或平台约定位置
- 不要提交运行时缓存、构建产物或本地 IDE 临时文件

## Documentation Rules

工作区级文档建议统一放在仓库根目录：
- `docs/` - 设计、架构、联调、部署说明
- `scripts/` - 脚本和自动化工具

如果只是 `admin/` 独有的说明，可以保留在本目录，但应尽量简洁。

## Development Guidance

由于当前没有现成工程，默认策略是：
- 先补充需求和目录结构，再开始实现
- 新增代码前，优先确认是否应复用 `frontend/` 或 `mobile/` 的现有能力
- 若用户要求创建后台项目，优先补齐 `README`、`CLAUDE.md`、`AGENTS.md` 与基础目录结构

## Validation

当前目录没有可执行的 lint / test / build 命令。

如果后续引入框架，请同步把以下内容补到本文件：
- 安装命令
- 启动命令
- lint / type-check / test 命令
- 环境变量说明
