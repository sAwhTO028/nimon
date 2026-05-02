import { HttpStatus, Injectable } from '@nestjs/common';
import { Prisma, PublishState } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { apiError } from '../../common/api-error';
import {
  DraftListSummaryResponseDto,
  DraftListWorkspaceState,
  ListStoryDraftsQuery,
  StoryDraftListEnvelopeDto,
  StoryDraftResponseDto,
} from './dto/story-draft.dto';
import {
  CreateStoryDraftRequestDto,
  StoryDraftWriteDto,
} from './dto/story-draft.requests';

const DEFAULT_DEV_OWNER_ID = '00000000-0000-0000-0000-000000000001';

/** GET /v1/story-drafts — aligns with docs/NIMON_API_QUERY_CONTRACT.md §3 (workspace). */
/** Default matches pre-pagination remote list (Flutter `listDraftIds()` omits `limit`). */
const LIST_DEFAULT_LIMIT = 50;
const LIST_MAX_LIMIT = 50;
const PREVIEW_MAX_CHARS = 200;

type ListCursorPayload = { u: string; i: string };

@Injectable()
export class StoryDraftsService {
  constructor(private readonly prisma: PrismaService) {}

  private getDevOwnerId(): string {
    return process.env.DEV_OWNER_ID ?? DEFAULT_DEV_OWNER_ID;
  }

  private etagFromVersion(version: number): string {
    return `"v${version}"`;
  }

  private requireIfMatch(ifMatch?: string): string {
    if (!ifMatch || !ifMatch.trim()) {
      throw apiError(
        HttpStatus.PRECONDITION_REQUIRED,
        'missing_if_match',
        'If-Match header is required',
      );
    }
    return ifMatch;
  }

  private throwConflict(currentVersion: number) {
    throw apiError(
      HttpStatus.CONFLICT,
      'conflict',
      'Draft was modified; refresh and retry',
      { currentEtag: this.etagFromVersion(currentVersion) },
    );
  }

