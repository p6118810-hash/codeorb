import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { compare, hash } from 'bcryptjs';
import { randomUUID } from 'crypto';
import { IsNull, Repository } from 'typeorm';
import { UsersService } from '../users/users.service';
import { AnonymousAuthDto } from './dto/anonymous-auth.dto';
import { LoginEmailDto } from './dto/login-email.dto';
import { RegisterEmailDto } from './dto/register-email.dto';
import { UpgradeAccountDto } from './dto/upgrade-account.dto';
import { AuthSession } from './entities/auth-session.entity';
import { JwtPayload } from './interfaces/jwt-payload.interface';

@Injectable()
export class AuthService {
  constructor(
    private readonly configService: ConfigService,
    private readonly jwtService: JwtService,
    private readonly usersService: UsersService,
    @InjectRepository(AuthSession)
    private readonly authSessionsRepository: Repository<AuthSession>
  ) {}

  async createAnonymousSession(dto: AnonymousAuthDto) {
    const user = await this.usersService.createAnonymousUser(dto);
    return this.issueSession(user.id, user.role, {
      source: dto.source ?? 'unknown',
      deviceId: dto.deviceId ?? null,
      metadata: {
        platform: dto.platform ?? null,
        ...dto.metadata
      }
    });
  }

  async registerWithEmail(dto: RegisterEmailDto) {
    const passwordHash = await hash(dto.password, 10);
    const user = await this.usersService.createEmailUser({
      email: dto.email,
      passwordHash,
      displayName: dto.displayName
    });

    return this.issueSession(user.id, user.role, {
      source: 'email-register',
      metadata: {
        authMethod: 'email-password'
      }
    });
  }

  async loginWithEmail(dto: LoginEmailDto) {
    const user = await this.usersService.findByEmail(dto.email);
    if (!user?.passwordHash) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const passwordMatches = await compare(dto.password, user.passwordHash);
    if (!passwordMatches) {
      throw new UnauthorizedException('Invalid email or password');
    }

    return this.issueSession(user.id, user.role, {
      source: 'email-login',
      metadata: {
        authMethod: 'email-password'
      }
    });
  }

  async upgradeAnonymousAccount(userId: string, currentSessionId: string, dto: UpgradeAccountDto) {
    const passwordHash = await hash(dto.password, 10);
    const user = await this.usersService.upgradeAnonymousUserToEmail(userId, {
      email: dto.email,
      passwordHash,
      displayName: dto.displayName
    });

    await this.revokeBySessionId(currentSessionId);

    return this.issueSession(user.id, user.role, {
      source: 'email-upgrade',
      metadata: {
        previousSessionId: currentSessionId,
        authMethod: 'email-password'
      }
    });
  }

  async validateAccessToken(accessToken: string) {
    try {
      const payload = await this.jwtService.verifyAsync<JwtPayload>(accessToken, {
        secret: this.configService.get<string>('JWT_SECRET')
      });

      const session = await this.getActiveSession(payload.sid);
      if (!session || session.userId !== payload.sub) {
        return { valid: false as const };
      }

      const user = await this.usersService.findById(payload.sub);
      if (!user) {
        return { valid: false as const };
      }

      await this.touchSession(payload.sid);

      return {
        valid: true as const,
        sessionId: payload.sid,
        user: this.usersService.toResponseDto(user)
      };
    } catch {
      return { valid: false as const };
    }
  }

  async revokeBySessionId(sessionId: string): Promise<void> {
    const session = await this.getActiveSession(sessionId);
    if (!session) {
      return;
    }

    session.revokedAt = new Date();
    await this.authSessionsRepository.save(session);
  }

  async getActiveSession(sessionId: string): Promise<AuthSession | null> {
    return this.authSessionsRepository.findOne({
      where: {
        tokenId: sessionId,
        revokedAt: IsNull()
      }
    });
  }

  async touchSession(sessionId: string): Promise<void> {
    const session = await this.getActiveSession(sessionId);
    if (!session) {
      return;
    }

    session.lastUsedAt = new Date();
    await this.authSessionsRepository.save(session);
    await this.usersService.touchLastSeen(session.userId);
  }

  private async issueSession(
    userId: string,
    role: string,
    options: {
      source: string;
      deviceId?: string | null;
      metadata?: Record<string, unknown> | null;
    }
  ) {
    const tokenId = randomUUID();
    const session = this.authSessionsRepository.create({
      tokenId,
      userId,
      source: options.source,
      deviceId: options.deviceId ?? null,
      metadata: options.metadata ?? null,
      lastUsedAt: new Date()
    });

    await this.authSessionsRepository.save(session);

    const payload: JwtPayload = {
      sub: userId,
      sid: tokenId,
      role
    };

    const accessToken = await this.jwtService.signAsync(payload, {
      secret: this.configService.get<string>('JWT_SECRET'),
      expiresIn: this.configService.get<string>('JWT_EXPIRES_IN') ?? '30d'
    });

    const user = await this.usersService.getByIdOrThrow(userId);

    return {
      accessToken,
      sessionId: tokenId,
      user: this.usersService.toResponseDto(user)
    };
  }
}
