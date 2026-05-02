import {
  Body,
  Controller,
  Delete,
  Get,
  Header,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Put,
  Query,
  Req,
} from '@nestjs/common';
import type { Request } from 'express';
import { StoryDraftsService } from './story-drafts.service';
import {
  CreateStoryDraftRequestDto,
  StoryDraftWriteDto,
} from './dto/story-draft.requests';

@Controller('v1/story-drafts')
export class StoryDraftsController {
  constructor(private readonly storyDrafts: StoryDraftsService) {}

  @Post()
  @Header('Content-Type', 'application/json')
  async createDraft(@Body() body: CreateStoryDraftRequestDto) {
    const created = await this.storyDrafts.createDraft(body);
    return created;
  }

  @Get()
  @Header('Content-Type', 'application/json')
  async listDrafts(
    @Query('limit') limit?: string,
    @Query('cursor') cursor?: string,
    @Query('sort') sort?: string,
    @Query('status') status?: string,
    @Query('publishState') publishState?: string,
    @Query('updatedAfter') updatedAfter?: string,
  ) {
    return await this.storyDrafts.listDrafts({
      limit,
      cursor,
      sort,
      status,
      publishState,
      updatedAfter,
    });
  }

  @Get(':draftId')
  @Header('Content-Type', 'application/json')
  async getDraft(@Param('draftId') draftId: string) {
    return await this.storyDrafts.getDraftById(draftId);
  }

  @Delete(':draftId')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteDraft(@Param('draftId') draftId: string) {
    await this.storyDrafts.deleteDraft(draftId);
  }

  @Put(':draftId')
  @Header('Content-Type', 'application/json')
  async updateDraft(
    @Param('draftId') draftId: string,
    @Body() body: StoryDraftWriteDto,
    @Req() req: Request,
  ) {
    const ifMatch = req.headers['if-match'];
    return await this.storyDrafts.updateDraft(
      draftId,
      body,
      typeof ifMatch === 'string' ? ifMatch : undefined,
    );
  }

  @Post(':draftId/publish/read-only')
  @Header('Content-Type', 'application/json')
  async publishReadOnly(@Param('draftId') draftId: string, @Req() req: Request) {
    const ifMatch = req.headers['if-match'];
    return await this.storyDrafts.publishReadOnly(
      draftId,
      typeof ifMatch === 'string' ? ifMatch : undefined,
    );
  }

  @Post(':draftId/publish/full-learn')
  @Header('Content-Type', 'application/json')
  async publishFullLearn(@Param('draftId') draftId: string, @Req() req: Request) {
    const ifMatch = req.headers['if-match'];
    return await this.storyDrafts.publishFullLearn(
      draftId,
      typeof ifMatch === 'string' ? ifMatch : undefined,
    );
  }
}

