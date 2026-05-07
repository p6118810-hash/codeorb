import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsObject, IsOptional, IsString, MaxLength } from 'class-validator';

export class RegisterDeviceDto {
  @ApiProperty({ description: 'Stable client-generated device identifier' })
  @IsString()
  @MaxLength(120)
  deviceIdentifier!: string;

  @ApiProperty({ description: 'Human-readable device name shown in the UI' })
  @IsString()
  @MaxLength(120)
  name!: string;

  @ApiProperty({ description: 'Device kind', enum: ['desktop', 'web', 'mobile'] })
  @IsString()
  @IsIn(['desktop', 'web', 'mobile'])
  kind!: string;

  @ApiProperty({ description: 'Platform name such as macos, ios, web' })
  @IsString()
  @MaxLength(80)
  platform!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(40)
  appVersion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(40)
  buildNumber?: string;

  @ApiPropertyOptional({ type: Object })
  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}
