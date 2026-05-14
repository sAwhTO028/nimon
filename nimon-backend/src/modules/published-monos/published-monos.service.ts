import {
  BadRequestException,
  HttpStatus,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';

import { apiError } from '../../common/api-error';
import { PublicWebBaseUrlService } from '../common/public-web-base-url.service';
import { MediaUrlCanonicalizerService } from '../media/media-url-canonicalizer.service';
import { PrismaService } from '../prisma/prisma.service';

import type {
  PublishedMonoDetailDto,
  PublishedMonoListResponseDto,
  PublishedMonoRestoreResponseDto,
  PublishedMonoTrashResponseDto,
} from './published-monos.dto';

import {
  attachWriterProfileToDetail,
  attachWriterProfileToListItem,
  publishedMonoDetailFromRow,
  publishedMonoListItemFromRow,
  type WriterProfileSlice,
} from './published-mono-common';
import { assertCanRevealOnePublishedTabMono } from './published-mono-published-tab-quota';
import { PUBLISHED_MONO_CATALOG_VISIBLE } from './published-mono-visibility';

import type { Prisma } from '@prisma/client';

function parseTrashedQuery(raw?: string): boolean {
  const t = (raw ?? '').trim().toLowerCase();
  return t === 'true' || t === '1' || t === 'yes';
}

/** Same cursor envelope as `MonoFeedService` (`updatedAt` + `id`), base64url JSON. */
type PublishedMonoListCursorPayload = {
  u: string;
  i: string;
};

const PUBLISHED_LIST_DEFAULT_LIMIT = 20;
const PUBLISHED_LIST_MAX_LIMIT = 50;

function parsePublishedListLimit(limitRaw?: string): number {
  if (limitRaw == null || String(limitRaw).trim() === '') {
    return PUBLISHED_LIST_DEFAULT_LIMIT;
  }
  const n = Number(limitRaw);
  if (!Number.isFinite(n)) {
    return PUBLISHED_LIST_DEFAULT_LIMIT;
  }
  const rounded = Math.floor(n);
  return Math.min(Math.max(rounded, 1), PUBLISHED_LIST_MAX_LIMIT);
}

function encodePublishedListCursor(updatedAt: Date, id: string): string {
  const payload: PublishedMonoListCursorPayload = {
    u: updatedAt.toISOString(),
    i: id,
  };
  return Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
}

function decodePublishedListCursor(raw: string): PublishedMonoListCursorPayload {
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
  const u = (parsed as PublishedMonoListCursorPayload).u;
  const i = (parsed as PublishedMonoListCursorPayload).i;
  if (typeof u !== 'string' || typeof i !== 'string' || !u.trim() || !i.trim()) {
    throw new BadRequestException('invalid_cursor');
  }
  const d = new Date(u);
  if (Number.isNaN(d.getTime())) {
    throw new BadRequestException('invalid_cursor');
  }
  return { u, i };
}

function parsePublishedListSort(sortRaw?: string): void {
  const s = (sortRaw ?? '').trim().toLowerCase();
  if (s === '' || s === 'latest' || s === 'recent') {
    return;
  }
  throw new BadRequestException('unsupported_sort');
}

@Injectable()
export class PublishedMonosService {
  private readonly logger = new Logger(PublishedMonosService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaUrlCanonicalizerService,
    private readonly publicWeb: PublicWebBaseUrlService,
  ) {}

  /**
   * Profile / "my published" list — caller must pass the authenticated owner id
   * (from JWT). Not a public catalog; unauthenticated public reader APIs would be
   * a separate route in a later milestone.
   *
   * `trashed=true` (or `1`/`yes`): **Trash** list — rows with `trashedAt != null` only,
   * no dirty-draft hiding predicate (everything in Trash).
   */
  private async writerProfile(ownerId: string): Promise<WriterProfileSlice | null> {
    const p = await this.prisma.userProfile.findUnique({
      where: { userId: ownerId },
      select: { displayName: true, handle: true, avatarUrl: true },
    });
    if (!p) return null;
    return {
      displayName: p.displayName ?? null,
      handle: p.handle ?? null,
      avatarUrl: p.avatarUrl ?? null,
    };
  }

  async listPublishedMonos(
    ownerId: string,
    limitRaw?: string,
    trashedRaw?: string,
    cursorRaw?: string,
    sortRaw?: string,
  ): Promise<PublishedMonoListResponseDto> {
    parsePublishedListSort(sortRaw);
    const limit = parsePublishedListLimit(limitRaw);
    const trashedOnly = parseTrashedQuery(trashedRaw);
    const whereBase: Prisma.PublishedMonoWhereInput = trashedOnly
      ? { ownerId, trashedAt: { not: null } }
      : { ownerId, ...PUBLISHED_MONO_CATALOG_VISIBLE };

    const cursorTrim = (cursorRaw ?? '').trim();
    const and: Prisma.PublishedMonoWhereInput[] = [whereBase];
    if (cursorTrim) {
      const { u, i } = decodePublishedListCursor(cursorTrim);
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
      },
    });

    const hasMore = rows.length > limit;
    const pageRows = hasMore ? rows.slice(0, limit) : rows;

    const totalCount: number | null =
      !trashedOnly && !cursorTrim
        ? await this.prisma.publishedMono.count({ where: whereBase })
        : null;

    const writer = await this.writerProfile(ownerId);
    const base = this.media.mediaPublicBaseUrl();
    const items = pageRows.map((row) => ({
      ...attachWriterProfileToListItem(
        publishedMonoListItemFromRow(row, base),
        writer,
        base,
      ),
      shareUrl: this.publicWeb.monoShareUrl(row.id),
    }));

    const last = pageRows[pageRows.length - 1];
    const nextCursor =
      hasMore && last ? encodePublishedListCursor(last.updatedAt, last.id) : null;

    const result: PublishedMonoListResponseDto = {
      items,
      nextCursor,
      hasMore,
      totalCount,
    };

    // M17C-5 TEMP: runtime truth for GET /v1/published-monos (remove after diagnosis).
    this.logger.log(
      `[M17C-5] route=GET /v1/published-monos listPublishedMonos ` +
        `userId=${ownerId} limit=${limit} limitRaw=${String(limitRaw ?? '')} ` +
        `cursor=${cursorTrim.length ? cursorTrim : 'null'} trashed=${trashedOnly} ` +
        `rowsFetched=${rows.length} itemsReturned=${items.length} hasMore=${String(hasMore)} ` +
        `nextCursor=${nextCursor == null ? 'null' : 'non-null'} ` +
        `totalCount=${totalCount == null ? 'null' : String(totalCount)} ` +
        `responseKeys=${Object.keys(result).sort().join(',')}`,
    );

    return result;
  }

  /**
   * Owner-scoped detail for Profile / app reader entry (same `ownerId` as list).
   */
  async getPublishedMonoById(
    ownerId: string,
    id: string,
  ): Promise<PublishedMonoDetailDto> {
    const m = await this.prisma.publishedMono.findFirst({
      where: { id, ownerId, ...PUBLISHED_MONO_CATALOG_VISIBLE },
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

    const writer = await this.writerProfile(ownerId);
    const base = this.media.mediaPublicBaseUrl();
    return {
      ...attachWriterProfileToDetail(publishedMonoDetailFromRow(m, base), writer, base),
      shareUrl: this.publicWeb.monoShareUrl(m.id),
    };
  }

  /** Idempotent: already trashed rows return existing `trashedAt`. */
  async trashPublishedMono(ownerId: string, id: string): Promise<PublishedMonoTrashResponseDto> {
    const rid = id.trim();
    const row = await this.prisma.publishedMono.findFirst({
      where: { id: rid, ownerId },
      select: { id: true, trashedAt: true },
    });
    if (!row) {
      throw new NotFoundException('published_mono_not_found');
    }
    if (row.trashedAt) {
      return { id: row.id, trashedAt: row.trashedAt.toISOString() };
    }
    const now = new Date();
    await this.prisma.publishedMono.updateMany({
      where: { id: rid, ownerId, trashedAt: null },
      data: { trashedAt: now },
    });
    const after = await this.prisma.publishedMono.findFirst({
      where: { id: rid, ownerId },
      select: { trashedAt: true },
    });
    const ts = after?.trashedAt ?? now;
    return { id: rid, trashedAt: ts.toISOString() };
  }

  /**
   * Clears Trash. Returns **400 published_mono_not_trashed** when the row exists
   * and is active (never trashed) — client should use the default published list shape.
   */
  async restorePublishedMono(
    ownerId: string,
    id: string,
  ): Promise<PublishedMonoRestoreResponseDto> {
    const rid = id.trim();
    const row = await this.prisma.publishedMono.findFirst({
      where: { id: rid, ownerId },
      select: { id: true, trashedAt: true },
    });
    if (!row) {
      throw new NotFoundException('published_mono_not_found');
    }
    if (row.trashedAt == null) {
      throw apiError(
        HttpStatus.BAD_REQUEST,
        'published_mono_not_trashed',
        'Published mono is not in Trash',
      );
    }
    await assertCanRevealOnePublishedTabMono(
      this.prisma,
      ownerId,
      { tag: 'restore-quota', publishedMonoId: rid },
      (line) => this.logger.log(line),
    );
    await this.prisma.publishedMono.updateMany({
      where: { id: rid, ownerId },
      data: { trashedAt: null },
    });
    return { id: rid, trashedAt: null };
  }

  /**
   * Hard delete for trashed PublishedMono only (P3).
   *
   * V1 idempotency: if already deleted, caller receives 404 on retry.
   */
  async permanentlyDeletePublishedMono(
    ownerId: string,
    id: string,
    confirm?: string,
  ): Promise<void> {
    const rid = id.trim();
    if ((confirm ?? '').trim() !== 'DELETE') {
      throw apiError(
        HttpStatus.BAD_REQUEST,
        'missing_delete_confirm',
        'Permanent delete requires confirm=DELETE',
      );
    }

    await this.prisma.$transaction(async (tx) => {
      const row = await tx.publishedMono.findFirst({
        where: { id: rid, ownerId },
        select: { id: true, trashedAt: true },
      });
      if (!row) {
        throw new NotFoundException('published_mono_not_found');
      }
      if (row.trashedAt == null) {
        throw apiError(
          HttpStatus.BAD_REQUEST,
          'published_mono_must_be_trashed_first',
          'Published mono must be in Trash before permanent delete',
        );
      }

      // Delete all linked drafts (cascades to draft_sentences, vocab/grammar/quiz/audio).
      await tx.storyDraft.deleteMany({
        where: { ownerId, publishedMonoId: rid },
      });

      // Delete the PublishedMono itself.
      await tx.publishedMono.deleteMany({
        where: { ownerId, id: rid },
      });
    });
  }
}
