import {
  canonicalizeMediaUrl,
  clonePublishedContentWithCanonicalMedia,
} from '../media/media-url-canonicalizer';
import type { PublishedMonoListItemDto, PublishedMonoDetailDto } from './published-monos.dto';

/** Subset of UserProfile used to stamp writer identity onto mono DTOs (M9f). */
export type WriterProfileSlice = {
  displayName: string | null;
  handle: string | null;
  avatarUrl: string | null;
};

export function attachWriterProfileToListItem(
  item: PublishedMonoListItemDto,
  writer: WriterProfileSlice | null,
  mediaPublicBaseUrl: string,
): PublishedMonoListItemDto {
  return {
    ...item,
    writerDisplayName: writer?.displayName ?? null,
    writerHandle: writer?.handle ?? null,
    writerAvatarUrl: canonicalizeMediaUrl(writer?.avatarUrl ?? null, mediaPublicBaseUrl),
  };
}

export function attachWriterProfileToDetail(
  detail: PublishedMonoDetailDto,
  writer: WriterProfileSlice | null,
  mediaPublicBaseUrl: string,
): PublishedMonoDetailDto {
  const stamped = attachWriterProfileToListItem(detail, writer, mediaPublicBaseUrl);
  const withAltCounts = detail as PublishedMonoDetailDto & {
    likeCount?: number;
    reactionsCount?: number;
  };
  return {
    ...stamped,
    content: detail.content,
    likesCount:
      detail.likesCount ??
      withAltCounts.likeCount ??
      withAltCounts.reactionsCount ??
      0,
    isBookmarkedByMe: detail.isBookmarkedByMe ?? false,
    myReaction: detail.myReaction ?? null,
  };
}

export const DURATION_BY_BAND: Record<string, string> = {
  '3_5': '3–5 min',
  '5_7': '5–7 min',
  '7_9': '7–9 min',
};

export function durationLabelFromKey(key: string | null | undefined): string | null {
  if (key == null) return null;
  const t = String(key).trim();
  if (!t) return null;
  return DURATION_BY_BAND[t] ?? null;
}

/**
 * `read_only_v1` / `full_learn_v1` in JSON, or other future versions.
 */
export function displayKindFrom(publishKind: string | null | undefined): 'read_only' | 'full_learn' | 'unknown' {
  const k = (publishKind ?? '').trim();
  if (k === 'read_only_v1' || k === 'read_only') return 'read_only';
  if (k === 'full_learn_v1' || k === 'full_learn') return 'full_learn';
  return 'unknown';
}

/**
 * Shallow merge for Prisma Json content.
 */
/** M22B / M22E: list rows from denormalized columns (no `content` JSONB select). */
export function publishedMonoListItemFromCatalogSummaryRow(
  m: {
    id: string;
    ownerId: string;
    title: string;
    category: string;
    level: string;
    description: string;
    createdAt: Date;
    updatedAt: Date;
    coverImageUrl?: string | null;
    publishKind?: string | null;
  },
  mediaPublicBaseUrl: string,
): PublishedMonoListItemDto {
  const publishKind =
    typeof m.publishKind === 'string' && m.publishKind.trim() !== ''
      ? m.publishKind.trim()
      : null;
  const contentSummary = publishKind
    ? { publishKind, updatedAt: null as string | null }
    : null;
  const coverImageUrl = canonicalizeMediaUrl(m.coverImageUrl ?? null, mediaPublicBaseUrl);

  return {
    id: m.id,
    ownerId: m.ownerId,
    sourceDraftId: null,
    title: m.title ?? '',
    category: m.category ?? '',
    level: m.level ?? '',
    description: m.description ?? '',
    publishKind,
    displayPublishKind: displayKindFrom(publishKind),
    coverImageUrl,
    targetDurationLabel: null,
    createdAt: m.createdAt.toISOString(),
    updatedAt: m.updatedAt.toISOString(),
    contentSummary,
    writerDisplayName: null,
    writerHandle: null,
    writerAvatarUrl: null,
  };
}

export function publishedMonoListItemFromRow(m: {
  id: string;
  ownerId: string;
  title: string;
  category: string;
  level: string;
  description: string;
  createdAt: Date;
  updatedAt: Date;
  content: unknown;
}, mediaPublicBaseUrl: string): PublishedMonoListItemDto {
  const content = (m.content ?? {}) as any;
  const sourceDraftId =
    typeof content?.sourceDraftId === 'string' ? content.sourceDraftId : null;
  const publishKind =
    typeof content?.publishKind === 'string' ? content.publishKind : null;
  const contentSummary =
    content && typeof content === 'object'
      ? {
          publishKind,
          updatedAt: typeof content.updatedAt === 'string' ? content.updatedAt : null,
        }
      : null;
  const core = content?.core && typeof content.core === 'object' ? content.core : {};
  const rawCover =
    typeof core?.coverImageUrl === 'string' && core.coverImageUrl.trim() !== ''
      ? core.coverImageUrl.trim()
      : null;
  const coverImageUrl = canonicalizeMediaUrl(rawCover, mediaPublicBaseUrl);
  const durationKey = typeof core?.targetDurationBandKey === 'string' ? core.targetDurationBandKey : null;
  const targetDurationLabel = durationLabelFromKey(durationKey);

  return {
    id: m.id,
    ownerId: m.ownerId,
    sourceDraftId,
    title: m.title ?? '',
    category: m.category ?? '',
    level: m.level ?? '',
    description: m.description ?? '',
    publishKind,
    displayPublishKind: displayKindFrom(publishKind),
    coverImageUrl,
    targetDurationLabel,
    createdAt: m.createdAt.toISOString(),
    updatedAt: m.updatedAt.toISOString(),
    contentSummary,
    writerDisplayName: null,
    writerHandle: null,
    writerAvatarUrl: null,
  };
}

export function publishedMonoDetailFromRow(
  m: {
    id: string;
    ownerId: string;
    title: string;
    category: string;
    level: string;
    description: string;
    createdAt: Date;
    updatedAt: Date;
    content: unknown;
  },
  mediaPublicBaseUrl: string,
): PublishedMonoDetailDto {
  return {
    ...publishedMonoListItemFromRow(m, mediaPublicBaseUrl),
    content: clonePublishedContentWithCanonicalMedia(m.content, mediaPublicBaseUrl),
    likesCount: 0,
    isBookmarkedByMe: false,
    myReaction: null,
  };
}
