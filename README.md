# CodeOrb

CodeOrb is an open source workspace for the Codex companion projects in this repository.

Website: https://www.codeorb.app

It currently includes:

- `mobile/` - the macOS menu bar client
- `frontend/` - the Next.js web experience
- `backend/` - the NestJS API foundation
- `admin/` and `app/` - reserved workspace directories

## What This Repo Is

This repository is organized as a workspace, not a single application. Each major surface lives in its own directory and has its own tooling, docs, and development commands.

## Getting Started

### macOS client

```bash
cd mobile
xcodebuild -scheme CodeOrb -configuration Release build
```

### Frontend

```bash
cd frontend
npm install
npm run dev
```

### Backend

```bash
cd backend
npm install
npm run start:dev
```

## Repository Notes

- Local build artifacts, editor state, and signing material are ignored through `.gitignore`.
- The repo is intended to be open source friendly: source files, docs, and scripts are committed; generated output stays local.
- Platform-specific guidance lives in the per-directory `CLAUDE.md` and `AGENTS.md` files.

## License

This project is licensed under the Apache License 2.0. See [`LICENSE`](LICENSE).
