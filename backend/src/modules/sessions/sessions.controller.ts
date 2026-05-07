import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AuthenticatedRequestUser } from '../auth/interfaces/authenticated-request-user.interface';
import { ClientSessionResponseDto } from './dto/client-session-response.dto';
import { ListSessionsQueryDto } from './dto/list-sessions-query.dto';
import { SyncSessionsDto } from './dto/sync-sessions.dto';
import { SessionsSummaryDto } from './dto/sessions-summary.dto';
import { SessionsService } from './sessions.service';

@ApiTags('sessions')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('sessions')
export class SessionsController {
  constructor(private readonly sessionsService: SessionsService) {}

  @Post('sync')
  @ApiOperation({ summary: 'Upsert session snapshots reported by a client device' })
  @ApiOkResponse({ type: ClientSessionResponseDto, isArray: true })
  async sync(
    @CurrentUser() user: AuthenticatedRequestUser,
    @Body() dto: SyncSessionsDto
  ): Promise<ClientSessionResponseDto[]> {
    const sessions = await this.sessionsService.syncSessions(user.userId, dto);
    return sessions.map((session) => this.sessionsService.toResponseDto(session));
  }

  @Get('me')
  @ApiOperation({ summary: 'List synced sessions for the current user with filtering and pagination' })
  @ApiOkResponse({ type: ClientSessionResponseDto, isArray: true })
  async list(
    @CurrentUser() user: AuthenticatedRequestUser,
    @Query() query: ListSessionsQueryDto
  ): Promise<ClientSessionResponseDto[]> {
    const sessions = await this.sessionsService.listForUser(user.userId, query);
    return sessions.map((session) => this.sessionsService.toResponseDto(session));
  }

  @Get('summary')
  @ApiOperation({ summary: 'Get aggregate session counts for the current user' })
  @ApiOkResponse({ type: SessionsSummaryDto })
  summary(@CurrentUser() user: AuthenticatedRequestUser): Promise<SessionsSummaryDto> {
    return this.sessionsService.getSummary(user.userId);
  }

  @Get('devices/:deviceId/active')
  @ApiOperation({ summary: 'List active sessions for a specific device' })
  @ApiOkResponse({ type: ClientSessionResponseDto, isArray: true })
  async listActiveForDevice(
    @CurrentUser() user: AuthenticatedRequestUser,
    @Param('deviceId') deviceId: string
  ): Promise<ClientSessionResponseDto[]> {
    const sessions = await this.sessionsService.listActiveForDevice(user.userId, deviceId);
    return sessions.map((session) => this.sessionsService.toResponseDto(session));
  }

  @Post(':sessionId/archive')
  @ApiOperation({ summary: 'Archive a synced session from the default list' })
  @ApiOkResponse({ type: ClientSessionResponseDto })
  async archive(
    @CurrentUser() user: AuthenticatedRequestUser,
    @Param('sessionId') sessionId: string
  ): Promise<ClientSessionResponseDto> {
    const session = await this.sessionsService.archiveSession(user.userId, sessionId);
    return this.sessionsService.toResponseDto(session);
  }

  @Post(':sessionId/unarchive')
  @ApiOperation({ summary: 'Restore an archived synced session back into the default list' })
  @ApiOkResponse({ type: ClientSessionResponseDto })
  async unarchive(
    @CurrentUser() user: AuthenticatedRequestUser,
    @Param('sessionId') sessionId: string
  ): Promise<ClientSessionResponseDto> {
    const session = await this.sessionsService.unarchiveSession(user.userId, sessionId);
    return this.sessionsService.toResponseDto(session);
  }
}
