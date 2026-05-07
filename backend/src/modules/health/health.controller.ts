import { Controller, Get } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { HealthService } from './health.service';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Get()
  @ApiOperation({ summary: 'Check backend health' })
  @ApiOkResponse({
    description: 'Returns the current backend health payload'
  })
  getHealth() {
    return this.healthService.getStatus();
  }
}
