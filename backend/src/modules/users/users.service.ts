import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UpdateMeDto } from './dto/update-me.dto';
import { UserResponseDto } from './dto/user-response.dto';
import { User } from './entities/user.entity';

type AnonymousUserInput = {
  displayName?: string;
  source?: string;
  platform?: string;
  deviceId?: string;
  metadata?: Record<string, unknown>;
};

type EmailUserInput = {
  email: string;
  passwordHash: string;
  displayName?: string;
};

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly usersRepository: Repository<User>
  ) {}

  async createAnonymousUser(input: AnonymousUserInput): Promise<User> {
    const displayName = input.displayName?.trim() || `Guest-${Date.now().toString(36)}`;
    const metadata = {
      source: input.source ?? 'unknown',
      platform: input.platform ?? 'unknown',
      deviceId: input.deviceId ?? null,
      ...input.metadata
    };

    const user = this.usersRepository.create({
      displayName,
      authProvider: 'anonymous',
      metadata,
      lastSeenAt: new Date()
    });

    return this.usersRepository.save(user);
  }

  async createEmailUser(input: EmailUserInput): Promise<User> {
    const normalizedEmail = this.normalizeEmail(input.email);
    const existing = await this.findByEmail(normalizedEmail);
    if (existing) {
      throw new ConflictException(`Email ${normalizedEmail} is already registered`);
    }

    const user = this.usersRepository.create({
      displayName: input.displayName?.trim() || normalizedEmail.split('@')[0],
      email: normalizedEmail,
      passwordHash: input.passwordHash,
      authProvider: 'email',
      metadata: {
        signupMethod: 'email-password'
      },
      lastSeenAt: new Date()
    });

    return this.usersRepository.save(user);
  }

  async findById(id: string): Promise<User | null> {
    return this.usersRepository.findOne({ where: { id } });
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.usersRepository.findOne({
      where: {
        email: this.normalizeEmail(email)
      }
    });
  }

  async getByIdOrThrow(id: string): Promise<User> {
    const user = await this.findById(id);
    if (!user) {
      throw new NotFoundException(`User ${id} was not found`);
    }

    return user;
  }

  async updateMe(userId: string, dto: UpdateMeDto): Promise<User> {
    const user = await this.getByIdOrThrow(userId);

    if (dto.displayName !== undefined) {
      user.displayName = dto.displayName.trim();
    }

    if (dto.avatarUrl !== undefined) {
      user.avatarUrl = dto.avatarUrl;
    }

    user.lastSeenAt = new Date();
    return this.usersRepository.save(user);
  }

  async upgradeAnonymousUserToEmail(userId: string, input: EmailUserInput): Promise<User> {
    const user = await this.getByIdOrThrow(userId);
    const normalizedEmail = this.normalizeEmail(input.email);

    if (user.authProvider !== 'anonymous') {
      throw new BadRequestException('Only anonymous users can be upgraded with this endpoint');
    }

    const existing = await this.findByEmail(normalizedEmail);
    if (existing && existing.id !== userId) {
      throw new ConflictException(`Email ${normalizedEmail} is already registered`);
    }

    user.email = normalizedEmail;
    user.passwordHash = input.passwordHash;
    user.authProvider = 'email';
    user.displayName = input.displayName?.trim() || user.displayName;
    user.lastSeenAt = new Date();
    user.metadata = {
      ...(user.metadata ?? {}),
      upgradedFromAnonymousAt: new Date().toISOString()
    };

    return this.usersRepository.save(user);
  }

  async touchLastSeen(userId: string): Promise<void> {
    await this.usersRepository.update(userId, {
      lastSeenAt: new Date()
    });
  }

  toResponseDto(user: User): UserResponseDto {
    return {
      id: user.id,
      displayName: user.displayName,
      email: user.email ?? null,
      avatarUrl: user.avatarUrl ?? null,
      role: user.role,
      authProvider: user.authProvider,
      hasPassword: Boolean(user.passwordHash),
      metadata: user.metadata ?? null,
      lastSeenAt: user.lastSeenAt ?? null,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt
    };
  }

  private normalizeEmail(email: string): string {
    return email.trim().toLowerCase();
  }
}
