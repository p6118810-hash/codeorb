import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import type { IncomingMessage, RequestListener, ServerResponse } from 'http';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/app.setup';

let cachedServer: RequestListener | undefined;

async function getServer(): Promise<RequestListener> {
  if (cachedServer) {
    return cachedServer;
  }

  const app = await NestFactory.create(AppModule, { logger: ['error', 'warn', 'log'] });
  await configureApp(app);
  await app.init();

  cachedServer = app.getHttpAdapter().getInstance() as RequestListener;
  return cachedServer;
}

export default async function handler(req: unknown, res: unknown) {
  const server = await getServer();
  return server(req as IncomingMessage, res as ServerResponse);
}
