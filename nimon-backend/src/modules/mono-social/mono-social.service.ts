import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { FREE_TIER_QUOTA_KEYS, FREE_TIER_QUOTAS } from '../../common/limits/free-tier-quotas';
import { QuotaExceededException } from '../../common/limits/quota-exceeded.exception';
import { PublicWebBaseUrlService } from '../common/public-web-base-url.service';
import { MediaUrlCanonicalizerService } from '../media/media-url-canonicalizer.service';
import { PrismaService } from '../prisma/prisma.service';
import { durationLabelFromKey } from '../published-monos/published-mono-common';
import { PUBLISHED_MONO_CATALOG_VISIBLE } from '../published-monos/published-mono-visibility';
import type {
  MonoBookmarkStateDto,
  MonoBookmarksListResponseDto,
  MonoReactionStateDto,
} from './mono-social.dto';

type CursorPayload = { c: string; i: string };

@Injectable()
export class MonoSocialService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaUrlCanonicalizerService,
    private readonly publicWeb: PublicWebBaseUrlService,
  ) {}

  private encodeCursor(createdAt: Date, id: string): string {
    const payload: CursorPayload = { c: createdAt.toISOString(), i: id };
    return Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
  }

  private decodeCursor(raw: string): CursorPayload {
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
      !('c' in parsed) ||
      !('i' in parsed)
    ) {
      throw new BadRequestException('invalid_cursor');
    }
    const c = (parsed as CursorPayload).c;
    const i = (parsed as CursorPayload).i;
    if (typeof c !== 'string' || typeof i !== 'string' || !c.trim() || !i.trim()) {
      throw new BadRequestException('invalid_cursor');
    }
    const d = new Date(c);
    if (Number.isNaN(d.getTime())) throw new BadRequestException('invalid_cursor');
    return { c, i };
  }

  private async requireCatalogVisibleMono(monoId: string) {
    const rid = monoId.trim();
    if (!rid) throw new NotFoundException('published_mono_not_found');
    const found = await this.prisma.publishedMono.findFirst({
      where: { id: rid, ...PUBLISHED_MONO_CATALOG_VISIBLE },
      select: { id: true },
    });
    if (!found) throw new NotFoundException('published_mono_not_found');
    return rid;
  }

  async bookmark(userId: string, monoId: string): Promise<MonoBookmarkStateDto> {
    const rid = await this.requireCatalogVisibleMono(monoId);
    const existing = await this.prisma.monoBookmark.findUnique({
      where: { userId_publishedMonoId: { userId, publishedMonoId: rid } },
      select: { publishedMonoId: true },
    });
    if (!existing) {
      const savedCount = await this.prisma.monoBookmark.count({ where: { userId } });
      if (savedCount >= FREE_TIER_QUOTAS.savedMonos) {
        throw new QuotaExceededException(
          FREE_TIER_QUOTA_KEYS.savedMonos,
          FREE_TIER_QUOTAS.savedMonos,
          savedCount,
        );
      }
    }
    await this.prisma.monoBookmark.upsert({
      where: { userId_publishedMonoId: { userId, publishedMonoId: rid } },
      update: {},
      create: { userId, publishedMonoId: rid },
    });
    return { publishedMonoId: rid, isBookmarkedByMe: true };
  }

  async unbookmark(
    userId: string,
    monoId: string,
  ): Promise<MonoBookmarkStateDto> {
    const rid = await this.requireCatalogVisibleMono(monoId);
    await this.prisma.monoBookmark.deleteMany({
      where: { userId, publishedMonoId: rid },
    });
    return { publishedMonoId: rid, isBookmarkedByMe: false };
  }

  async reactHeart(
    userId: string,
    monoId: string,
  ): Promise<MonoReactionStateDto> {
    const rid = await this.requireCatalogVisibleMono(monoId);
    await this.prisma.monoReaction.upsert({
      where: { userId_publishedMonoId: { userId, publishedMonoId: rid } },
      update: { kind: 'heart' },
      create: { userId, publishedMonoId: rid, kind: 'heart' },
    });
    const likesCount = await this.prisma.monoReaction.count({
      where: { publishedMonoId: rid, kind: 'heart' },
    });
    return { publishedMonoId: rid, likesCount, myReaction: 'heart' };
  }

  async unreact(
    userId: string,
    monoId: string,
  ): Promise<MonoReactionStateDto> {
    const rid = await this.requireCatalogVisibleMono(monoId);
    await this.prisma.monoReaction.deleteMany({
      where: { userId, publishedMonoId: rid },
    });
    const likesCount = await this.prisma.monoReaction.count({
      where: { publishedMonoId: rid, kind: 'heart' },
    });
    return { publishedMonoId: rid, likesCount, myReaction: null };
  }

  async listMyBookmarks(opts: {
    userId: string;
    limit: number;
    cursor?: string;
  }): Promise<MonoBookmarksListResponseDto> {
    const limit = Math.min(Math.max(Math.floor(opts.limit || 15), 1), 30);
    const take = limit + 1;

    const and: import('@prisma/client').Prisma.MonoBookmarkWhereInput[] = [
      { userId: opts.userId },
      { publishedMono: PUBLISHED_MONO_CATALOG_VISIBLE },
    ];
    if (opts.cursor) {
      const { c, i } = this.decodeCursor(opts.cursor);
      const cAt = new Date(c);
      and.push({
        OR: [
          { createdAt: { lt: cAt } },
          { AND: [{ createdAt: cAt }, { id: { lt: i } }] },
        ],
      });
    }

    const listWhere: import('@prisma/client').Prisma.MonoBookmarkWhereInput = {
      userId: opts.userId,
      publishedMono: PUBLISHED_MONO_CATALOG_VISIBLE,
    };

    const [rows, totalCount] = await Promise.all([
      this.prisma.monoBookmark.findMany({
      where: { AND: and },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take,
      select: {
        id: true,
        createdAt: true,
        publishedMono: {
          select: {
            id: true,
            ownerId: true,
            title: true,
            category: true,
            level: true,
            description: true,
            createdAt: true,
            updatedAt: true,
            content: true,
            contentLocale: true,
            learningLanguage: true,
            owner: {
              select: {
                profile: { select: { displayName: true, handle: true } },
              },
            },
          },
        },
      },
    }),
      this.prisma.monoBookmark.count({ where: listWhere }),
    ]);

    const hasMore = rows.length > limit;
    const page = hasMore ? rows.slice(0, limit) : rows;
    const next = page[page.length - 1];
    const nextCursor =
      hasMore && next ? this.encodeCursor(next.createdAt, next.id) : null;

    const monoIds = page.map((r) => r.publishedMono.id);
    const likeGroups =
      monoIds.length === 0
        ? []
        : await this.prisma.monoReaction.groupBy({
            by: ['publishedMonoId'],
            where: { publishedMonoId: { in: monoIds }, kind: 'heart' },
            _count: { _all: true },
          });
    const likesById = new Map<string, number>();
    for (const g of likeGroups) {
      likesById.set(g.publishedMonoId, g._count._all);
    }
    const myReactions = monoIds.length
      ? await this.prisma.monoReaction.findMany({
          where: { userId: opts.userId, publishedMonoId: { in: monoIds }, kind: 'heart' },
          select: { publishedMonoId: true, kind: true },
        })
      : [];
    const myReacted = new Set(myReactions.map((r) => r.publishedMonoId));
    const items = page.map((b) => {
      const m = b.publishedMono;
      const content = (m.content ?? {}) as any;
      const publishKind = typeof content.publishKind === 'string' ? content.publishKind : null;
      const core = content?.core && typeof content.core === 'object' ? content.core : {};
      const rawCover =
        typeof core?.coverImageUrl === 'string' && core.coverImageUrl.trim() !== ''
          ? core.coverImageUrl.trim()
          : null;
      const coverUrl = this.media.url(rawCover);
      const learn = content?.learn && typeof content.learn === 'object' ? content.learn : {};
      const audio = learn?.audio && typeof learn.audio === 'object' ? learn.audio : {};
      const storyAudio =
        audio?.storyAudio && typeof audio.storyAudio === 'object'
          ? audio.storyAudio
          : null;
      const hasAudio =
        typeof storyAudio?.sourceUrl === 'string' &&
        storyAudio.sourceUrl.trim() !== '';
      const cat = (m.category ?? '').trim();
      const durationKey =
        typeof core?.targetDurationBandKey === 'string'
          ? core.targetDurationBandKey.trim()
          : null;
      const targetDurationLabel = durationLabelFromKey(durationKey);
      return {
        monoId: m.id,
        title: m.title ?? '',
        coverUrl,
        level: m.level ?? '',
        category: m.category ?? '',
        categories: cat ? [cat] : [],
        description: m.description ?? '',
        writerId: m.ownerId,
        writerHandle: m.owner?.profile?.handle ?? null,
        writerDisplayName: m.owner?.profile?.displayName ?? null,
        publishedAt: m.createdAt.toISOString(),
        updatedAt: m.updatedAt.toISOString(),
        likesCount: likesById.get(m.id) ?? 0,
        hasAudio,
        isBookmarkedByMe: true as const,
        myReaction: myReacted.has(m.id) ? ('heart' as const) : null,
        shareUrl: this.publicWeb.monoShareUrl(m.id),
        publishKind,
        accessType: 'public' as const,
        bookmarkedAt: b.createdAt.toISOString(),
        targetDurationLabel,
        contentLocale:
          m.contentLocale != null && String(m.contentLocale).trim() !== ''
            ? String(m.contentLocale).trim()
            : null,
        learningLanguage:
          m.learningLanguage != null && String(m.learningLanguage).trim() !== ''
            ? String(m.learningLanguage).trim()
            : null,
      };
    });

    return { items, nextCursor, hasMore, totalCount };
  }
}

