# Code Orb Backend

Backend API foundation for the Code Orb web frontend and desktop app.

## Current Scope

This first pass initializes a minimal NestJS backend with:

- environment-based configuration
- a shared Nest bootstrap setup
- CORS configuration for web and app clients
- Swagger docs for API discovery
- a health endpoint for deployment checks
- starter auth, session, and current-user endpoints
- device registration and heartbeat endpoints for desktop/web clients
- synced client session snapshots for live session lists
- email/password auth plus anonymous-account upgrade
- zero-config local persistence with SQL.js plus Postgres-ready config

The real business modules can now be added incrementally without reshaping the project.

## Commands

```bash
npm install
npm run start:dev
```

Other useful commands:

```bash
npm run build
npm run lint
npm run test:e2e
```

## Default URLs

- API: `http://localhost:3101/api`
- Swagger: `http://localhost:3101/api/docs`
- Health: `http://localhost:3101/api/health`
- Create guest session: `POST http://localhost:3101/api/auth/anonymous`
- Register email account: `POST http://localhost:3101/api/auth/register/email`
- Login with email: `POST http://localhost:3101/api/auth/login/email`
- Upgrade anonymous account: `POST http://localhost:3101/api/auth/upgrade/email`
- Current user profile: `GET http://localhost:3101/api/users/me`
- Register device: `POST http://localhost:3101/api/devices/register`
- Sync sessions: `POST http://localhost:3101/api/sessions/sync`
- Sessions summary: `GET http://localhost:3101/api/sessions/summary`

## Environment Variables

Copy `.env.example` to `.env` and adjust as needed.

| Variable | Default | Description |
| --- | --- | --- |
| `NODE_ENV` | `development` | Runtime environment |
| `APP_NAME` | `Code Orb API` | Service name shown in docs and health payloads |
| `PORT` | `3101` | HTTP port |
| `API_PREFIX` | `api` | Global route prefix |
| `SWAGGER_ENABLED` | `true` | Whether Swagger is exposed |
| `CORS_ORIGINS` | `http://localhost:3000` | Comma-separated list of allowed browser origins |
| `DATABASE_URL` | empty | Optional Postgres connection string |
| `DATABASE_STORAGE` | `code-orb-dev.sqlite` | Local SQL.js file used when `DATABASE_URL` is not set |
| `DB_SYNC` | `true` | Auto-sync entities for the current environment |
| `JWT_SECRET` | `change-me-for-production` | JWT signing secret |
| `JWT_EXPIRES_IN` | `30d` | Access token lifetime |

## Suggested Next Modules

- `devices` for desktop app registration and telemetry-safe status
- `sessions` for session sync, state aggregation, and activity APIs
- `billing` for plans, entitlements, and limits

## Integration Docs

- `docs/client-integration.md` - end-to-end flow and client-side request/response shapes
