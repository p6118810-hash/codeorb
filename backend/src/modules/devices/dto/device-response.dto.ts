import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class DeviceResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  deviceIdentifier!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty()
  kind!: string;

  @ApiProperty()
  platform!: string;

  @ApiPropertyOptional()
  appVersion?: string | null;

  @ApiPropertyOptional()
  buildNumber?: string | null;

  @ApiPropertyOptional({ type: Object })
  metadata?: Record<string, unknown> | null;

  @ApiPropertyOptional()
  lastSeenAt?: Date | null;

  @ApiProperty()
  createdAt!: Date;

  @ApiProperty()
  updatedAt!: Date;
}
