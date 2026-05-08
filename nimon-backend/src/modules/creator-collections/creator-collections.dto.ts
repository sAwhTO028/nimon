import { Transform } from 'class-transformer';
import {
  IsArray,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MinLength,
} from 'class-validator';

import type { PublishedMonoListItemDto } from '../published-monos/published-monos.dto';

/** Single collection row returned by owner + public list APIs. */
export type CreatorMonoCollectionDto = {
  id: string;
  ownerId: string;
  title: string;
  description: string | null;
  coverImageUrl: string | null;
  visibility: string;
  /** Published monos that pass catalog visibility (not trashed, not dirty-hidden). */
  itemCount: number;
  createdAt: string;
  updatedAt: string;
};

export type CreatorMonoCollectionMonosResponseDto = {
  items: PublishedMonoListItemDto[];
  nextCursor: string | null;
};

export class CreateCreatorMonoCollectionDto {
  @IsString()
  @MinLength(1)
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim() : String(value ?? '').trim(),
  )
  title!: string;

  @IsOptional()
  @IsString()
  description?: string | null;

  @IsOptional()
  @IsString()
  coverImageUrl?: string | null;

  @IsOptional()
  @IsIn(['public', 'private'])
  visibility?: string;

  @IsOptional()
  @IsInt()
  sortOrder?: number;
}

export class UpdateCreatorMonoCollectionDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim() : String(value ?? '').trim(),
  )
  title?: string;

  @IsOptional()
  @IsString()
  description?: string | null;

  @IsOptional()
  @IsString()
  coverImageUrl?: string | null;

  @IsOptional()
  @IsIn(['public', 'private'])
  visibility?: string;

  @IsOptional()
  @IsInt()
  sortOrder?: number;
}

export class AddCreatorCollectionItemDto {
  @IsUUID()
  publishedMonoId!: string;
}

export class BulkAddCreatorCollectionItemsDto {
  @IsArray()
  @IsUUID('4', { each: true })
  publishedMonoIds!: string[];
}
