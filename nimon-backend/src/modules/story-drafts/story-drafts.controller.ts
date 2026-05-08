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
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtOrDevOwnerFallbackGuard } from '../auth/jwt-or-dev-owner-fallback.guard';
import type { JwtValidatedUser } from '../auth/jwt.strategy';
import { StoryDraftsService } from './story-drafts.service';
import {
  CreateStoryDraftRequestDto,
  StoryDraftWriteDto,
} from './dto/story-draft.requests';

@UseGuards(JwtOrDevOwnerFallbackGuard)
@Controller('v1/story-drafts')
export class StoryDraftsController {
  constructor(private readonly storyDrafts: StoryDraftsService) {}

  @Post()
  @Header('Content-Type', 'application/json')
  async createDraft(
    @Body() body: CreateStoryDraftRequestDto,
    @CurrentUser() user: JwtValidatedUser,
  ) {
    const created = await this.storyDrafts.createDraft(user.userId, body);
    return created;
  }

  @Get()
  @Header('Content-Type', 'application/json')
  async listDrafts(
    @CurrentUser() user: JwtValidatedUser,
    @Query('limit') limit?: string,
    @Query('cursor') cursor?: string,
    @Query('sort') sort?: string,
    @Query('status') status?: string,
    @Query('publishState') publishState?: string,
    @Query('updatedAfter') updatedAfter?: string,
  ) {
    return await this.storyDrafts.listDrafts(user.userId, {
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
  async getDraft(
    @Param('draftId') draftId: string,
    @CurrentUser() user: JwtValidatedUser,
  ) {
    return await this.storyDrafts.getDraftById(user.userId, draftId);
  }

  @Delete(':draftId')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteDraft(
    @Param('draftId') draftId: string,
    @CurrentUser() user: JwtValidatedUser,
  ) {
    await this.storyDrafts.deleteDraft(user.userId, draftId);
  }

  @Put(':draftId')
  @Header('Content-Type', 'application/json')
  async updateDraft(
    @Param('draftId') draftId: string,
    @Body() body: StoryDraftWriteDto,
    @Req() req: Request,
    @CurrentUser() user: JwtValidatedUser,
  ) {
    const ifMatch = req.headers['if-match'];
    return await this.storyDrafts.updateDraft(
      user.userId,
      draftId,
      body,
      typeof ifMatch === 'string' ? ifMatch : undefined,
    );
  }

  @Post(':draftId/publish/read-only')
  @Header('Content-Type', 'application/json')
  async publishReadOnly(
    @Param('draftId') draftId: string,
    @Req() req: Request,
    @CurrentUser() user: JwtValidatedUser,
  ) {
    const ifMatch = req.headers['if-match'];
    return await this.storyDrafts.publishReadOnly(
      user.userId,
      draftId,
      typeof ifMatch === 'string' ? ifMatch : undefined,
    );
  }

  @Post(':draftId/publish/full-learn')
  @Header('Content-Type', 'application/json')
  async publishFullLearn(
    @Param('draftId') draftId: string,
    @Req() req: Request,
    @CurrentUser() user: JwtValidatedUser,
  ) {
    const ifMatch = req.headers['if-match'];
    return await this.storyDrafts.publishFullLearn(
      user.userId,
      draftId,
      typeof ifMatch === 'string' ? ifMatch : undefined,
    );
  }
}
