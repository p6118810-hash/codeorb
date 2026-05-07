import { ApiProperty } from '@nestjs/swagger';
import { IsString } from 'class-validator';

export class ValidateTokenDto {
  @ApiProperty({ description: 'JWT access token returned by the backend' })
  @IsString()
  accessToken!: string;
}
