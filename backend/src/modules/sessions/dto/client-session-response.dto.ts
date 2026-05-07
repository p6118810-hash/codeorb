import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class ClientSessionResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  deviceId!: string;

  @ApiProperty()
  externalSessionId!: string;

  @ApiProperty()
  provider!: string;

  @ApiPropertyOptional()
  title?: string | null;

  @ApiPropertyOptional()
  cwd?: string | null;

  @ApiProperty()
  phase!: string;

  @ApiProperty()
  isFocused!: boolean;

  @ApiPropertyOptional({ type: Object })
  metadata?: Record<string, unknown> | null;

  @ApiPropertyOptional()
  startedAt?: Date | null;

  @ApiPropertyOptional()
  lastActivityAt?: Date | null;

  @ApiPropertyOptional()
  endedAt?: Date | null;

  @ApiPropertyOptional()
  archivedAt?: Date | null;

  @ApiProperty()
  createdAt!: Date;

  @ApiProperty()
  updatedAt!: Date;
}
