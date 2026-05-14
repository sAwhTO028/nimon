import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { PublicWebBaseUrlService } from '../common/public-web-base-url.service';
import { MediaUrlCanonicalizerService } from '../media/media-url-canonicalizer.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  attachWriterProfileToDetail,
  publishedMonoDetailFromRow,
} from '../published-monos/published-mono-common';
import { PUBLISHED_MONO_CATALOG_VISIBLE } from '../published-monos/published-mono-visibility';
import type { PublishedMonoDetailDto } from '../published-monos/published-monos.dto';

import type { MonoFeedListResponseDto, MonoFeedSummaryItemDto } from './mono-feed.dto';

const DEFAULT_LIMIT = 15;
const MAX_LIMIT = 30;

const DEFAULT_CONTENT_LOCALE = 'en';
const DEFAULT_LEARNING_LANGUAGE = 'ja';

function normalizeCode(v: string | null | undefined): string | null {
  if (v == null) return null;
  const t = String(v).trim().toLowerCase();
  return t ? t : null;
}

function ensureAllowedContentLocale(
  v: string | null,
): 'en' | 'my' | 'ja' | null {
  if (v == null) return null;
  if (v === 'en' || v === 'my' || v === 'ja') return v;
  throw new BadRequestException('contentLocale_invalid');
}

function ensureAllowedLearningLanguage(v: string | null): 'ja' | null {
  if (v == null) return null;
  if (v === 'ja') return v;
  throw new BadRequestException('learningLanguage_invalid');
}

/**
 * User-preference values may be invalid if written by older clients; never take down the feed.
 */
function safeStoredContentLocale(
  raw: string | null | undefined,
): 'en' | 'my' | 'ja' {
  const n = normalizeCode(raw);
  if (n === null) return DEFAULT_CONTENT_LOCALE;
  if (n === 'en' || n === 'my' || n === 'ja') return n;
  return DEFAULT_CONTENT_LOCALE;
}

function safeStoredLearningLanguage(raw: string | null | undefined): 'ja' {
  const n = normalizeCode(raw);
  if (n === null) return DEFAULT_LEARNING_LANGUAGE;
  if (n === 'ja') return 'ja';
  return DEFAULT_LEARNING_LANGUAGE;
}

export type MonoFeedCursorPayload = {
  /** ISO 8601 */
  u: string;
  /** published_monos.id */
  i: string;
};

