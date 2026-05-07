import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class UserResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  displayName!: string;

  @ApiPropertyOptional()
  email?: string | null;

  @ApiPropertyOptional()
  avatarUrl?: string | null;

  @ApiProperty()
  role!: string;

  @ApiProperty()
  authProvider!: string;

  @ApiProperty()
  hasPassword!: boolean;

  @ApiPropertyOptional({ type: Object })
  metadata?: Record<string, unknown> | null;

  @ApiPropertyOptional()
  lastSeenAt?: Date | null;

  @ApiProperty()
  createdAt!: Date;

  @ApiProperty()
  updatedAt!: Date;
}
