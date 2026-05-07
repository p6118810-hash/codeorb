import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { DevicesService } from '../devices/devices.service';
import { ClientSessionResponseDto } from './dto/client-session-response.dto';
import { ListSessionsQueryDto } from './dto/list-sessions-query.dto';
import { SyncSessionItemDto, SyncSessionsDto } from './dto/sync-sessions.dto';
import { SessionsSummaryDto } from './dto/sessions-summary.dto';
import { ClientSession } from './entities/client-session.entity';

@Injectable()
export class SessionsService {
  constructor(
    @InjectRepository(ClientSession)
    private readonly clientSessionsRepository: Repository<ClientSession>,
    private readonly devicesService: DevicesService
  ) {}

  async syncSessions(userId: string, dto: SyncSessionsDto): Promise<ClientSession[]> {
    const device = await this.devicesService.getOwnedDeviceOrThrow(userId, dto.deviceId);
    const syncedExternalIds = new Set<string>();

    for (const item of dto.sessions) {
      syncedExternalIds.add(item.externalSessionId);
      await this.upsertSession(userId, dto.deviceId, item);
    }

    if (dto.archiveMissing) {
      const existingActiveSessions = await this.clientSessionsRepository.find({
        where: {
          userId,
          deviceId: dto.deviceId,
          endedAt: IsNull()
        }
      });

      for (const session of existingActiveSessions) {
        if (!syncedExternalIds.has(session.externalSessionId)) {
          session.phase = 'ended';
          session.endedAt = new Date();
          await this.clientSessionsRepository.save(session);
        }
      }
    }

    await this.devicesService.heartbeat(userId, device.id, {});

    return this.listForUser(userId);
  }

  async listForUser(userId: string, query: ListSessionsQueryDto = {}): Promise<ClientSession[]> {
    const qb = this.clientSessionsRepository
      .createQueryBuilder('session')
      .where('session.user_id = :userId', { userId });

    if (!query.includeArchived) {
      qb.andWhere('session.archived_at IS NULL');
    }

    if (query.deviceId) {
      qb.andWhere('session.device_id = :deviceId', { deviceId: query.deviceId });
    }

    if (query.provider) {
      qb.andWhere('session.provider = :provider', { provider: query.provider });
    }

    if (query.phase) {
      qb.andWhere('session.phase = :phase', { phase: query.phase });
    }

    if (query.state === 'active') {
      qb.andWhere('session.ended_at IS NULL');
    } else if (query.state === 'ended') {
      qb.andWhere('session.ended_at IS NOT NULL');
    }

    if (query.focusedOnly) {
      qb.andWhere('session.is_focused = :focused', { focused: true });
    }

    qb.orderBy('session.archived_at', 'ASC')
      .addOrderBy('session.ended_at', 'ASC')
      .addOrderBy('session.last_activity_at', 'DESC')
      .addOrderBy('session.updated_at', 'DESC')
      .take(query.limit ?? 50)
      .skip(query.offset ?? 0);

    return qb.getMany();
  }

  async listActiveForDevice(userId: string, deviceId: string): Promise<ClientSession[]> {
    await this.devicesService.getOwnedDeviceOrThrow(userId, deviceId);
    return this.clientSessionsRepository.find({
      where: {
        userId,
        deviceId,
        endedAt: IsNull(),
        archivedAt: IsNull()
      },
      order: {
        lastActivityAt: 'DESC',
        updatedAt: 'DESC'
      }
    });
  }

  async getSummary(userId: string): Promise<SessionsSummaryDto> {
    const sessions = await this.clientSessionsRepository.find({
      where: { userId }
    });

    const byProvider: Record<string, number> = {};
    let active = 0;
    let ended = 0;
    let archived = 0;
    let attention = 0;
    let focused = 0;

    for (const session of sessions) {
      byProvider[session.provider] = (byProvider[session.provider] ?? 0) + 1;

      if (session.archivedAt) {
        archived += 1;
      }

      if (session.endedAt) {
        ended += 1;
      } else {
        active += 1;
      }

      if (session.isFocused) {
        focused += 1;
      }

      if (this.needsAttention(session.phase)) {
        attention += 1;
      }
    }

    return {
      total: sessions.length,
      active,
      ended,
      archived,
      attention,
      focused,
      byProvider
    };
  }

  async archiveSession(userId: string, sessionId: string): Promise<ClientSession> {
    const session = await this.getOwnedSessionOrThrow(userId, sessionId);
    session.archivedAt = new Date();
    return this.clientSessionsRepository.save(session);
  }

  async unarchiveSession(userId: string, sessionId: string): Promise<ClientSession> {
    const session = await this.getOwnedSessionOrThrow(userId, sessionId);
    session.archivedAt = null;
    return this.clientSessionsRepository.save(session);
  }

  private async upsertSession(userId: string, deviceId: string, item: SyncSessionItemDto): Promise<ClientSession> {
    const existing = await this.clientSessionsRepository.findOne({
      where: {
        deviceId,
        externalSessionId: item.externalSessionId
      }
    });

    const target = existing ?? this.clientSessionsRepository.create({
      userId,
      deviceId,
      externalSessionId: item.externalSessionId
    });

    target.userId = userId;
    target.deviceId = deviceId;
    target.provider = item.provider;
    target.title = item.title ?? null;
    target.cwd = item.cwd ?? null;
    target.phase = item.phase;
    target.isFocused = item.isFocused ?? false;
    target.metadata = item.metadata ?? target.metadata ?? null;
    target.startedAt = item.startedAt ? new Date(item.startedAt) : target.startedAt ?? null;
    target.lastActivityAt = item.lastActivityAt ? new Date(item.lastActivityAt) : new Date();
    target.endedAt = item.endedAt ? new Date(item.endedAt) : item.phase === 'ended' ? new Date() : null;
    target.archivedAt = null;

    return this.clientSessionsRepository.save(target);
  }

  private async getOwnedSessionOrThrow(userId: string, sessionId: string): Promise<ClientSession> {
    const session = await this.clientSessionsRepository.findOne({
      where: {
        id: sessionId,
        userId
      }
    });

    if (!session) {
      throw new NotFoundException(`Session ${sessionId} was not found`);
    }

    return session;
  }

  private needsAttention(phase: string): boolean {
    return ['waitingForApproval', 'interrupted', 'error'].includes(phase);
  }

  toResponseDto(session: ClientSession): ClientSessionResponseDto {
    return {
      id: session.id,
      deviceId: session.deviceId,
      externalSessionId: session.externalSessionId,
      provider: session.provider,
      title: session.title ?? null,
      cwd: session.cwd ?? null,
      phase: session.phase,
      isFocused: session.isFocused,
      metadata: session.metadata ?? null,
      startedAt: session.startedAt ?? null,
      lastActivityAt: session.lastActivityAt ?? null,
      endedAt: session.endedAt ?? null,
      archivedAt: session.archivedAt ?? null,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt
    };
  }
}
