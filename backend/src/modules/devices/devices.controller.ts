import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AuthenticatedRequestUser } from '../auth/interfaces/authenticated-request-user.interface';
import { DeviceHeartbeatDto } from './dto/device-heartbeat.dto';
import { ListDevicesQueryDto } from './dto/list-devices-query.dto';
import { DeviceResponseDto } from './dto/device-response.dto';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { DevicesService } from './devices.service';

@ApiTags('devices')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('devices')
export class DevicesController {
  constructor(private readonly devicesService: DevicesService) {}

  @Post('register')
  @ApiOperation({ summary: 'Register or update a client device for the current user' })
  @ApiOkResponse({ type: DeviceResponseDto })
  async register(
    @CurrentUser() user: AuthenticatedRequestUser,
    @Body() dto: RegisterDeviceDto
  ): Promise<DeviceResponseDto> {
    const device = await this.devicesService.registerOrUpdate(user.userId, dto);
    return this.devicesService.toResponseDto(device);
  }

  @Post(':deviceId/heartbeat')
  @ApiOperation({ summary: 'Update device heartbeat and app metadata' })
  @ApiOkResponse({ type: DeviceResponseDto })
  async heartbeat(
    @CurrentUser() user: AuthenticatedRequestUser,
    @Param('deviceId') deviceId: string,
    @Body() dto: DeviceHeartbeatDto
  ): Promise<DeviceResponseDto> {
    const device = await this.devicesService.heartbeat(user.userId, deviceId, dto);
    return this.devicesService.toResponseDto(device);
  }

  @Get('me')
  @ApiOperation({ summary: 'List devices owned by the current user' })
  @ApiOkResponse({ type: DeviceResponseDto, isArray: true })
  async list(
    @CurrentUser() user: AuthenticatedRequestUser,
    @Query() query: ListDevicesQueryDto
  ): Promise<DeviceResponseDto[]> {
    const devices = await this.devicesService.listForUser(user.userId, query);
    return devices.map((device) => this.devicesService.toResponseDto(device));
  }
}
