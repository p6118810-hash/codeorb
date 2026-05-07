type EnvShape = Record<string, unknown>;

function parseNumber(value: unknown, fallback: number, key: string): number {
  if (value === undefined || value === null || value === '') {
    return fallback;
  }

  const parsed = Number(value);
  if (Number.isNaN(parsed)) {
    throw new Error(`${key} must be a valid number`);
  }

  return parsed;
}

function parseBoolean(value: unknown, fallback: boolean, key: string): boolean {
  if (value === undefined || value === null || value === '') {
    return fallback;
  }

  if (typeof value === 'boolean') {
    return value;
  }

  const normalized = String(value).trim().toLowerCase();
  if (normalized === 'true') {
    return true;
  }

  if (normalized === 'false') {
    return false;
  }

  throw new Error(`${key} must be either true or false`);
}

function parseNodeEnv(value: unknown): 'development' | 'test' | 'production' {
  const normalized = String(value ?? 'development').trim() as 'development' | 'test' | 'production';
  if (normalized === 'development' || normalized === 'test' || normalized === 'production') {
    return normalized;
  }

  throw new Error('NODE_ENV must be development, test, or production');
}

export function validateEnv(config: EnvShape) {
  return {
    NODE_ENV: parseNodeEnv(config.NODE_ENV),
    APP_NAME: String(config.APP_NAME ?? 'Code Orb API'),
    PORT: parseNumber(config.PORT, 3101, 'PORT'),
    API_PREFIX: String(config.API_PREFIX ?? 'api'),
    SWAGGER_ENABLED: parseBoolean(config.SWAGGER_ENABLED, true, 'SWAGGER_ENABLED'),
    CORS_ORIGINS: String(config.CORS_ORIGINS ?? '*'),
    DATABASE_URL: config.DATABASE_URL ? String(config.DATABASE_URL) : undefined,
    DATABASE_STORAGE: String(config.DATABASE_STORAGE ?? 'code-orb-dev.sqlite'),
    DB_SYNC: parseBoolean(config.DB_SYNC, true, 'DB_SYNC'),
    JWT_SECRET: String(config.JWT_SECRET ?? 'change-me-for-production'),
    JWT_EXPIRES_IN: String(config.JWT_EXPIRES_IN ?? '30d')
  };
}
