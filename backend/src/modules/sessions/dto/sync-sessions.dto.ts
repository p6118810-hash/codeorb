import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested
} from 'class-validator';
import { Type } from 'class-transformer';

export class SyncSessionItemDto {
  @ApiProperty()
  @IsString()
  @MaxLength(160)
  externalSessionId!: string;

  @ApiProperty({ enum: ['codex', 'claude', 'cursor', 'gemini', 'other'] })
  @IsString()
  @IsIn(['codex', 'claude', 'cursor', 'gemini', 'other'])
  provider!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(200)
  title?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(400)
  cwd?: string;

  @ApiProperty({ description: 'Current lifecycle phase such as idle, processing, waitingForApproval, ended' })
  @IsString()
  @MaxLength(80)
  phase!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isFocused?: boolean;

  @ApiPropertyOptional({ type: Object })
  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  startedAt?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  lastActivityAt?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  endedAt?: string;
}

export class SyncSessionsDto {
  @ApiProperty()
  @IsString()
  deviceId!: string;

  @ApiProperty({ type: SyncSessionItemDto, isArray: true })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SyncSessionItemDto)
  sessions!: SyncSessionItemDto[];

  @ApiPropertyOptional({ description: 'Mark missing active sessions from this device as ended' })
  @IsOptional()
  @IsBoolean()
  archiveMissing?: boolean;
}
