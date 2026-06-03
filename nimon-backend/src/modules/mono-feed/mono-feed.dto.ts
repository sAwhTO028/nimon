/**
 * Public catalog feed (Mono Home) — list rows are summary-only; no full `content` JSON in response.
 * Aligned with docs/NIMON_API_QUERY_CONTRACT.md §4.1 `MonoFeedSummaryDto` + app fields.
 */
export type MonoFeedSummaryItemDto = {
  monoId: string;
  title: string;
  coverUrl: string | null;
  level: string;
  /** Single category from `published_monos.category` (V1). */
  category: string;
  /** Array form for contract consumers. */
  categories: string[];
  /** Short text from `published_monos.description`. */
  description: string;
  writerId: string;
  writerHandle: string | null;
  writerDisplayName: string | null;
  /** Live [UserProfile.avatarUrl] join (never a stale PublishedMono snapshot). */
  writerAvatarUrl: string | null;
  publishedAt: string;
  updatedAt: string;
  likesCount: number;
  hasAudio: boolean;
  isBookmarkedByMe: boolean;
  myReaction: 'heart' | null;
  shareUrl: string;
  /** From denormalized `published_monos.publishKind` (backfilled from `content` on publish). */
  publishKind: string | null;
  /** V1: all rows in `published_monos` treated as public catalog. */
  accessType: 'public';
};

export type MonoFeedListResponseDto = {
  items: MonoFeedSummaryItemDto[];
  nextCursor: string | null;
  hasMore: boolean;
};
