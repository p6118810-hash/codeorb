import { Body, Controller, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UsersService } from '../users/users.service';
import { AnonymousAuthDto } from './dto/anonymous-auth.dto';
import { LoginEmailDto } from './dto/login-email.dto';
import { RegisterEmailDto } from './dto/register-email.dto';
import { UpgradeAccountDto } from './dto/upgrade-account.dto';
import { ValidateTokenDto } from './dto/validate-token.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { AuthenticatedRequestUser } from './interfaces/authenticated-request-user.interface';
import { AuthService } from './auth.service';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly usersService: UsersService
  ) {}

  @Post('anonymous')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create an anonymous user session for web or app onboarding' })
  @ApiOkResponse({ description: 'Returns a newly issued access token and user payload' })
  createAnonymousSession(@Body() dto: AnonymousAuthDto) {
    return this.authService.createAnonymousSession(dto);
  }

  @Post('register/email')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Register a new email/password account' })
  registerWithEmail(@Body() dto: RegisterEmailDto) {
    return this.authService.registerWithEmail(dto);
  }

  @Post('login/email')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Sign in with email and password' })
  loginWithEmail(@Body() dto: LoginEmailDto) {
    return this.authService.loginWithEmail(dto);
  }

  @Post('upgrade/email')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Upgrade the current anonymous account to an email/password account' })
  upgradeAnonymousAccount(
    @CurrentUser() user: AuthenticatedRequestUser,
    @Body() dto: UpgradeAccountDto
  ) {
    return this.authService.upgradeAnonymousAccount(user.userId, user.sessionId, dto);
  }

  @Post('validate')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Validate an access token and fetch the bound user' })
  @ApiOkResponse({ description: 'Returns whether the supplied token is still valid' })
  validateToken(@Body() dto: ValidateTokenDto) {
    return this.authService.validateAccessToken(dto.accessToken);
  }

  @Post('logout')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Revoke the current session' })
  async logout(@CurrentUser() user: AuthenticatedRequestUser) {
    await this.authService.revokeBySessionId(user.sessionId);
    return { success: true };
  }

  @Post('whoami')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Get the authenticated user from the current token' })
  async whoAmI(@CurrentUser() user: AuthenticatedRequestUser) {
    const entity = await this.usersService.getByIdOrThrow(user.userId);
    return this.usersService.toResponseDto(entity);
  }
}
