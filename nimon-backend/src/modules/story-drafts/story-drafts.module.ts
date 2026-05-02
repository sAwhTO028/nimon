import { Module } from '@nestjs/common';
import { StoryDraftsController } from './story-drafts.controller';
import { StoryDraftsService } from './story-drafts.service';

@Module({
  controllers: [StoryDraftsController],
  providers: [StoryDraftsService],
})
export class StoryDraftsModule {}

