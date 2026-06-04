import { PublishState } from '@prisma/client';

export type ModuleWorkflowStatusesDto = Record<string, string>;

export type StoryDraftBasicsDto = {
  storyId: string;
  ownerId?: string;
  title: string;
  category: string;
  level: string;
  description: string;
  promptSourceNote: string;
  targetDurationBandKey: string | null;
  coverImageUrl: string | null;
  /** Community / audience language (`en` | `my` | `ja`). */
  contentLocale: string | null;
  /** Target language being learned (V1: `ja`). */
  learningLanguage: string | null;
  createdAt: string;
  updatedAt: string;
};

export type StoryDraftResponseDto = {
  draftId: string;
  ownerId: string;
  schemaVersion: number;
  etag: string;
  createdAt: string;
  updatedAt: string;
  basics: StoryDraftBasicsDto;
  sentences: unknown[];
  vocabularyKanji: { entries: unknown[] };
  grammar: { entries: unknown[] };
  quiz: { entries: unknown[] };
  audio: { storyAudio: unknown | null };
  publishState: PublishState;
  moduleWorkflowStatuses: ModuleWorkflowStatusesDto;
  publishedMonoId: string | null;
  readingOnlyPublishedAt: string | null;
  fullLearnPublishedAt: string | null;
};

/** @deprecated Prefer [DraftListSummaryResponseDto] — kept for documentation parity. */
export type ProcessingListItemResponseDto = {
  draftId: string;
  title: string;
  updatedAt: string;
  publishState: PublishState;
  readinessSummary?: string;
  primaryActionHint?: string;
};

export type DraftListWorkspaceState = 'draft' | 'editing' | 'synced';

/** Cursor-paged draft index row — no sentences / learn blobs (see Nimon API contract). */
export type DraftListSummaryResponseDto = {
  draftId: string;
  title: string;
  coverImageUrl: string | null;
  level: string;
  category: string;
  /** Coarse lifecycle label for list UX */
  status: string;
  publishState: PublishState;
  processingStatus: string | null;
  updatedAt: string;
  sentenceCount: number;
  /** Display hint: `draft` | `read_only` | `full_learn` */
  publishType: string;
  previewText: string;

  /** Persisted; list endpoint does not recompute via diff. */
  hasUnpublishedCoreChanges: boolean;
  targetDurationBandKey: string | null;
  moduleWorkflowStatuses: Record<string, string>;
  learnModeEnabled: boolean;
  /** 0–100 derived from basics fill + sentenceCount + module statuses (no sentence-body reads). */
  completionPercent: number | null;
  workspaceState: DraftListWorkspaceState;
  /** Module key from workflow JSON when heuristic finds an active step; otherwise null. */
  lastEditingStep: string | null;
  /** M22F-1: community / audience (`en` | `my` | `ja`); null = legacy. */
  contentLocale: string | null;
  /** M22F-1: target learning language (V1: `ja`); null = legacy. */
  learningLanguage: string | null;
};

export type StoryDraftListEnvelopeDto = {
  items: DraftListSummaryResponseDto[];
  nextCursor: string | null;
  hasMore: boolean;
  totalCount: number | null;
};

/** Query accepted by GET /v1/story-drafts (cursor summary index). */
export type ListStoryDraftsQuery = {
  limit?: string;
  cursor?: string;
  sort?: string;
  status?: string;
  publishState?: string;
  updatedAfter?: string;
};

