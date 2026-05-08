import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { StoryDraftsController } from './story-drafts.controller';
import { StoryDraftsService } from './story-drafts.service';

@Module({
  imports: [AuthModule],
  controllers: [StoryDraftsController],
  providers: [StoryDraftsService],
})
export class StoryDraftsModule {}

