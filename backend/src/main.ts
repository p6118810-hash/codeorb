import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { configureApp } from './app.setup';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const { port, prefix, swaggerEnabled } = await configureApp(app);

  await app.listen(port);

  console.log(`Code Orb backend is running on http://localhost:${port}/${prefix}`);
  if (swaggerEnabled) {
    console.log(`Swagger docs available at http://localhost:${port}/${prefix}/docs`);
  }
}

bootstrap();
