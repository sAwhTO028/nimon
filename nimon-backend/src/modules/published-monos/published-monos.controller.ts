import { Controller, Get, Header, Param, Query } from '@nestjs/common';
import { PublishedMonosService } from './published-monos.service';

@Controller('v1/published-monos')
export class PublishedMonosController {
  constructor(private readonly published: PublishedMonosService) {}

  @Get()
  @Header('Content-Type', 'application/json')
  async list(@Query('limit') limit?: string) {
    return await this.published.listPublishedMonos(limit);
  }

  @Get(':id')
  @Header('Content-Type', 'application/json')
  async getOne(@Param('id') id: string) {
    return await this.published.getPublishedMonoById(id);
  }
}

