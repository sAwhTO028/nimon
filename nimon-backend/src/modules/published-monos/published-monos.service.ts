import { HttpStatus, Injectable, NotFoundException } from '@nestjs/common';

import { apiError } from '../../common/api-error';
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
import { PUBLISHED_MONO_CATALOG_VISIBLE } from './published-mono-visibility';

function parseTrashedQuery(raw?: string): boolean {
  const t = (raw ?? '').trim().toLowerCase();
  return t === 'true' || t === '1' || t === 'yes';
}

@Injectable()
export class PublishedMonosService {
  constructor(private readonly prisma: PrismaService) {}

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
  ): Promise<PublishedMonoListResponseDto> {
    const limitNum = limitRaw ? Number(limitRaw) : 50;
    const take = Number.isFinite(limitNum)
      ? Math.min(Math.max(limitNum, 1), 100)
      : 50;

    const trashedOnly = parseTrashedQuery(trashedRaw);
    const where = trashedOnly
      ? { ownerId, trashedAt: { not: null } }
      : { ownerId, ...PUBLISHED_MONO_CATALOG_VISIBLE };

    const rows = await this.prisma.publishedMono.findMany({
      where,
      orderBy: { updatedAt: 'desc' },
      take,
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

    const writer = await this.writerProfile(ownerId);
    const items = rows.map((row) =>
      attachWriterProfileToListItem(publishedMonoListItemFromRow(row), writer),
    );

    return { items, nextCursor: null };
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
    return attachWriterProfileToDetail(publishedMonoDetailFromRow(m), writer);
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
