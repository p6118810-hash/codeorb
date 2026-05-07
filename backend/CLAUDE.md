# CodeOrb Backend Workspace Guide

## 重要说明

当前 `backend/` 目录还没有正式后端源码，现有内容主要是 `.setting.zhd/` 工具状态目录。

在这个目录工作时请遵守：
- 不要修改 `.setting.zhd/` 下的日志和缓存文件
- 不要擅自初始化数据库、启动服务、安装依赖或生成后端模板
- 如果用户明确要求新增 API / webhook / relay / sync 服务，请把实现集中放在 `backend/` 中

## Workspace Status

`backend/` 目前属于预留目录，可用于未来的后端服务、接口层、同步任务或本地桥接服务。

当前可见内容：
- `.setting.zhd/` - 本地工具状态和日志

## Expected Responsibilities

如果后续在本目录落地代码，通常会承担这些职责：
- 为 `frontend/` 提供 API 或 BFF
- 为 `mobile/` 提供同步、推送、状态聚合或鉴权能力
- 承接 webhook、队列任务或后台管理接口

## Directory Rules

推荐约定：
- 源码放在 `backend/src/`
- 配置样例使用 `.env.example`
- 脚本放在根目录 `scripts/`，避免和业务源码混在一起
- 不要提交本地数据库、日志、缓存和构建产物

## Validation

当前目录没有可执行的 lint / test / build 命令。

如果后续创建真实后端项目，请同步补充：
- 技术栈与入口文件
- 安装 / 启动 / 构建命令
- lint / test / type-check / migration 命令
- 环境变量与依赖服务说明
