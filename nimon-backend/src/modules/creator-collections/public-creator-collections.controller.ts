import {
  Controller,
  Get,
  Header,
  Param,
  Query,
  ParseUUIDPipe,
} from '@nestjs/common';

import { CreatorCollectionsService } from './creator-collections.service';

@Controller()
export class PublicCreatorCollectionsController {
  constructor(private readonly collections: CreatorCollectionsService) {}

  @Get('v1/users/:userId/creator-collections')
  @Header('Content-Type', 'application/json')
  async listPublic(@Param('userId', ParseUUIDPipe) userId: string) {
    return await this.collections.listPublicForUser(userId);
  }

  @Get('v1/users/:userId/creator-collections/:collectionId/monos')
  @Header('Content-Type', 'application/json')
  async listCollectionMonos(
    @Param('userId', ParseUUIDPipe) userId: string,
    @Param('collectionId', ParseUUIDPipe) collectionId: string,
    @Query('limit') limit?: string,
    @Query('cursor') cursor?: string,
  ) {
    return await this.collections.listPublicCollectionMonos(
      userId,
      collectionId,
      limit,
      cursor,
    );
  }
}
