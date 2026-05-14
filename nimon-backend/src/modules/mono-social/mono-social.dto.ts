export type MonoBookmarkStateDto = {
  publishedMonoId: string;
  isBookmarkedByMe: boolean;
};

export type MonoReactionStateDto = {
  publishedMonoId: string;
  likesCount: number;
  myReaction: 'heart' | null;
};

export type MonoBookmarksListItemDto = {
  /** Same as feed `monoId`. */
  monoId: string;
  title: string;
  coverUrl: string | null;
  level: string;
  category: string;
  categories: string[];
  description: string;
  writerId: string;
  writerHandle: string | null;
  writerDisplayName: string | null;
  publishedAt: string;
  updatedAt: string;
  likesCount: number;
  hasAudio: boolean;
  isBookmarkedByMe: true;
  myReaction: 'heart' | null;
  shareUrl: string;
  publishKind: string | null;
  accessType: 'public';
  bookmarkedAt: string;
  /** Same derivation as published list (`content.core.targetDurationBandKey`). */
  targetDurationLabel: string | null;
};

export type MonoBookmarksListResponseDto = {
  items: MonoBookmarksListItemDto[];
  nextCursor: string | null;
  hasMore: boolean;
  /** Catalog-visible saved rows for this viewer (same filter as [items]). */
  totalCount: number;
};

