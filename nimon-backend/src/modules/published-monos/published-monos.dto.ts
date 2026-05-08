export type PublishedMonoDisplayKind = 'read_only' | 'full_learn' | 'unknown';

export type PublishedMonoListItemDto = {
  id: string;
  ownerId: string;
  sourceDraftId: string | null;
  title: string;
  category: string;
  level: string;
  description: string;
  /** Raw content.publishKind, e.g. `read_only_v1` / `full_learn_v1`. */
  publishKind: string | null;
  /** UI-safe bucket for badges. */
  displayPublishKind: PublishedMonoDisplayKind;
  /** From content.core.coverImageUrl when present. */
  coverImageUrl: string | null;
  /** e.g. `3–5 min` from `content.core.targetDurationBandKey`. */
  targetDurationLabel: string | null;
  createdAt: string;
  updatedAt: string;
  contentSummary: unknown | null;
  /** Live UserProfile for [ownerId]; null when profile row missing. */
  writerDisplayName: string | null;
  writerHandle: string | null;
  writerAvatarUrl: string | null;
};

export type PublishedMonoListResponseDto = {
  items: PublishedMonoListItemDto[];
  nextCursor: null;
};

export type PublishedMonoDetailDto = PublishedMonoListItemDto & {
  /** Full JSON blob: core, learn, publishKind, sourceDraftId, etc. */
  content: unknown;
};

/** Response for `POST .../trash` — `trashedAt` is ISO-8601 when in Trash. */
export type PublishedMonoTrashResponseDto = {
  id: string;
  trashedAt: string;
};

/** Response for `POST .../restore` — `trashedAt` is always JSON `null`. */
export type PublishedMonoRestoreResponseDto = {
  id: string;
  trashedAt: null;
};

/** Request body for `DELETE .../permanent` — requires explicit confirmation phrase. */
export type PublishedMonoPermanentDeleteRequestDto = {
  confirm: string;
};

