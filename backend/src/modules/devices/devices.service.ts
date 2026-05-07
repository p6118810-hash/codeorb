import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DeviceHeartbeatDto } from './dto/device-heartbeat.dto';
import { DeviceResponseDto } from './dto/device-response.dto';
import { ListDevicesQueryDto } from './dto/list-devices-query.dto';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { Device } from './entities/device.entity';

@Injectable()
export class DevicesService {
  constructor(
    @InjectRepository(Device)
    private readonly devicesRepository: Repository<Device>
  ) {}

  async registerOrUpdate(userId: string, dto: RegisterDeviceDto): Promise<Device> {
    const existing = await this.devicesRepository.findOne({
      where: {
        userId,
        deviceIdentifier: dto.deviceIdentifier
      }
    });

    if (existing) {
      existing.name = dto.name;
      existing.kind = dto.kind;
      existing.platform = dto.platform;
      existing.appVersion = dto.appVersion ?? null;
      existing.buildNumber = dto.buildNumber ?? null;
      existing.metadata = dto.metadata ?? existing.metadata ?? null;
      existing.lastSeenAt = new Date();
      return this.devicesRepository.save(existing);
    }

    const device = this.devicesRepository.create({
      userId,
      deviceIdentifier: dto.deviceIdentifier,
      name: dto.name,
      kind: dto.kind,
      platform: dto.platform,
      appVersion: dto.appVersion ?? null,
      buildNumber: dto.buildNumber ?? null,
      metadata: dto.metadata ?? null,
      lastSeenAt: new Date()
    });

    return this.devicesRepository.save(device);
  }

  async heartbeat(userId: string, deviceId: string, dto: DeviceHeartbeatDto): Promise<Device> {
    const device = await this.getOwnedDeviceOrThrow(userId, deviceId);

    if (dto.name !== undefined) {
      device.name = dto.name;
    }

    if (dto.appVersion !== undefined) {
      device.appVersion = dto.appVersion;
    }

    if (dto.buildNumber !== undefined) {
      device.buildNumber = dto.buildNumber;
    }

    if (dto.metadata !== undefined) {
      device.metadata = {
        ...(device.metadata ?? {}),
        ...dto.metadata
      };
    }

    device.lastSeenAt = new Date();
    return this.devicesRepository.save(device);
  }

  async listForUser(userId: string, query: ListDevicesQueryDto = {}): Promise<Device[]> {
    const qb = this.devicesRepository.createQueryBuilder('device').where('device.user_id = :userId', { userId });

    if (query.kind) {
      qb.andWhere('device.kind = :kind', { kind: query.kind });
    }

    if (query.platform) {
      qb.andWhere('device.platform = :platform', { platform: query.platform });
    }

    qb.orderBy('device.last_seen_at', 'DESC')
      .addOrderBy('device.created_at', 'DESC')
      .take(query.limit ?? 50)
      .skip(query.offset ?? 0);

    return qb.getMany();
  }

  async getOwnedDeviceOrThrow(userId: string, deviceId: string): Promise<Device> {
    const device = await this.devicesRepository.findOne({
      where: {
        id: deviceId,
        userId
      }
    });

    if (!device) {
      throw new NotFoundException(`Device ${deviceId} was not found`);
    }

    return device;
  }

  toResponseDto(device: Device): DeviceResponseDto {
    return {
      id: device.id,
      deviceIdentifier: device.deviceIdentifier,
      name: device.name,
      kind: device.kind,
      platform: device.platform,
      appVersion: device.appVersion ?? null,
      buildNumber: device.buildNumber ?? null,
      metadata: device.metadata ?? null,
      lastSeenAt: device.lastSeenAt ?? null,
      createdAt: device.createdAt,
      updatedAt: device.updatedAt
    };
  }
}
