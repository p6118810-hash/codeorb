import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsObject, IsOptional, IsString, MaxLength } from 'class-validator';

export class AnonymousAuthDto {
  @ApiPropertyOptional({ description: 'Optional display name for the guest user' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  displayName?: string;

  @ApiPropertyOptional({ description: 'Client source such as web, macos, ios, android' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  source?: string;

  @ApiPropertyOptional({ description: 'Platform information from the client app' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  platform?: string;

  @ApiPropertyOptional({ description: 'Stable client-side device identifier' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  deviceId?: string;

  @ApiPropertyOptional({ description: 'Additional client metadata', type: Object })
  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}
