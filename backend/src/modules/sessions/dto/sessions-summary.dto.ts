import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class SessionsSummaryDto {
  @ApiProperty()
  total!: number;

  @ApiProperty()
  active!: number;

  @ApiProperty()
  ended!: number;

  @ApiProperty()
  archived!: number;

  @ApiProperty()
  attention!: number;

  @ApiProperty()
  focused!: number;

  @ApiPropertyOptional({ type: Object })
  byProvider!: Record<string, number>;
}
