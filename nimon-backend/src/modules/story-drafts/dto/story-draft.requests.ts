import { PublishState } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  Equals,
  IsArray,
  IsIn,
  IsNotEmpty,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  ValidateNested,
} from 'class-validator';

import { V1_LEARNING_LANGUAGES } from '../../../common/validation/language-pair-validation';

class CreateDraftBasicsDto {
  @IsOptional()
  storyId?: string;

  @IsOptional()
  @IsString()
  title?: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsString()
  level?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  promptSourceNote?: string;

  @IsOptional()
  @IsString()
  targetDurationBandKey?: string | null;

  @IsOptional()
  @IsString()
  coverImageUrl?: string | null;

  @IsOptional()
  @IsIn(['en', 'my', 'ja'])
  contentLocale?: string | null;

  @IsOptional()
  @IsIn([...V1_LEARNING_LANGUAGES])
  learningLanguage?: string | null;
}

export class CreateStoryDraftRequestDto {
  @Equals(1)
  schemaVersion!: 1;

  @IsOptional()
  draftId?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => CreateDraftBasicsDto)
  basics?: CreateDraftBasicsDto;
}

class StoryDraftBasicsWriteDto {
  @IsString()
  @IsNotEmpty()
  storyId!: string;

  @IsOptional()
  @IsString()
  ownerId?: string;

  @IsString()
  title!: string;

  @IsString()
  category!: string;

  @IsString()
  level!: string;

  @IsString()
  description!: string;

  @IsString()
  promptSourceNote!: string;

  @IsOptional()
  @IsString()
  targetDurationBandKey!: string | null;

  @IsOptional()
  @IsString()
  coverImageUrl!: string | null;

  @IsOptional()
  @IsString()
  createdAt?: string;

  @IsOptional()
  @IsString()
  updatedAt?: string;

  @IsOptional()
  @IsIn(['en', 'my', 'ja'])
  contentLocale?: string | null;

  @IsOptional()
  @IsIn([...V1_LEARNING_LANGUAGES])
  learningLanguage?: string | null;
}

class EntriesWrapperDto {
  @IsArray()
  entries!: Array<Record<string, unknown>>;
}

class AudioWrapperDto {
  @IsOptional()
  @IsObject()
  storyAudio!: Record<string, unknown> | null;
}

export class StoryDraftWriteDto {
  @Equals(1)
  schemaVersion!: 1;

  @ValidateNested()
  @Type(() => StoryDraftBasicsWriteDto)
  basics!: StoryDraftBasicsWriteDto;

  @IsArray()
  sentences!: Array<Record<string, unknown>>;

  @ValidateNested()
  @Type(() => EntriesWrapperDto)
  vocabularyKanji!: EntriesWrapperDto;

  @ValidateNested()
  @Type(() => EntriesWrapperDto)
  grammar!: EntriesWrapperDto;

  @ValidateNested()
  @Type(() => EntriesWrapperDto)
  quiz!: EntriesWrapperDto;

  @ValidateNested()
  @Type(() => AudioWrapperDto)
  audio!: AudioWrapperDto;

  @IsIn(['draft', 'reading_only_published', 'full_learn_published'])
  publishState!: PublishState;

  @IsObject()
  moduleWorkflowStatuses!: Record<string, string>;
}