@Injectable()
export class MonoFeedService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaUrlCanonicalizerService,
    private readonly publicWeb: PublicWebBaseUrlService,
  ) {}

  encodeCursor(updatedAt: Date, id: string): string {
    const payload: MonoFeedCursorPayload = {
      u: updatedAt.toISOString(),
      i: id,
    };
    return Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
  }

  decodeCursor(raw: string): MonoFeedCursorPayload {
    let json: string;
    try {
      json = Buffer.from(raw, 'base64url').toString('utf8');
    } catch {
      throw new BadRequestException('invalid_cursor');
    }
    let parsed: unknown;
    try {
      parsed = JSON.parse(json);
    } catch {
      throw new BadRequestException('invalid_cursor');
    }
    if (
      typeof parsed !== 'object' ||
      parsed === null ||
      !('u' in parsed) ||
      !('i' in parsed)
    ) {
      throw new BadRequestException('invalid_cursor');
    }
    const u = (parsed as MonoFeedCursorPayload).u;
    const i = (parsed as MonoFeedCursorPayload).i;
    if (typeof u !== 'string' || typeof i !== 'string' || !u.trim() || !i.trim()) {
      throw new BadRequestException('invalid_cursor');
    }
    const d = new Date(u);
    if (Number.isNaN(d.getTime())) {
      throw new BadRequestException('invalid_cursor');
    }
    return { u, i };
  }

  parseLimit(limitRaw?: string): number {
    if (limitRaw == null || String(limitRaw).trim() === '') {
      return DEFAULT_LIMIT;
    }
    const n = Number(limitRaw);
    if (!Number.isFinite(n)) {
      return DEFAULT_LIMIT;
    }
    const rounded = Math.floor(n);
    return Math.min(Math.max(rounded, 1), MAX_LIMIT);
  }

  /**
   * Derives cover URL and publishKind from `content` JSON without returning full blob to clients.
   */
  private extractContentMeta(content: unknown): {
    coverUrl: string | null;
    publishKind: string | null;
    hasAudio: boolean;
  } {
    const c = (content ?? {}) as Record<string, unknown>;
    const publishKind =
      typeof c.publishKind === 'string' && c.publishKind.trim() !== ''
        ? c.publishKind.trim()
        : null;
    const core =
      c.core && typeof c.core === 'object'
        ? (c.core as Record<string, unknown>)
        : {};
    const coverUrl =
      typeof core.coverImageUrl === 'string' && core.coverImageUrl.trim() !== ''
        ? core.coverImageUrl.trim()
        : null;
    const learn =
      c.learn && typeof c.learn === 'object'
        ? (c.learn as Record<string, unknown>)
        : {};
    const audio =
      learn.audio && typeof learn.audio === 'object'
        ? (learn.audio as Record<string, unknown>)
        : {};
    const storyAudio =
      audio.storyAudio && typeof audio.storyAudio === 'object'
        ? (audio.storyAudio as Record<string, unknown>)
        : null;
    const sourceUrl =
      storyAudio && typeof storyAudio.sourceUrl === 'string'
        ? storyAudio.sourceUrl.trim()
        : '';
    const hasAudio = sourceUrl.length > 0;
    return { coverUrl, publishKind, hasAudio };
  }

  private publicWebBaseUrl(): string {
    const raw =
      process.env.NIMON_PUBLIC_WEB_BASE_URL?.trim() ||
      process.env.PUBLIC_WEB_BASE_URL?.trim() ||
      '';
    const base = raw.replace(/\/+$/, '');
    return base || 'http://localhost:3000';
  }

  private shareUrlFor(monoId: string): string {
    const base = this.publicWebBaseUrl();
    return `${base}/mono/${monoId}`;
  }

  private mapRowToSummary(
    row: {
      id: string;
      ownerId: string;
      title: string;
      category: string;
      level: string;
      description: string;
      createdAt: Date;
      updatedAt: Date;
      content: unknown;
      owner: {
        profile: {
          displayName: string | null;
          handle: string | null;
          avatarUrl: string | null;
        } | null;
      } | null;
    },
    opts: {
      likesCount: number;
      isBookmarkedByMe: boolean;
      myReaction: 'heart' | null;
    },
  ): MonoFeedSummaryItemDto {
    const { coverUrl: rawCover, publishKind, hasAudio } =
      this.extractContentMeta(row.content);
    const coverUrl = this.media.url(rawCover);
    const cat = (row.category ?? '').trim();
    return {
      monoId: row.id,
      title: row.title ?? '',
      coverUrl,
      level: row.level ?? '',
      category: row.category ?? '',
      categories: cat ? [cat] : [],
      description: row.description ?? '',
      writerId: row.ownerId,
      writerHandle: row.owner?.profile?.handle ?? null,
      writerDisplayName: row.owner?.profile?.displayName ?? null,
      writerAvatarUrl: this.media.url(row.owner?.profile?.avatarUrl ?? null),
      publishedAt: row.createdAt.toISOString(),
      updatedAt: row.updatedAt.toISOString(),
      likesCount: opts.likesCount,
      hasAudio,
      isBookmarkedByMe: opts.isBookmarkedByMe,
      myReaction: opts.myReaction,
      shareUrl: this.publicWeb.monoShareUrl(row.id),
      publishKind,
      accessType: 'public',
    };
  }

  /**
   * Public catalog list — `published_monos` only, ordered by `updatedAt` desc, `id` desc.
   * Selects `content` only to derive `coverUrl` and `publishKind`; response items exclude raw `content`.
   */
  async listFeed(options: {
    limit: number;
    cursor?: string;
    sort?: string;
    level?: string;
    category?: string;
    writerId?: string;
    contentLocale?: string;
    learningLanguage?: string;
    userId?: string | null;
    followingOnly?: boolean;
  }): Promise<MonoFeedListResponseDto> {
    const sort = (options.sort ?? 'recent').trim();
    if (sort !== '' && sort !== 'recent') {
      throw new BadRequestException('unsupported_sort');
    }

    const take = options.limit + 1;
    const levelF = options.level?.trim();
    const categoryF = options.category?.trim();

    // Resolve preference defaults (auth) and apply query overrides.
    const contentLocaleQ = ensureAllowedContentLocale(
      normalizeCode(options.contentLocale),
    );
    const learningLanguageQ = ensureAllowedLearningLanguage(
      normalizeCode(options.learningLanguage),
    );
    let effectiveContentLocale: 'en' | 'my' | 'ja' = DEFAULT_CONTENT_LOCALE;
    let effectiveLearningLanguage: 'ja' = DEFAULT_LEARNING_LANGUAGE;
    if (options.userId) {
      const pref = await this.prisma.userPreference.findUnique({
        where: { userId: options.userId },
        select: { contentLocale: true, learningLanguage: true },
      });
      effectiveContentLocale = safeStoredContentLocale(pref?.contentLocale);
      effectiveLearningLanguage = safeStoredLearningLanguage(pref?.learningLanguage);
    }
    if (contentLocaleQ) effectiveContentLocale = contentLocaleQ;
    if (learningLanguageQ) effectiveLearningLanguage = learningLanguageQ;

    const and: import('@prisma/client').Prisma.PublishedMonoWhereInput[] = [
      PUBLISHED_MONO_CATALOG_VISIBLE,
    ];
    // Include legacy rows where locale tags are unset (null).
    and.push({
      AND: [
        {
          OR: [
            { contentLocale: effectiveContentLocale },
            { contentLocale: null },
          ],
        },
        {
          OR: [
            { learningLanguage: effectiveLearningLanguage },
            { learningLanguage: null },
          ],
        },
      ],
    });
    if (options.followingOnly) {
      const uid = options.userId ?? null;
      if (!uid) {
        // Controller should already have enforced auth, but keep it safe.
        throw new BadRequestException('following_requires_auth');
      }
      const edges = await this.prisma.userFollow.findMany({
        where: { followerId: uid },
        select: { followingId: true },
      });
      const followedIds = edges.map((e) => e.followingId);
      if (followedIds.length === 0) {
        return { items: [], nextCursor: null, hasMore: false };
      }
      and.push({ ownerId: { in: followedIds } });
    }
    const writerIdF = (options.writerId ?? '').trim();
    if (writerIdF) {
      and.push({ ownerId: writerIdF });
    }
    if (levelF) and.push({ level: levelF });
    if (categoryF) and.push({ category: categoryF });
    if (options.cursor) {
      const { u, i } = this.decodeCursor(options.cursor);
      const cAt = new Date(u);
      and.push({
        OR: [
          { updatedAt: { lt: cAt } },
          { AND: [{ updatedAt: cAt }, { id: { lt: i } }] },
        ],
      });
    }
    const where: import('@prisma/client').Prisma.PublishedMonoWhereInput = {
      AND: and,
    };

    const rows = await this.prisma.publishedMono.findMany({
      where,
      orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
      take,
      select: {
        id: true,
        ownerId: true,
        contentLocale: true,
        learningLanguage: true,
        title: true,
        category: true,
        level: true,
        description: true,
        createdAt: true,
        updatedAt: true,
        content: true,
        owner: {
          select: {
            profile: {
              select: { displayName: true, handle: true, avatarUrl: true },
            },
          },
        },
      },
    });

    const hasMore = rows.length > options.limit;
    const page = hasMore ? rows.slice(0, options.limit) : rows;
    const last = page[page.length - 1];
    const nextCursor =
      hasMore && last
        ? this.encodeCursor(last.updatedAt, last.id)
        : null;

    const ids = page.map((r) => r.id);
    const likeGroups =
      ids.length === 0
        ? []
        : await this.prisma.monoReaction.groupBy({
            by: ['publishedMonoId'],
            where: { publishedMonoId: { in: ids }, kind: 'heart' },
            _count: { _all: true },
          });
    const likesById = new Map<string, number>();
    for (const g of likeGroups) {
      likesById.set(g.publishedMonoId, g._count._all);
    }

    const uid = options.userId ?? null;
    const bookmarkedIds =
      uid && ids.length
        ? new Set(
            (
              await this.prisma.monoBookmark.findMany({
                where: { userId: uid, publishedMonoId: { in: ids } },
                select: { publishedMonoId: true },
              })
            ).map((x) => x.publishedMonoId),
          )
        : new Set<string>();

    const reactedIds =
      uid && ids.length
        ? new Set(
            (
              await this.prisma.monoReaction.findMany({
                where: { userId: uid, publishedMonoId: { in: ids }, kind: 'heart' },
                select: { publishedMonoId: true },
              })
            ).map((x) => x.publishedMonoId),
          )
        : new Set<string>();

    return {
      items: page.map((r) =>
        this.mapRowToSummary(r, {
          likesCount: likesById.get(r.id) ?? 0,
          isBookmarkedByMe: bookmarkedIds.has(r.id),
          myReaction: reactedIds.has(r.id) ? 'heart' : null,
        }),
      ),
      nextCursor,
      hasMore,
    };
  }

  /**
   * Public reader detail by mono id (not owner-scoped). Same JSON shape as owner `GET /v1/published-monos/:id`.
   */
  async getPublicMonoById(
    id: string,
    userId?: string | null,
  ): Promise<PublishedMonoDetailDto & {
    likesCount: number;
    isBookmarkedByMe: boolean;
    myReaction: 'heart' | null;
    shareUrl: string;
  }> {
    const rid = id.trim();
    if (!rid) {
      throw new NotFoundException('published_mono_not_found');
    }
    const m = await this.prisma.publishedMono.findFirst({
      where: { id: rid, ...PUBLISHED_MONO_CATALOG_VISIBLE },
      select: {
        id: true,
        ownerId: true,
        createdAt: true,
        updatedAt: true,
        title: true,
        category: true,
        level: true,
        description: true,
        content: true,
      },
    });
    if (!m) {
      throw new NotFoundException('published_mono_not_found');
    }
    const likesCount = await this.prisma.monoReaction.count({
      where: { publishedMonoId: rid, kind: 'heart' },
    });
    const uid = userId ?? null;
    const isBookmarkedByMe = uid
      ? (await this.prisma.monoBookmark.count({
          where: { userId: uid, publishedMonoId: rid },
        })) > 0
      : false;
    const myReaction = uid
      ? (await this.prisma.monoReaction.findFirst({
          where: { userId: uid, publishedMonoId: rid, kind: 'heart' },
          select: { kind: true },
        }))
      : null;

    const wp = await this.prisma.userProfile.findUnique({
      where: { userId: m.ownerId },
      select: { displayName: true, handle: true, avatarUrl: true },
    });
    const writer = wp
      ? {
          displayName: wp.displayName ?? null,
          handle: wp.handle ?? null,
          avatarUrl: wp.avatarUrl ?? null,
        }
      : null;

    const base = this.media.mediaPublicBaseUrl();
    const core = attachWriterProfileToDetail(
      publishedMonoDetailFromRow(m, base),
      writer,
      base,
    );

    return {
      ...core,
      likesCount,
      isBookmarkedByMe,
      myReaction: myReaction?.kind === 'heart' ? 'heart' : null,
      shareUrl: this.publicWeb.monoShareUrl(rid),
    };
  }
}
