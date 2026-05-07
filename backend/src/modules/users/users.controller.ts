import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AuthenticatedRequestUser } from '../auth/interfaces/authenticated-request-user.interface';
import { UpdateMeDto } from './dto/update-me.dto';
import { UserResponseDto } from './dto/user-response.dto';
import { UsersService } from './users.service';

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Get the current authenticated user' })
  @ApiOkResponse({ type: UserResponseDto })
  async getMe(@CurrentUser() user: AuthenticatedRequestUser): Promise<UserResponseDto> {
    const entity = await this.usersService.getByIdOrThrow(user.userId);
    return this.usersService.toResponseDto(entity);
  }

  @Patch('me')
  @ApiOperation({ summary: 'Update the current authenticated user profile' })
  @ApiOkResponse({ type: UserResponseDto })
  async updateMe(
    @CurrentUser() user: AuthenticatedRequestUser,
    @Body() dto: UpdateMeDto
  ): Promise<UserResponseDto> {
    const entity = await this.usersService.updateMe(user.userId, dto);
    return this.usersService.toResponseDto(entity);
  }
}
