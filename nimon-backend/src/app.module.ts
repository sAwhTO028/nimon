import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './modules/auth/auth.module';
import { HealthModule } from './modules/health/health.module';
import { PrismaModule } from './modules/prisma/prisma.module';
import { ProcessingModule } from './modules/processing/processing.module';
import { MonoFeedModule } from './modules/mono-feed/mono-feed.module';
import { MonoSocialModule } from './modules/mono-social/mono-social.module';
import { UserFollowModule } from './modules/user-follow/user-follow.module';
import { PublishedMonosModule } from './modules/published-monos/published-monos.module';
import { PublishingModule } from './modules/publishing/publishing.module';
import { StoryDraftsModule } from './modules/story-drafts/story-drafts.module';
import { UsersModule } from './modules/users/users.module';
import { MediaModule } from './modules/media/media.module';
import { CreatorCollectionsModule } from './modules/creator-collections/creator-collections.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env'],
    }),
    PrismaModule,
    HealthModule,
    AuthModule,
    UsersModule,
    StoryDraftsModule,
    PublishedMonosModule,
    MonoFeedModule,
    MonoSocialModule,
    UserFollowModule,
    ProcessingModule,
    PublishingModule,
    MediaModule,
    CreatorCollectionsModule,
  ],
})
export class AppModule {}
