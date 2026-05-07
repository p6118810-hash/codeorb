import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModuleAsyncOptions, TypeOrmModuleOptions } from '@nestjs/typeorm';

function buildLocalSqljsOptions(configService: ConfigService): TypeOrmModuleOptions {
  return {
    type: 'sqljs',
    driver: require('sql.js'),
    location: configService.get<string>('DATABASE_STORAGE') ?? 'code-orb-dev.sqlite',
    autoSave: true,
    autoLoadEntities: true,
    synchronize: configService.get<boolean>('DB_SYNC') ?? true
  };
}

function buildPostgresOptions(configService: ConfigService): TypeOrmModuleOptions {
  return {
    type: 'postgres',
    url: configService.get<string>('DATABASE_URL'),
    autoLoadEntities: true,
    synchronize: configService.get<boolean>('DB_SYNC') ?? false,
    ssl: configService.get<string>('NODE_ENV') === 'production' ? { rejectUnauthorized: false } : false
  };
}

export function getDatabaseConfig(configService: ConfigService): TypeOrmModuleOptions {
  const databaseUrl = configService.get<string>('DATABASE_URL');
  return databaseUrl ? buildPostgresOptions(configService) : buildLocalSqljsOptions(configService);
}

export const databaseModuleOptions: TypeOrmModuleAsyncOptions = {
  imports: [ConfigModule],
  inject: [ConfigService],
  useFactory: (configService: ConfigService) => getDatabaseConfig(configService)
};
