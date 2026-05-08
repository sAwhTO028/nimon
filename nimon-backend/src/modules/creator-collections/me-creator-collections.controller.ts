import {
  Body,
  Controller,
  Delete,
  Get,
  Header,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { JwtValidatedUser } from '../auth/jwt.strategy';

import {
  AddCreatorCollectionItemDto,
  BulkAddCreatorCollectionItemsDto,
  CreateCreatorMonoCollectionDto,
  UpdateCreatorMonoCollectionDto,
} from './creator-collections.dto';
import { CreatorCollectionsService } from './creator-collections.service';

@Controller()
export class MeCreatorCollectionsController {
  constructor(private readonly collections: CreatorCollectionsService) {}

  @Get('v1/me/creator-collections')
  @UseGuards(JwtAuthGuard)
  @Header('Content-Type', 'application/json')
  async list(@Req() req: { user: JwtValidatedUser }) {
    return await this.collections.listMine(req.user.userId);
  }

  @Post('v1/me/creator-collections')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.CREATED)
  @Header('Content-Type', 'application/json')
  async create(
    @Req() req: { user: JwtValidatedUser },
    @Body() body: CreateCreatorMonoCollectionDto,
  ) {
    return await this.collections.create(req.user.userId, body);
  }

  @Patch('v1/me/creator-collections/:id')
  @UseGuards(JwtAuthGuard)
  @Header('Content-Type', 'application/json')
  async patch(
    @Req() req: { user: JwtValidatedUser },
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: UpdateCreatorMonoCollectionDto,
  ) {
    return await this.collections.updateMine(req.user.userId, id, body);
  }

  @Delete('v1/me/creator-collections/:id')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  async delete(
    @Req() req: { user: JwtValidatedUser },
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    await this.collections.deleteMine(req.user.userId, id);
  }

  @Post('v1/me/creator-collections/:id/items')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  @Header('Content-Type', 'application/json')
  async addItem(
    @Req() req: { user: JwtValidatedUser },
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: AddCreatorCollectionItemDto,
  ) {
    return await this.collections.addItemMine(
      req.user.userId,
      id,
      body.publishedMonoId,
    );
  }

  @Delete('v1/me/creator-collections/:id/items/:publishedMonoId')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  async removeItem(
    @Req() req: { user: JwtValidatedUser },
    @Param('id', ParseUUIDPipe) id: string,
    @Param('publishedMonoId', ParseUUIDPipe) publishedMonoId: string,
  ) {
    await this.collections.removeItemMine(req.user.userId, id, publishedMonoId);
  }

  @Post('v1/me/creator-collections/:id/items/bulk')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  @Header('Content-Type', 'application/json')
  async bulkAdd(
    @Req() req: { user: JwtValidatedUser },
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: BulkAddCreatorCollectionItemsDto,
  ) {
    return await this.collections.bulkAddItemsMine(req.user.userId, id, body);
  }

  @Get('v1/me/creator-collections/:id/monos')
  @UseGuards(JwtAuthGuard)
  @Header('Content-Type', 'application/json')
  async listMineCollectionMonos(
    @Req() req: { user: JwtValidatedUser },
    @Param('id', ParseUUIDPipe) id: string,
    @Query('limit') limit?: string,
    @Query('cursor') cursor?: string,
  ) {
    return await this.collections.listMineCollectionMonos(
      req.user.userId,
      id,
      limit,
      cursor,
    );
  }
}
