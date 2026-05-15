import { BadRequestException, Injectable } from '@nestjs/common';

import type { Prisma } from '@prisma/client';

import { PublicWebBaseUrlService } from '../common/public-web-base-url.service';
import { MediaUrlCanonicalizerService } from '../media/media-url-canonicalizer.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  attachWriterProfileToListItem,
  publishedMonoListItemFromRow,
  type WriterProfileSlice,
} from '../published-monos/published-mono-common';
import { PUBLISHED_MONO_CATALOG_VISIBLE } from '../published-monos/published-mono-visibility';

import type {
  PublishedMonoSearchListItemDto,
  SearchPublishedMonosResponseDto,
} from './search.dto';

const SEARCH_DEFAULT_LIMIT = 20;
const SEARCH_MAX_LIMIT = 50;
const MAX_QUERY_TOKENS = 12;
const MAX_QUERY_LENGTH = 240;

const ALLOWED_LEVELS = new Set(['N5', 'N4', 'N3', 'N2', 'N1']);

/** Same cursor envelope as `PublishedMonosService` / `MonoFeedService` (`updatedAt` + `id`), base64url JSON. */
type SearchMonoCursorPayload = {
  u: string;
  i: string;
};

function parseSearchLimit(limitRaw?: string): number {
  if (limitRaw == null || String(limitRaw).trim() === '') {
    return SEARCH_DEFAULT_LIMIT;
  }
  const n = Number(limitRaw);
  if (!Number.isFinite(n)) {
    return SEARCH_DEFAULT_LIMIT;
  }
  const rounded = Math.floor(n);
  return Math.min(Math.max(rounded, 1), SEARCH_MAX_LIMIT);
}

function parseSearchSort(sortRaw?: string): void {
  const s = (sortRaw ?? '').trim().toLowerCase();
  if (s === '' || s === 'latest' || s === 'recent') {
    return;
  }
  throw new BadRequestException('unsupported_sort');
}

function encodeSearchCursor(updatedAt: Date, id: string): string {
  const payload: SearchMonoCursorPayload = {
    u: updatedAt.toISOString(),
    i: id,
  };
  return Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
}

function decodeSearchCursor(raw: string): SearchMonoCursorPayload {
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
  const u = (parsed as SearchMonoCursorPayload).u;
  const i = (parsed as SearchMonoCursorPayload).i;
  if (typeof u !== 'string' || typeof i !== 'string' || !u.trim() || !i.trim()) {
    throw new BadRequestException('invalid_cursor');
  }
  const d = new Date(u);
  if (Number.isNaN(d.getTime())) {
    throw new BadRequestException('invalid_cursor');
  }
  return { u, i };
}

function tokenizeSearchQuery(raw: string): string[] {
  const t = raw.trim().slice(0, MAX_QUERY_LENGTH);
  if (!t) return [];
  const parts = t.split(/\s+/).filter((p) => p.length > 0);
  return parts.slice(0, MAX_QUERY_TOKENS);
}

function keywordClauseForToken(tok: string): Prisma.PublishedMonoWhereInput {
  return {
    OR: [
      { title: { contains: tok, mode: 'insensitive' } },
      { description: { contains: tok, mode: 'insensitive' } },
      {
        owner: {
          profile: {
            OR: [
              { displayName: { contains: tok, mode: 'insensitive' } },
              { handle: { contains: tok, mode: 'insensitive' } },
            ],
          },
        },
      },
    ],
  };
}

@Injectable()
export class SearchService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaUrlCanonicalizerService,
    private readonly publicWeb: PublicWebBaseUrlService,
  ) {}

  async searchPublishedMonos(options: {
    q?: string;
    level?: string;
    category?: string;
    sort?: string;
    limitRaw?: string;
    cursor?: string;
    viewerUserId?: string | null;
  }): Promise<SearchPublishedMonosResponseDto> {
    parseSearchSort(options.sort);
    const limit = parseSearchLimit(options.limitRaw);
    const cursorTrim = (options.cursor ?? '').trim();

    const levelRaw = (options.level ?? '').trim();
    if (levelRaw && !ALLOWED_LEVELS.has(levelRaw)) {
      throw new BadRequestException('invalid_level');
    }

    const categoryRaw = (options.category ?? '').trim();

    const tokens = tokenizeSearchQuery(options.q ?? '');

    const and: Prisma.PublishedMonoWhereInput[] = [PUBLISHED_MONO_CATALOG_VISIBLE];

    if (levelRaw) {
      and.push({ level: levelRaw });
    }
    if (categoryRaw) {
      and.push({ category: categoryRaw });
    }

    if (tokens.length) {
      and.push({
        AND: tokens.map((tok) => keywordClauseForToken(tok)),
      });
    }

    if (cursorTrim) {
      const { u, i } = decodeSearchCursor(cursorTrim);
      const cAt = new Date(u);
      and.push({
        OR: [
          { updatedAt: { lt: cAt } },
          { AND: [{ updatedAt: cAt }, { id: { lt: i } }] },
        ],
      });
    }

    const where: Prisma.PublishedMonoWhereInput =
      and.length === 1 ? and[0]! : { AND: and };

    const rows = await this.prisma.publishedMono.findMany({
      where,
      orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
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
        owner: {
          select: {
            profile: {
              select: { displayName: true, handle: true, avatarUrl: true },
            },
          },
        },
      },
    });

    const hasMore = rows.length > limit;
    const pageRows = hasMore ? rows.slice(0, limit) : rows;

    const totalCount: number | null = cursorTrim
      ? null
      : await this.prisma.publishedMono.count({ where });

    const base = this.media.mediaPublicBaseUrl();
    const ids = pageRows.map((r) => r.id);

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

    const uid = options.viewerUserId ?? null;
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

    const items: PublishedMonoSearchListItemDto[] = pageRows.map((row) => {
      const prof = row.owner?.profile;
      const writer: WriterProfileSlice | null = prof
        ? {
            displayName: prof.displayName ?? null,
            handle: prof.handle ?? null,
            avatarUrl: prof.avatarUrl ?? null,
          }
        : null;
      const baseItem = attachWriterProfileToListItem(
        publishedMonoListItemFromRow(row, base),
        writer,
        base,
      );
      return {
        ...baseItem,
        shareUrl: this.publicWeb.monoShareUrl(row.id),
        likesCount: likesById.get(row.id) ?? 0,
        isBookmarkedByMe: bookmarkedIds.has(row.id),
        myReaction: reactedIds.has(row.id) ? 'heart' : null,
      };
    });

    const last = pageRows[pageRows.length - 1];
    const nextCursor =
      hasMore && last ? encodeSearchCursor(last.updatedAt, last.id) : null;

    return {
      items,
      nextCursor,
      hasMore,
      totalCount,
    };
  }
}
