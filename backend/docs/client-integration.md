# Code Orb Client Integration

This is the current integration contract for the Code Orb backend. It covers:

- the Next.js web frontend
- the macOS app in `mobile/CodeOrb`

## Recommended Flow

1. Create an anonymous session with `POST /api/auth/anonymous`
2. Persist the returned `accessToken`
3. Register the current machine or browser with `POST /api/devices/register`
4. Heartbeat the device periodically with `POST /api/devices/:deviceId/heartbeat`
5. Sync live session snapshots with `POST /api/sessions/sync`
6. Read dashboard views with `GET /api/sessions/me` and `GET /api/sessions/summary`
7. If the user wants a durable account, call `POST /api/auth/upgrade/email`

## TypeScript Shapes

```ts
export type AuthUser = {
  id: string;
  displayName: string;
  email: string | null;
  avatarUrl: string | null;
  role: string;
  authProvider: "anonymous" | "email";
  hasPassword: boolean;
  metadata: Record<string, unknown> | null;
  lastSeenAt: string | null;
  createdAt: string;
  updatedAt: string;
};

export type AuthSessionResponse = {
  accessToken: string;
  sessionId: string;
  user: AuthUser;
};

export type Device = {
  id: string;
  deviceIdentifier: string;
  name: string;
  kind: "desktop" | "web" | "mobile";
  platform: string;
  appVersion: string | null;
  buildNumber: string | null;
  metadata: Record<string, unknown> | null;
  lastSeenAt: string | null;
  createdAt: string;
  updatedAt: string;
};

export type SyncedSession = {
  id: string;
  deviceId: string;
  externalSessionId: string;
  provider: "codex" | "claude" | "cursor" | "gemini" | "other";
  title: string | null;
  cwd: string | null;
  phase: string;
  isFocused: boolean;
  metadata: Record<string, unknown> | null;
  startedAt: string | null;
  lastActivityAt: string | null;
  endedAt: string | null;
  archivedAt: string | null;
  createdAt: string;
  updatedAt: string;
};
```

## Swift Codable Shapes

```swift
struct AuthUser: Codable {
    let id: String
    let displayName: String
    let email: String?
    let avatarUrl: String?
    let role: String
    let authProvider: String
    let hasPassword: Bool
    let metadata: [String: StringCodable]?
    let lastSeenAt: String?
    let createdAt: String
    let updatedAt: String
}

struct AuthSessionResponse: Codable {
    let accessToken: String
    let sessionId: String
    let user: AuthUser
}

struct RegisterDeviceRequest: Codable {
    let deviceIdentifier: String
    let name: String
    let kind: String
    let platform: String
    let appVersion: String?
    let buildNumber: String?
    let metadata: [String: StringCodable]?
}

struct SyncSessionItem: Codable {
    let externalSessionId: String
    let provider: String
    let title: String?
    let cwd: String?
    let phase: String
    let isFocused: Bool
    let metadata: [String: StringCodable]?
    let startedAt: String?
    let lastActivityAt: String?
    let endedAt: String?
}
```

`StringCodable` above stands for your own Codable wrapper for mixed JSON values.

## Session Sync Mapping

These local app values map well into the backend session payload:

- local `sessionId` -> `externalSessionId`
- provider kind (`codex`, `claude`) -> `provider`
- `displayTitle` or `summary` -> `title`
- `cwd` -> `cwd`
- `phase` -> `phase`
- focused state from terminal visibility -> `isFocused`
- extra diagnostics -> `metadata`
- `createdAt` -> `startedAt`
- `lastActivity` -> `lastActivityAt`

## Practical Rules

- Register one device record per installation or machine profile
- Heartbeat every 30-90 seconds while the client is active
- Sync active sessions every few seconds when the app is open
- Send `archiveMissing: true` only when the payload is the complete active set for that device
- Archive sessions from the UI with `POST /api/sessions/:sessionId/archive`
- Use `GET /api/sessions/me?state=active&provider=codex` for filtered views

## Account Upgrade

Anonymous users can be upgraded without losing their synced devices or sessions:

- call `POST /api/auth/upgrade/email`
- replace the old `accessToken` with the newly returned token
- keep using the same device and session identifiers
