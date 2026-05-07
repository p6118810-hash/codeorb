import { INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

function parseCorsOrigins(rawOrigins: string | undefined): string[] {
  if (!rawOrigins || rawOrigins.trim() === '') {
    return ['*'];
  }

  return rawOrigins
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
}

export async function configureApp(app: INestApplication) {
  const configService = app.get(ConfigService);
  const appName = configService.get<string>('APP_NAME') ?? 'Code Orb API';
  const prefix = configService.get<string>('API_PREFIX') ?? 'api';
  const port = configService.get<number>('PORT') ?? 3101;
  const swaggerEnabled = configService.get<boolean>('SWAGGER_ENABLED') ?? true;
  const corsOrigins = parseCorsOrigins(configService.get<string>('CORS_ORIGINS'));

  app.enableShutdownHooks();
  app.setGlobalPrefix(prefix);
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
      transformOptions: {
        enableImplicitConversion: true
      }
    })
  );

  app.enableCors({
    origin: (origin, callback) => {
      if (!origin) {
        return callback(null, true);
      }

      if (corsOrigins.includes('*') || corsOrigins.includes(origin)) {
        return callback(null, true);
      }

      return callback(new Error(`Origin ${origin} is not allowed by CORS`), false);
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept-Language', 'X-Request-Id']
  });

  if (swaggerEnabled) {
    const document = SwaggerModule.createDocument(
      app,
      new DocumentBuilder()
        .setTitle(appName)
        .setDescription('Code Orb backend API for web and desktop clients')
        .setVersion('0.1.0')
        .build()
    );

    SwaggerModule.setup('docs', app, document, {
      useGlobalPrefix: true
    });
  }

  return {
    port,
    prefix,
    swaggerEnabled
  };
}
