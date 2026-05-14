/**
 * V1 free-tier ownership quotas (M17D / M17E).
 * Server-enforced; Flutter mirrors for UX only in M17F.
 */
export const FREE_TIER_QUOTAS = {
  publishedMonos: 30,
  savedMonos: 50,
  collections: 10,
  collectionItems: 30,
  draftStories: 50,
} as const;

/** Values match API `key` in `quota_exceeded` responses. */
export const FREE_TIER_QUOTA_KEYS = {
  publishedMonos: 'published_mono_limit_reached',
  savedMonos: 'saved_mono_limit_reached',
  collections: 'collection_limit_reached',
  collectionItems: 'collection_item_limit_reached',
  draftStories: 'draft_story_limit_reached',
} as const;