  private ensureModuleWorkflowStatuses(value: unknown): Record<string, string> {
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      return value as Record<string, string>;
    }
    return {
      vocabulary_kanji: 'not_started',
      grammar: 'not_started',
      quiz: 'not_started',
      audio: 'not_started',
    };
  }

  private async ensureDevOwnerUser(ownerId: string) {
    await this.prisma.user.upsert({
      where: { id: ownerId },
      update: {},
      create: { id: ownerId },
    });
  }

  private mapFullDraft(draft: any): StoryDraftResponseDto {
    const etag = this.etagFromVersion(draft.version);
    const createdAt = draft.createdAt.toISOString();
    const updatedAt = draft.updatedAt.toISOString();

    const sentences = (draft.sentences ?? [])
      .slice()
      .sort((a: any, b: any) => a.order - b.order)
      .map((s: any) => ({
        ...(s.content ?? {}),
        orderIndex:
          typeof s.content?.orderIndex === 'number' ? s.content.orderIndex : s.order,
      }));

    const vocabularyEntries = (draft.vocabEntries ?? [])
      .slice()
      .sort((a: any, b: any) => a.order - b.order)
      .map((e: any) => ({ ...(e.content ?? {}) }));

    const grammarEntries = (draft.grammarEntries ?? [])
      .slice()
      .sort((a: any, b: any) => a.order - b.order)
      .map((e: any) => ({ ...(e.content ?? {}) }));

    const quizEntries = (draft.quizEntries ?? [])
      .slice()
      .sort((a: any, b: any) => a.order - b.order)
      .map((e: any) => ({ ...(e.content ?? {}) }));

    const storyAudioRow = (draft.audios ?? []).find(
      (a: any) => a.kind === 'storyAudio',
    );

    return {
      draftId: draft.id,
      ownerId: draft.ownerId,
      schemaVersion: draft.schemaVersion,
      etag,
      createdAt,
      updatedAt,
      basics: {
        storyId: draft.id,
        ownerId: draft.ownerId,
        title: draft.title ?? '',
        category: draft.category ?? '',
        level: draft.level ?? '',
        description: draft.description ?? '',
        promptSourceNote: draft.promptSourceNote ?? '',
        targetDurationBandKey: draft.targetDurationBandKey ?? null,
        coverImageUrl: draft.coverImageUrl ?? null,
        createdAt,
        updatedAt,
      },
      sentences,
      vocabularyKanji: { entries: vocabularyEntries },
      grammar: { entries: grammarEntries },
      quiz: { entries: quizEntries },
      audio: { storyAudio: storyAudioRow ? storyAudioRow.content : null },
      publishState: draft.publishState as PublishState,
      moduleWorkflowStatuses: this.ensureModuleWorkflowStatuses(
        draft.moduleWorkflowStatuses,
      ),
      publishedMonoId: draft.publishedMonoId ?? null,
      readingOnlyPublishedAt: draft.readingOnlyPublishedAt
        ? draft.readingOnlyPublishedAt.toISOString()
        : null,
      fullLearnPublishedAt: draft.fullLearnPublishedAt
        ? draft.fullLearnPublishedAt.toISOString()
        : null,
    };
  }

  async createDraft(req: CreateStoryDraftRequestDto): Promise<StoryDraftResponseDto> {
    const ownerId = this.getDevOwnerId();
    await this.ensureDevOwnerUser(ownerId);

    const draftId = req.draftId ?? crypto.randomUUID();
    const basics = req.basics ?? {};

    const created = await this.prisma.storyDraft.create({
      data: {
        id: draftId,
        ownerId,
        schemaVersion: req.schemaVersion ?? 1,
        publishState: 'draft',
        hasUnpublishedCoreChanges: false,
        title: basics.title ?? '',
        category: basics.category ?? '',
        level: basics.level ?? '',
        description: basics.description ?? '',
        promptSourceNote: basics.promptSourceNote ?? '',
        targetDurationBandKey: basics.targetDurationBandKey ?? null,
        coverImageUrl: basics.coverImageUrl ?? null,
        moduleWorkflowStatuses: this.ensureModuleWorkflowStatuses(null),
      },
      include: {
        sentences: true,
        vocabEntries: true,
        grammarEntries: true,
        quizEntries: true,
        audios: true,
      },
    });

    return this.mapFullDraft(created);
  }

  async deleteDraft(draftId: string): Promise<void> {
    const ownerId = this.getDevOwnerId();
    const result = await this.prisma.storyDraft.deleteMany({
      where: { id: draftId, ownerId },
    });
    if (result.count === 0) {
      throw apiError(HttpStatus.NOT_FOUND, 'draft_not_found', 'Draft not found');
    }
  }

  async getDraftById(draftId: string): Promise<StoryDraftResponseDto> {
    const ownerId = this.getDevOwnerId();
    const draft = await this.prisma.storyDraft.findFirst({
      where: { id: draftId, ownerId },
      include: {
        sentences: true,
        vocabEntries: true,
        grammarEntries: true,
        quizEntries: true,
        audios: true,
      },
    });

    if (!draft) {
      throw apiError(HttpStatus.NOT_FOUND, 'draft_not_found', 'Draft not found');
    }

    return this.mapFullDraft(draft);
  }

  async updateDraft(
    draftId: string,
    body: StoryDraftWriteDto,
    ifMatch?: string,
  ): Promise<StoryDraftResponseDto> {
    const ownerId = this.getDevOwnerId();
    const requiredIfMatch = this.requireIfMatch(ifMatch);

    if (body.basics.storyId !== draftId) {
      throw apiError(
        HttpStatus.BAD_REQUEST,
        'draft_id_mismatch',
        'basics.storyId must equal path draftId',
      );
    }

    if (body.basics.ownerId && body.basics.ownerId !== ownerId) {
      throw apiError(
        HttpStatus.FORBIDDEN,
        'owner_mismatch',
        'ownerId does not match authenticated user',
      );
    }

    const sentences = body.sentences ?? [];
    const vocab = body.vocabularyKanji?.entries ?? [];
    const grammar = body.grammar?.entries ?? [];
    const quiz = body.quiz?.entries ?? [];
    const storyAudio = body.audio?.storyAudio ?? null;

    const updated = await this.prisma.$transaction(async (tx) => {
      const current = await tx.storyDraft.findFirst({
        where: { id: draftId, ownerId },
        select: { version: true, publishState: true },
      });
      if (!current) {
        throw apiError(HttpStatus.NOT_FOUND, 'draft_not_found', 'Draft not found');
      }

      const becomesPublishedRelated =
        current.publishState !== PublishState.draft ||
        body.publishState !== PublishState.draft;

      const currentEtag = this.etagFromVersion(current.version);
      if (requiredIfMatch !== currentEtag) {
        this.throwConflict(current.version);
      }

      await tx.draftSentence.deleteMany({ where: { draftId } });
      await tx.draftVocabEntry.deleteMany({ where: { draftId } });
      await tx.draftGrammarEntry.deleteMany({ where: { draftId } });
      await tx.draftQuizEntry.deleteMany({ where: { draftId } });
      await tx.draftAudio.deleteMany({ where: { draftId } });

      if (sentences.length > 0) {
        await tx.draftSentence.createMany({
          data: sentences.map((s, idx) => {
            const orderIndex = (s as any).orderIndex;
            const order = typeof orderIndex === 'number' ? orderIndex : idx;
            return { draftId, order, content: s as Prisma.InputJsonValue };
          }),
        });
      }

      if (vocab.length > 0) {
        await tx.draftVocabEntry.createMany({
          data: vocab.map((e, idx) => ({
            draftId,
            order: idx,
            content: e as Prisma.InputJsonValue,
          })),
        });
      }

      if (grammar.length > 0) {
        await tx.draftGrammarEntry.createMany({
          data: grammar.map((e, idx) => ({
            draftId,
            order: idx,
            content: e as Prisma.InputJsonValue,
          })),
        });
      }

      if (quiz.length > 0) {
        await tx.draftQuizEntry.createMany({
          data: quiz.map((e, idx) => ({
            draftId,
            order: idx,
            content: e as Prisma.InputJsonValue,
          })),
        });
      }

      if (storyAudio) {
        await tx.draftAudio.create({
          data: {
            draftId,
            kind: 'storyAudio',
            content: storyAudio as Prisma.InputJsonValue,
          },
        });
      }

      const updateResult = await tx.storyDraft.updateMany({
        where: { id: draftId, ownerId, version: current.version },
        data: {
          schemaVersion: body.schemaVersion ?? 1,
          publishState: body.publishState,
          hasUnpublishedCoreChanges: becomesPublishedRelated,
          title: body.basics.title ?? '',
          category: body.basics.category ?? '',
          level: body.basics.level ?? '',
          description: body.basics.description ?? '',
          promptSourceNote: body.basics.promptSourceNote ?? '',
          targetDurationBandKey: body.basics.targetDurationBandKey ?? null,
          coverImageUrl: body.basics.coverImageUrl ?? null,
          moduleWorkflowStatuses: this.ensureModuleWorkflowStatuses(
            body.moduleWorkflowStatuses,
          ),
          version: { increment: 1 },
        },
      });

      if (updateResult.count !== 1) {
        const latest = await tx.storyDraft.findFirst({
          where: { id: draftId, ownerId },
          select: { version: true },
        });
        if (!latest) {
          throw apiError(HttpStatus.NOT_FOUND, 'draft_not_found', 'Draft not found');
        }
        this.throwConflict(latest.version);
      }

      const reloaded = await tx.storyDraft.findFirst({
        where: { id: draftId, ownerId },
        include: {
          sentences: true,
          vocabEntries: true,
          grammarEntries: true,
          quizEntries: true,
          audios: true,
        },
      });

      if (!reloaded) {
        throw apiError(HttpStatus.NOT_FOUND, 'draft_not_found', 'Draft not found');
      }
      return reloaded;
    });

    return this.mapFullDraft(updated);
  }

  async listDrafts(q: ListStoryDraftsQuery): Promise<StoryDraftListEnvelopeDto> {
    const ownerId = this.getDevOwnerId();
    await this.ensureDevOwnerUser(ownerId);

    const limitNum = q.limit ? Number(q.limit) : LIST_DEFAULT_LIMIT;
    const takeBase = Number.isFinite(limitNum)
      ? Math.min(Math.max(limitNum, 1), LIST_MAX_LIMIT)
      : LIST_DEFAULT_LIMIT;

    const sortRaw = q.sort?.trim().toLowerCase() ?? 'latest';
    const descending = sortRaw !== 'oldest';

    let cursorPayload: ListCursorPayload | null = null;
    if (q.cursor?.trim()) {
      cursorPayload = this.decodeListCursor(q.cursor.trim());
    }

    let updatedAfterDate: Date | undefined;
    if (q.updatedAfter?.trim()) {
      const d = new Date(q.updatedAfter.trim());
      if (Number.isNaN(d.getTime())) {
        throw apiError(
          HttpStatus.BAD_REQUEST,
          'invalid_query',
          'updatedAfter must be a valid ISO-8601 timestamp',
        );
      }
      updatedAfterDate = d;
    }

    const publishFilter = this.resolvePublishStateFilter(q.publishState, q.status);

    const cursorClause = this.buildListCursorWhere(cursorPayload, descending);

    const parts: Prisma.StoryDraftWhereInput[] = [{ ownerId }];
    if (publishFilter !== undefined) {
      parts.push({ publishState: publishFilter });
    }
    if (updatedAfterDate) {
      parts.push({ updatedAt: { gt: updatedAfterDate } });
    }
    if (cursorClause) {
      parts.push(cursorClause);
    }

    const where: Prisma.StoryDraftWhereInput =
      parts.length === 1 ? parts[0]! : { AND: parts };

    const rows = await this.prisma.storyDraft.findMany({
      where,
      orderBy: descending
        ? [{ updatedAt: 'desc' }, { id: 'desc' }]
        : [{ updatedAt: 'asc' }, { id: 'asc' }],
      take: takeBase + 1,
      select: {
        id: true,
        title: true,
        category: true,
        level: true,
        description: true,
        coverImageUrl: true,
        publishState: true,
        updatedAt: true,
        targetDurationBandKey: true,
        moduleWorkflowStatuses: true,
        hasUnpublishedCoreChanges: true,
        _count: { select: { sentences: true } },
      },
    });

    const hasMore = rows.length > takeBase;
    const page = hasMore ? rows.slice(0, takeBase) : rows;
    const last = page.length > 0 ? page[page.length - 1]! : null;
    const nextCursor =
      hasMore && last ? this.encodeListCursor(last.updatedAt, last.id) : null;

    return {
      items: page.map((d) => this.mapDraftListSummary(d)),
      nextCursor,
      hasMore,
      totalCount: null,
    };
  }

  private encodeListCursor(updatedAt: Date, id: string): string {
    const payload: ListCursorPayload = { u: updatedAt.toISOString(), i: id };
    return Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
  }

  private decodeListCursor(raw: string): ListCursorPayload {
    try {
      const json = Buffer.from(raw, 'base64url').toString('utf8');
      const v = JSON.parse(json) as ListCursorPayload;
      if (typeof v?.u === 'string' && typeof v?.i === 'string' && v.i.trim()) {
        return { u: v.u, i: v.i.trim() };
      }
    } catch {
      // fallthrough
    }
    throw apiError(HttpStatus.BAD_REQUEST, 'invalid_cursor', 'cursor could not be decoded');
  }

  private resolvePublishStateFilter(
    publishStateRaw?: string,
    statusRaw?: string,
  ): PublishState | { in: PublishState[] } | undefined {
    const ps = publishStateRaw?.trim();
    if (ps) {
      const normalized = ps.toLowerCase();
      if (normalized === 'draft') return PublishState.draft;
      if (normalized === 'reading_only_published') return PublishState.reading_only_published;
      if (normalized === 'full_learn_published') return PublishState.full_learn_published;
    }

    const st = statusRaw?.trim().toLowerCase();
    if (st === 'draft') return PublishState.draft;
    if (st === 'published') {
      return { in: [PublishState.reading_only_published, PublishState.full_learn_published] };
    }
    return undefined;
  }

  private buildListCursorWhere(
    cursor: ListCursorPayload | null,
    descending: boolean,
  ): Prisma.StoryDraftWhereInput | undefined {
    if (!cursor) return undefined;
    const u = new Date(cursor.u);
    const id = cursor.i;
    if (Number.isNaN(u.getTime())) {
      throw apiError(HttpStatus.BAD_REQUEST, 'invalid_cursor', 'cursor timestamp invalid');
    }
    if (descending) {
      return {
        OR: [{ updatedAt: { lt: u } }, { AND: [{ updatedAt: u }, { id: { lt: id } }] }],
      };
    }
    return {
      OR: [{ updatedAt: { gt: u } }, { AND: [{ updatedAt: u }, { id: { gt: id } }] }],
    };
  }

  private truncatePreview(text: string): string {
    const t = text.trim();
    if (t.length <= PREVIEW_MAX_CHARS) return t;
    return `${t.slice(0, PREVIEW_MAX_CHARS)}…`;
  }

  /**
   * Cheap 0–100 estimate from list-row scalars only (no sentence-body reads).
   * — 35%: five basics slots (title, category, level, description, targetDurationBandKey).
   * — 25%: sentence volume (full contribution at ≥5 sentences).
   * — 40%: four learn modules (completed=10 pts each, in_progress=5).
   */
  private listSummaryCompletionPercent(args: {
    title: string | null;
    category: string | null;
    level: string | null;
    description: string | null;
    targetDurationBandKey: string | null;
    sentenceCount: number;
    moduleStatuses: Record<string, string>;
  }): number {
    const slots = [
      args.title?.trim(),
      args.category?.trim(),
      args.level?.trim(),
      args.description?.trim(),
      args.targetDurationBandKey?.trim(),
    ];
    const filledBasics = slots.filter((s) => !!s && s.length > 0).length;
    const basicsScore = (filledBasics / 5) * 35;
    const sentenceScore = Math.min(args.sentenceCount / 5, 1) * 25;
    const keys = ['vocabulary_kanji', 'grammar', 'quiz', 'audio'];
    let modulePoints = 0;
    for (const k of keys) {
      const st = (args.moduleStatuses[k] ?? 'not_started').toLowerCase();
      if (st === 'completed') modulePoints += 10;
      else if (st === 'in_progress') modulePoints += 5;
    }
    const raw = basicsScore + sentenceScore + modulePoints;
    return Math.max(0, Math.min(100, Math.round(raw)));
  }

  private learnModeEnabledFromStatuses(statuses: Record<string, string>): boolean {
    return Object.values(statuses).some((s) => (s ?? '').toLowerCase() !== 'not_started');
  }

  /** First module in editorial order that is `in_progress`; otherwise null. */
  private lastEditingStepFromModuleStatuses(statuses: Record<string, string>): string | null {
    const order = ['vocabulary_kanji', 'grammar', 'quiz', 'audio'] as const;
    for (const k of order) {
      const st = (statuses[k] ?? 'not_started').toLowerCase();
      if (st === 'in_progress') return k;
    }
    return null;
  }

  private listSummaryWorkspaceState(
    ps: PublishState,
    hasUnpublishedCoreChanges: boolean,
  ): DraftListWorkspaceState {
    if (ps === PublishState.draft) return 'draft';
    return hasUnpublishedCoreChanges ? 'editing' : 'synced';
  }

  private mapDraftListSummary(d: {
    id: string;
    title: string | null;
    category: string | null;
    level: string | null;
    description: string | null;
    coverImageUrl: string | null;
    publishState: PublishState;
    updatedAt: Date;
    targetDurationBandKey: string | null;
    moduleWorkflowStatuses: unknown;
    hasUnpublishedCoreChanges: boolean;
    _count: { sentences: number };
  }): DraftListSummaryResponseDto {
    const ps = d.publishState;
    const status = ps === PublishState.draft ? 'draft' : 'published';
    const publishType =
      ps === PublishState.draft
        ? 'draft'
        : ps === PublishState.reading_only_published
          ? 'read_only'
          : 'full_learn';

    const moduleStatuses: Record<string, string> = {
      ...this.ensureModuleWorkflowStatuses(null),
      ...(typeof d.moduleWorkflowStatuses === 'object' &&
      d.moduleWorkflowStatuses !== null &&
      !Array.isArray(d.moduleWorkflowStatuses)
        ? (d.moduleWorkflowStatuses as Record<string, string>)
        : {}),
    };
    const completionPercent = this.listSummaryCompletionPercent({
      title: d.title,
      category: d.category,
      level: d.level,
      description: d.description,
      targetDurationBandKey: d.targetDurationBandKey,
      sentenceCount: d._count.sentences,
      moduleStatuses,
    });

    const durationKey = d.targetDurationBandKey?.trim() ? d.targetDurationBandKey.trim() : null;
    const dirty = d.hasUnpublishedCoreChanges;

    return {
      draftId: d.id,
      title: d.title?.trim() ? d.title.trim() : 'Untitled draft',
      coverImageUrl: d.coverImageUrl ?? null,
      level: (d.level ?? '').trim().toLowerCase(),
      category: (d.category ?? '').trim().toLowerCase(),
      status,
      publishState: ps,
      processingStatus: null,
      updatedAt: d.updatedAt.toISOString(),
      sentenceCount: d._count.sentences,
      publishType,
      previewText: this.truncatePreview(d.description ?? ''),
      hasUnpublishedCoreChanges: dirty,
      targetDurationBandKey: durationKey,
      moduleWorkflowStatuses: moduleStatuses,
      learnModeEnabled: this.learnModeEnabledFromStatuses(moduleStatuses),
      completionPercent,
      workspaceState: this.listSummaryWorkspaceState(ps, dirty),
      lastEditingStep: this.lastEditingStepFromModuleStatuses(moduleStatuses),
    };
  }

  private sentenceHasJapaneseText(sentenceContent: unknown): boolean {
    if (!sentenceContent || typeof sentenceContent !== 'object') return false;
    const c = sentenceContent as Record<string, unknown>;
    const candidates = [
      c.japanese,
      c.japaneseText,
      c.jp,
      c.textJa,
      c.text,
      c.value,
    ];
    return candidates.some((v) => typeof v === 'string' && v.trim().length > 0);
  }

  private getReadOnlyReadinessUnmet(draft: any): string[] {
    const unmet: string[] = [];
    if (!draft.title?.trim()) unmet.push('title_empty');
    if (!draft.category?.trim()) unmet.push('category_empty');
    if (!draft.level?.trim()) unmet.push('level_empty');
    if (!draft.description?.trim()) unmet.push('description_empty');
    if (!draft.targetDurationBandKey?.trim())
      unmet.push('target_duration_band_missing');

    const sentences = (draft.sentences ?? []) as Array<{ content: unknown }>;
    const hasValidSentence = sentences.some((s) =>
      this.sentenceHasJapaneseText(s.content),
    );
    if (!hasValidSentence) unmet.push('no_valid_sentence');
    return unmet;
  }

  private getFullLearnReadinessUnmet(draft: any): string[] {
    const unmet = this.getReadOnlyReadinessUnmet(draft);
    const statuses = this.ensureModuleWorkflowStatuses(draft.moduleWorkflowStatuses);
    const requiredKeys = ['vocabulary_kanji', 'grammar', 'quiz', 'audio'];
    for (const k of requiredKeys) {
      if (statuses[k] !== 'completed') unmet.push(`module_${k}_not_completed`);
    }
    return unmet;
  }

  async publishReadOnly(draftId: string, ifMatch?: string) {
    const ownerId = this.getDevOwnerId();
    const requiredIfMatch = this.requireIfMatch(ifMatch);

    const now = new Date();

    const updated = await this.prisma.$transaction(async (tx) => {
      const draft = await tx.storyDraft.findFirst({
        where: { id: draftId, ownerId },
        include: {
          sentences: true,
          publishedMono: true,
        },
      });

      if (!draft) {
        throw apiError(HttpStatus.NOT_FOUND, 'draft_not_found', 'Draft not found');
      }

      const currentEtag = this.etagFromVersion(draft.version);
      if (requiredIfMatch !== currentEtag) {
        this.throwConflict(draft.version);
      }

      const unmet = this.getReadOnlyReadinessUnmet(draft);
      if (unmet.length > 0) {
        throw apiError(
          HttpStatus.UNPROCESSABLE_ENTITY,
          'unprocessable_entity',
          'Read-only publish requirements not met',
          { unmet },
        );
      }

      let publishedMonoId = draft.publishedMonoId;
      if (!publishedMonoId) {
        const mono = await tx.publishedMono.create({
          data: {
            ownerId,
            title: draft.title ?? '',
            category: draft.category ?? '',
            level: draft.level ?? '',
            description: draft.description ?? '',
            content: { sourceDraftId: draft.id },
          },
          select: { id: true },
        });
        publishedMonoId = mono.id;
      }

      // V1 update path:
      // - first publish creates a PublishedMono
      // - subsequent "publish read-only" updates the SAME PublishedMono (reuses id)
      // so "Update Read Only" is backend-safe and does not create a new logical publish.
      await tx.publishedMono.update({
        where: { id: publishedMonoId },
        data: {
          title: draft.title ?? '',
          category: draft.category ?? '',
          level: draft.level ?? '',
          description: draft.description ?? '',
          content: {
            sourceDraftId: draft.id,
            publishKind: 'read_only_v1',
            updatedAt: now.toISOString(),
            core: {
              title: draft.title ?? '',
              category: draft.category ?? '',
              level: draft.level ?? '',
              description: draft.description ?? '',
              targetDurationBandKey: draft.targetDurationBandKey,
              coverImageUrl: draft.coverImageUrl,
              sentences: (draft.sentences ?? [])
                .slice()
                .sort((a, b) => a.order - b.order)
                .map((s) => ({
                  order: s.order,
                  content: s.content,
                })),
            },
          },
        },
      });

      const updateResult = await tx.storyDraft.updateMany({
        where: { id: draftId, ownerId, version: draft.version },
        data: {
          publishState: 'reading_only_published',
          publishedMonoId,
          readingOnlyPublishedAt: draft.readingOnlyPublishedAt ?? now,
          hasUnpublishedCoreChanges: false,
          version: { increment: 1 },
        },
      });

      if (updateResult.count !== 1) {
        const latest = await tx.storyDraft.findFirst({
          where: { id: draftId, ownerId },
          select: { version: true },
        });
        if (!latest) {
          throw apiError(HttpStatus.NOT_FOUND, 'draft_not_found', 'Draft not found');
        }
        this.throwConflict(latest.version);
      }

      const reloaded = await tx.storyDraft.findFirst({
        where: { id: draftId, ownerId },
        include: {
          sentences: true,
          vocabEntries: true,
          grammarEntries: true,
          quizEntries: true,
          audios: true,
        },
      });
      if (!reloaded) {
        throw apiError(HttpStatus.NOT_FOUND, 'draft_not_found', 'Draft not found');
      }
      return reloaded;
    });

    return this.mapFullDraft(updated);
  }

  async publishFullLearn(draftId: string, ifMatch?: string) {
    const ownerId = this.getDevOwnerId();
    const requiredIfMatch = this.requireIfMatch(ifMatch);

    const now = new Date();

    const updated = await this.prisma.$transaction(async (tx) => {
      const draft = await tx.storyDraft.findFirst({
        where: { id: draftId, ownerId },
        include: {
          sentences: true,
          vocabEntries: true,
          grammarEntries: true,
          quizEntries: true,
          audios: true,
        },
      });

      if (!draft) {
        throw apiError(HttpStatus.NOT_FOUND, 'draft_not_found', 'Draft not found');
      }

      const currentEtag = this.etagFromVersion(draft.version);
      if (requiredIfMatch !== currentEtag) {
        this.throwConflict(draft.version);
      }

      const unmet = this.getFullLearnReadinessUnmet(draft);
      if (unmet.length > 0) {
        throw apiError(
          HttpStatus.UNPROCESSABLE_ENTITY,
          'unprocessable_entity',
          'Full-learn publish requirements not met',
          { unmet },
        );
      }

      if (!draft.publishedMonoId) {
        throw apiError(
          HttpStatus.UNPROCESSABLE_ENTITY,
          'unprocessable_entity',
          'Full-learn publish requires an existing publishedMonoId',
          { unmet: ['published_mono_missing'] },
        );
      }

      const updateResult = await tx.storyDraft.updateMany({
        where: { id: draftId, ownerId, version: draft.version },
        data: {
          publishState: 'full_learn_published',
          fullLearnPublishedAt: draft.fullLearnPublishedAt ?? now,
          hasUnpublishedCoreChanges: false,
          version: { increment: 1 },
        },
      });

      if (updateResult.count !== 1) {
        const latest = await tx.storyDraft.findFirst({
          where: { id: draftId, ownerId },
          select: { version: true },
        });
        if (!latest) {
          throw apiError(HttpStatus.NOT_FOUND, 'draft_not_found', 'Draft not found');
        }
        this.throwConflict(latest.version);
      }

      const reloaded = await tx.storyDraft.findFirst({
        where: { id: draftId, ownerId },
        include: {
          sentences: true,
          vocabEntries: true,
          grammarEntries: true,
          quizEntries: true,
          audios: true,
        },
      });

      if (!reloaded) {
        throw apiError(HttpStatus.NOT_FOUND, 'draft_not_found', 'Draft not found');
      }

      // Mark PublishedMono as Full Learn. Learn module snapshots are not written here yet
      // (V1: Flutter must not render fake learn data; [content.learn] is optional for later).
      const publishedMonoId = reloaded.publishedMonoId;
      if (publishedMonoId) {
        const pm = await tx.publishedMono.findUnique({ where: { id: publishedMonoId } });
        if (pm) {
          const prev = (pm.content ?? {}) as Record<string, unknown>;
          await tx.publishedMono.update({
            where: { id: publishedMonoId },
            data: {
              content: {
                ...prev,
                sourceDraftId: reloaded.id,
                publishKind: 'full_learn_v1',
                updatedAt: now.toISOString(),
              } as any,
            },
          });
        }
      }

      return reloaded;
    });

    return this.mapFullDraft(updated);
  }
}

