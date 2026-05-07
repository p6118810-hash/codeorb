import { INestApplication } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { rmSync } from 'fs';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/app.setup';

jest.setTimeout(20000);

describe('AppController (e2e)', () => {
  let app: INestApplication;
  const databaseStorage = 'code-orb-test.sqlite';

  beforeAll(async () => {
    process.env.NODE_ENV = 'test';
    process.env.DATABASE_URL = '';
    process.env.DATABASE_STORAGE = databaseStorage;
    process.env.DB_SYNC = 'true';

    rmSync(databaseStorage, { force: true });

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule]
    }).compile();

    app = moduleFixture.createNestApplication();
    await configureApp(app);
    await app.init();
  });

  afterAll(async () => {
    if (app) {
      await app.close();
    }
    rmSync(databaseStorage, { force: true });
  });

  it('/api/health (GET)', async () => {
    const response = await request(app.getHttpServer()).get('/api/health').expect(200);

    expect(response.body).toMatchObject({
      status: 'ok'
    });
    expect(typeof response.body.timestamp).toBe('string');
  });

  it('creates, validates, and uses an anonymous session', async () => {
    const sessionResponse = await request(app.getHttpServer())
      .post('/api/auth/anonymous')
      .send({
        displayName: 'Orb Tester',
        source: 'web',
        platform: 'test-suite'
      })
      .expect(201);

    expect(sessionResponse.body.accessToken).toEqual(expect.any(String));
    expect(sessionResponse.body.user.displayName).toBe('Orb Tester');

    const validateResponse = await request(app.getHttpServer())
      .post('/api/auth/validate')
      .send({
        accessToken: sessionResponse.body.accessToken
      })
      .expect(200);

    expect(validateResponse.body.valid).toBe(true);
    expect(validateResponse.body.user.id).toBe(sessionResponse.body.user.id);

    const meResponse = await request(app.getHttpServer())
      .get('/api/users/me')
      .set('Authorization', `Bearer ${sessionResponse.body.accessToken}`)
      .expect(200);

    expect(meResponse.body.displayName).toBe('Orb Tester');
    expect(meResponse.body.hasPassword).toBe(false);
  });

  it('registers a device, syncs sessions, and supports summary/archive flows', async () => {
    const sessionResponse = await request(app.getHttpServer())
      .post('/api/auth/anonymous')
      .send({
        displayName: 'Sync Tester',
        source: 'desktop',
        platform: 'macos'
      })
      .expect(201);

    const token = sessionResponse.body.accessToken as string;

    const deviceResponse = await request(app.getHttpServer())
      .post('/api/devices/register')
      .set('Authorization', `Bearer ${token}`)
      .send({
        deviceIdentifier: 'macbook-pro-main',
        name: 'MacBook Pro',
        kind: 'desktop',
        platform: 'macos',
        appVersion: '1.3.0'
      })
      .expect(201);

    expect(deviceResponse.body.deviceIdentifier).toBe('macbook-pro-main');

    const syncedSessionsResponse = await request(app.getHttpServer())
      .post('/api/sessions/sync')
      .set('Authorization', `Bearer ${token}`)
      .send({
        deviceId: deviceResponse.body.id,
        archiveMissing: true,
        sessions: [
          {
            externalSessionId: 'codex-123',
            provider: 'codex',
            title: 'Fix backend auth flow',
            cwd: '/Users/admin/WebstormProjects/code-orb-workspace/backend',
            phase: 'processing',
            isFocused: true,
            metadata: {
              providerDisplayName: 'Codex',
              projectName: 'backend'
            },
            startedAt: '2026-04-23T08:00:00.000Z',
            lastActivityAt: '2026-04-23T08:05:00.000Z'
          }
        ]
      })
      .expect(201);

    expect(syncedSessionsResponse.body).toHaveLength(1);
    expect(syncedSessionsResponse.body[0].externalSessionId).toBe('codex-123');

    const sessionsListResponse = await request(app.getHttpServer())
      .get('/api/sessions/me?provider=codex&state=active')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(sessionsListResponse.body[0].title).toBe('Fix backend auth flow');

    const activeDeviceSessionsResponse = await request(app.getHttpServer())
      .get(`/api/sessions/devices/${deviceResponse.body.id}/active`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(activeDeviceSessionsResponse.body).toHaveLength(1);
    expect(activeDeviceSessionsResponse.body[0].isFocused).toBe(true);

    const summaryResponse = await request(app.getHttpServer())
      .get('/api/sessions/summary')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(summaryResponse.body.total).toBe(1);
    expect(summaryResponse.body.active).toBe(1);
    expect(summaryResponse.body.byProvider.codex).toBe(1);

    const archivedResponse = await request(app.getHttpServer())
      .post(`/api/sessions/${syncedSessionsResponse.body[0].id}/archive`)
      .set('Authorization', `Bearer ${token}`)
      .expect(201);

    expect(archivedResponse.body.archivedAt).toEqual(expect.any(String));

    const defaultListAfterArchive = await request(app.getHttpServer())
      .get('/api/sessions/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(defaultListAfterArchive.body).toHaveLength(0);

    const archivedList = await request(app.getHttpServer())
      .get('/api/sessions/me?includeArchived=true')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(archivedList.body).toHaveLength(1);

    const unarchivedResponse = await request(app.getHttpServer())
      .post(`/api/sessions/${syncedSessionsResponse.body[0].id}/unarchive`)
      .set('Authorization', `Bearer ${token}`)
      .expect(201);

    expect(unarchivedResponse.body.archivedAt).toBeNull();
  });

  it('registers an email account, logs in, and upgrades an anonymous account', async () => {
    const registerResponse = await request(app.getHttpServer())
      .post('/api/auth/register/email')
      .send({
        email: 'orb@example.com',
        password: 'strong-pass-123',
        displayName: 'Orb Email User'
      })
      .expect(201);

    expect(registerResponse.body.user.email).toBe('orb@example.com');
    expect(registerResponse.body.user.authProvider).toBe('email');
    expect(registerResponse.body.user.hasPassword).toBe(true);

    const loginResponse = await request(app.getHttpServer())
      .post('/api/auth/login/email')
      .send({
        email: 'orb@example.com',
        password: 'strong-pass-123'
      })
      .expect(200);

    expect(loginResponse.body.user.id).toBe(registerResponse.body.user.id);

    const anonymousResponse = await request(app.getHttpServer())
      .post('/api/auth/anonymous')
      .send({
        displayName: 'Temp Guest',
        source: 'web',
        platform: 'browser'
      })
      .expect(201);

    const upgradedResponse = await request(app.getHttpServer())
      .post('/api/auth/upgrade/email')
      .set('Authorization', `Bearer ${anonymousResponse.body.accessToken}`)
      .send({
        email: 'guest-upgraded@example.com',
        password: 'guest-pass-123',
        displayName: 'Upgraded Guest'
      })
      .expect(200);

    expect(upgradedResponse.body.user.email).toBe('guest-upgraded@example.com');
    expect(upgradedResponse.body.user.authProvider).toBe('email');
    expect(upgradedResponse.body.user.displayName).toBe('Upgraded Guest');
    expect(upgradedResponse.body.user.hasPassword).toBe(true);
  });
});
