import type { PublishedMonoListItemDto } from '../published-monos/published-monos.dto';

/**
 * One published mono row for search results — list card DTO plus engagement fields
 * (same enrichment pattern as public mono feed / reader detail).
 */
export type PublishedMonoSearchListItemDto = PublishedMonoListItemDto & {
  likesCount: number;
  isBookmarkedByMe: boolean;
  myReaction: 'heart' | null;
  shareUrl: string;
};

export type SearchPublishedMonosResponseDto = {
  items: PublishedMonoSearchListItemDto[];
  nextCursor: string | null;
  hasMore: boolean;
  /** Total rows matching filters + keyword on the first page only (`cursor` absent). */
  totalCount: number | null;
};
