import { HttpStatus, Injectable, Logger } from '@nestjs/common';
import { Prisma, PublishState } from '@prisma/client';
import {
  normalizeStoryDraftTextFields,
  validateStoryDescription,
  validateStoryTitle,
} from '../../common/validation/story-validation';
import { ValidationMode } from '../../common/validation/validation-mode';
import { assertNoBlockingValidationIssues } from '../../common/validation/validation-exception';
import { combine, type ValidationResult } from '../../common/validation/validation-result';
import {
  storyPublishInputFromDraftRow,
  validateStoryPublishInput,
} from '../../common/validation/publish-validation';
import {
  assertCanRevealOnePublishedTabMono,
  isOwnerPublishedMonoTabVisible,
  logPublishedTabPublishQuotaIfDev,
} from '../published-monos/published-mono-published-tab-quota';
import {
  resolvePublishedMonoIdForReadOnlyPublish,
  type PublishedMonoReadOnlyPublishScope,
} from '../published-monos/published-mono-slot-guards';
import { PrismaService } from '../prisma/prisma.service';
import { FREE_TIER_QUOTA_KEYS, FREE_TIER_QUOTAS } from '../../common/limits/free-tier-quotas';
import { QuotaExceededException } from '../../common/limits/quota-exceeded.exception';
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

/** GET /v1/story-drafts — aligns with docs/NIMON_API_QUERY_CONTRACT.md §3 (workspace). */
/** Default matches pre-pagination remote list (Flutter `listDraftIds()` omits `limit`). */
const LIST_DEFAULT_LIMIT = 50;
const LIST_MAX_LIMIT = 50;
const PREVIEW_MAX_CHARS = 200;

type ListCursorPayload = { u: string; i: string };

@Injectable()
export class StoryDraftsService {
  private readonly logger = new Logger(StoryDraftsService.name);

  constructor(private readonly prisma: PrismaService) {}

  private isM17e4DiagEnabled(): boolean {
    return process.env.NODE_ENV !== 'production';
  }

  private jsonSourceDraftId(content: unknown): string | null {
    const c = content as Record<string, unknown> | null | undefined;
    const raw = c?.sourceDraftId;
    if (typeof raw !== 'string' || !raw.trim()) {
      return null;
    }
    return raw.trim();
  }

  private logM17e4EditStage(params: {
    trigger: 'getDraftById' | 'updateDraft' | 'createDraft';
    ownerId: string;
    workspaceDraftId: string;
    publishedMonoIdFromDraft: string | null;
    draftPublishState: PublishState;
    draftHasDirty: boolean;
    publishedMonoTrashedAtIso: string | null;
    publishedMonoSourceDraftId: string | null;
    createdDraftId: string | null;
  }): void {
    if (!this.isM17e4DiagEnabled()) {
      return;
    }
    const p = params;
    this.logger.log(
      `[M17E-4 edit-stage] trigger=${p.trigger} ownerId=${p.ownerId} publishedMonoId=${p.publishedMonoIdFromDraft ?? 'null'} sourceDraftId=${p.publishedMonoSourceDraftId ?? 'null'} workspaceDraftId=${p.workspaceDraftId} createdDraftId=${p.createdDraftId ?? 'null'} draft.publishState=${p.draftPublishState} draft.publishedMonoId=${p.publishedMonoIdFromDraft ?? 'null'} draft.sourcePublishedMonoId=n/a draft.hasUnpublishedCoreChanges=${p.draftHasDirty} publishedMono.trashedAt=${p.publishedMonoTrashedAtIso ?? 'null'} publishedMonoRowHasUnpublishedCoreChanges=n/a visibility=PUBLISHED_MONO_CATALOG_VISIBLE`,
    );
  }

  private logM17e4PublishEntry(params: {
    methodName: string;
    ownerId: string;
    draftId: string;
    publishState: PublishState;
    publishedMonoIdOnDraft: string | null;
    hasDirty: boolean;
    isFirstPublish: boolean;
    resolutionVia: string;
  }): void {
    if (!this.isM17e4DiagEnabled()) {
      return;
    }
    const x = params;
    this.logger.log(
      `[M17E-4 publish-entry] methodName=${x.methodName} ownerId=${x.ownerId} draftId=${x.draftId} draft.publishState=${x.publishState} draft.publishedMonoId=${x.publishedMonoIdOnDraft ?? 'null'} draft.hasUnpublishedCoreChanges=${x.hasDirty} isFirstPublish=${x.isFirstPublish ? 'yes' : 'no'} resolutionVia=${x.resolutionVia}`,
    );
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

  /** Safe shallow copy for Prisma Json row.content — avoids mutating stored objects. */
  private shallowJsonObjectCopy(content: unknown): Record<string, unknown> {
    if (content == null) {
      return {};
    }
    if (typeof content !== 'object' || Array.isArray(content)) {
      return {};
    }
    return { ...(content as Record<string, unknown>) };
  }

  /**
   * Draft PUT uses the **array order** of `sentences` as canonical display order.
   * DB column `DraftSentence.order` is always `0..n-1` by index (unique with `draftId`).
   * Client `orderIndex` is not trusted for insertion (duplicates caused P2002).
   */
  private logDuplicateIncomingSentenceOrderIndexes(
    draftId: string,
    sentences: unknown[],
  ): void {
    const seen = new Set<number>();
    const dup = new Set<number>();
    for (const raw of sentences) {
      if (raw == null || typeof raw !== 'object' || Array.isArray(raw)) continue;
      const oi = (raw as Record<string, unknown>).orderIndex;
      if (typeof oi !== 'number' || !Number.isFinite(oi)) continue;
      const k = Math.trunc(oi);
      if (seen.has(k)) dup.add(k);
      else seen.add(k);
    }
    if (dup.size === 0) return;
    const sorted = [...dup].sort((a, b) => a - b);
    this.logger.warn(
      `draft_sentences: duplicate orderIndex in PUT payload (ignored for DB order); draftId=${draftId} duplicateOrderIndex=${sorted.join(',')}`,
    );
  }

  /**
   * PublishedMono `content.core` — reader + feed use this (not only `content.learn`).
   * Sorted by `DraftSentence.order`; each row `{ order, content }` preserves the JSON blob
   * (japaneseText, furiganaSpans, meanings, etc.).
   */
  private buildPublishedCorePayloadFromDraft(draft: any): Record<string, unknown> {
    return {
      title: draft.title ?? '',
      category: draft.category ?? '',
      level: draft.level ?? '',
      description: draft.description ?? '',
      targetDurationBandKey: draft.targetDurationBandKey,
      coverImageUrl: draft.coverImageUrl,
      sentences: (draft.sentences ?? [])
        .slice()
        .sort((a: any, b: any) => a.order - b.order)
        .map((s: any) => ({
          order: s.order,
          content: s.content,
        })),
    };
  }

  /**
   * PublishedMono `content.learn` snapshot — same ordering as mapFullDraft learn layers.
   */
  private buildLearnSnapshotFromDraft(draft: any): Record<string, unknown> {
    const vocabularyEntries = (draft.vocabEntries ?? [])
      .slice()
      .sort((a: any, b: any) => a.order - b.order)
      .map((e: any) => this.shallowJsonObjectCopy(e.content));

    const grammarEntries = (draft.grammarEntries ?? [])
      .slice()
      .sort((a: any, b: any) => a.order - b.order)
      .map((e: any) => this.shallowJsonObjectCopy(e.content));

    const quizEntries = (draft.quizEntries ?? [])
      .slice()
      .sort((a: any, b: any) => a.order - b.order)
      .map((e: any) => this.shallowJsonObjectCopy(e.content));

    const storyAudioRow = (draft.audios ?? []).find(
      (a: any) => a.kind === 'storyAudio',
    );
    const storyAudio = storyAudioRow
      ? this.shallowJsonObjectCopy(storyAudioRow.content)
      : null;

    return {
      schemaVersion: 1,
      vocabularyKanji: { entries: vocabularyEntries },
      grammar: { entries: grammarEntries },
      quiz: { entries: quizEntries },
      audio: { storyAudio },
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

  async createDraft(
    ownerId: string,
    req: CreateStoryDraftRequestDto,
  ): Promise<StoryDraftResponseDto> {
    await this.ensureDevOwnerUser(ownerId);

    const draftId = req.draftId ?? crypto.randomUUID();
    const basicsRaw = req.basics ?? {};
    const normalizedText = normalizeStoryDraftTextFields({
      title: basicsRaw.title as string | null | undefined,
      description: basicsRaw.description as string | null | undefined,
    });
    const basics = { ...basicsRaw, ...normalizedText };

    const draftParts: ValidationResult[] = [];
    if (Object.prototype.hasOwnProperty.call(basicsRaw, 'title')) {
      draftParts.push(
        validateStoryTitle(
          basicsRaw.title as string | null | undefined,
          ValidationMode.Draft,
        ),
      );
    }
    if (Object.prototype.hasOwnProperty.call(basicsRaw, 'description')) {
      draftParts.push(
        validateStoryDescription(
          basicsRaw.description as string | null | undefined,
          ValidationMode.Draft,
        ),
      );
    }
    if (draftParts.length > 0) {
      assertNoBlockingValidationIssues(combine(...draftParts));
    }

    const draftCount = await this.prisma.storyDraft.count({ where: { ownerId } });
    if (draftCount >= FREE_TIER_QUOTAS.draftStories) {
      throw new QuotaExceededException(
        FREE_TIER_QUOTA_KEYS.draftStories,
        FREE_TIER_QUOTAS.draftStories,
        draftCount,
      );
    }

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

    this.logM17e4EditStage({
      trigger: 'createDraft',
      ownerId,
      workspaceDraftId: created.id,
      publishedMonoIdFromDraft: null,
      draftPublishState: created.publishState,
      draftHasDirty: created.hasUnpublishedCoreChanges,
      publishedMonoTrashedAtIso: null,
      publishedMonoSourceDraftId: null,
      createdDraftId: created.id,
    });

    return this.mapFullDraft(created);
  }

  async deleteDraft(ownerId: string, draftId: string): Promise<void> {
    const existing = await this.prisma.storyDraft.findFirst({
      where: { id: draftId, ownerId },
      select: {
        publishedMonoId: true,
        hasUnpublishedCoreChanges: true,
        publishState: true,
      },
    });
    if (!existing) {
      throw apiError(HttpStatus.NOT_FOUND, 'draft_not_found', 'Draft not found');
    }
    const linkedId = existing.publishedMonoId?.trim();
    if (linkedId) {
      const pm = await this.prisma.publishedMono.findUnique({
        where: { id: linkedId },
        select: { trashedAt: true, ownerId: true },
      });
      if (pm && pm.trashedAt == null) {
        if (pm.ownerId !== ownerId) {
          throw apiError(HttpStatus.NOT_FOUND, 'draft_not_found', 'Draft not found');
        }
        const isPlainDraft = existing.publishState === PublishState.draft;
        if (isPlainDraft && !existing.hasUnpublishedCoreChanges) {
          throw apiError(
            HttpStatus.CONFLICT,
            'published_draft_must_be_trashed_first',
            'Move the published story to Trash before deleting this draft.',
          );
        }
        if (existing.hasUnpublishedCoreChanges) {
          // M20E: Cancel edit deletes the staging workspace row only; the PublishedMono
          // already exists. Do not apply Published-tab reveal quota (M17E-6).
          if (process.env.NODE_ENV !== 'production') {
            this.logger.log(
              `[M20E backend-edit-cancel] ownerId=${ownerId} draftId=${draftId} ` +
                `publishedMonoId=${linkedId} hasUnpublishedCoreChanges_before=${existing.hasUnpublishedCoreChanges} ` +
                `publishState_before=${existing.publishState} skipRevealQuota=true`,
            );
          }
        }
      }
    }

    const result = await this.prisma.storyDraft.deleteMany({
      where: { id: draftId, ownerId },
    });
    if (result.count === 0) {
      throw apiError(HttpStatus.NOT_FOUND, 'draft_not_found', 'Draft not found');
    }
    if (process.env.NODE_ENV !== 'production' && existing.hasUnpublishedCoreChanges) {
      this.logger.log(
        `[M20E backend-edit-cancel] ownerId=${ownerId} draftId=${draftId} ` +
          `publishedMonoId=${linkedId ?? 'null'} hasUnpublishedCoreChanges_after=deleted ` +
          `publishState_after=deleted publishedMonoExists=true responseStatus=204`,
      );
    }
  }

  async getDraftById(ownerId: string, draftId: string): Promise<StoryDraftResponseDto> {
    const draft = await this.prisma.storyDraft.findFirst({
      where: { id: draftId, ownerId },
      include: {
        sentences: true,
        vocabEntries: true,
        grammarEntries: true,
        quizEntries: true,
        audios: true,
        publishedMono: { select: { id: true, trashedAt: true, content: true } },
      },
    });

    if (!draft) {
      throw apiError(HttpStatus.NOT_FOUND, 'draft_not_found', 'Draft not found');
    }

    const pmRef = draft.publishedMonoId?.trim() || null;
    if (draft.publishState !== PublishState.draft || pmRef) {
      const pm = draft.publishedMono;
      this.logM17e4EditStage({
        trigger: 'getDraftById',
        ownerId,
        workspaceDraftId: draftId,
        publishedMonoIdFromDraft: pmRef,
        draftPublishState: draft.publishState,
        draftHasDirty: draft.hasUnpublishedCoreChanges,
        publishedMonoTrashedAtIso: pm?.trashedAt?.toISOString() ?? null,
        publishedMonoSourceDraftId: this.jsonSourceDraftId(pm?.content),
        createdDraftId: null,
      });
    }

    return this.mapFullDraft(draft);
  }

  async updateDraft(
    ownerId: string,
    draftId: string,
    body: StoryDraftWriteDto,
    ifMatch?: string,
  ): Promise<StoryDraftResponseDto> {
    const requiredIfMatch = this.requireIfMatch(ifMatch);

    const basicsRaw = body.basics ?? {};
    const normalizedBasics = normalizeStoryDraftTextFields({
      title: basicsRaw.title as string | null | undefined,
      description: basicsRaw.description as string | null | undefined,
    });
    const basics = {
      ...basicsRaw,
      ...normalizedBasics,
      ownerId,
      storyId: draftId,
    };

    const draftParts: ValidationResult[] = [];
    if (Object.prototype.hasOwnProperty.call(basicsRaw, 'title')) {
      draftParts.push(
        validateStoryTitle(
          basicsRaw.title as string | null | undefined,
          ValidationMode.Draft,
        ),
      );
    }
    if (Object.prototype.hasOwnProperty.call(basicsRaw, 'description')) {
      draftParts.push(
        validateStoryDescription(
          basicsRaw.description as string | null | undefined,
          ValidationMode.Draft,
        ),
      );
    }
    if (draftParts.length > 0) {
      assertNoBlockingValidationIssues(combine(...draftParts));
    }

    if (basics.storyId !== draftId) {
      throw apiError(
        HttpStatus.BAD_REQUEST,
        'draft_id_mismatch',
        'basics.storyId must equal path draftId',
      );
    }

    const sentences = body.sentences ?? [];
    this.logDuplicateIncomingSentenceOrderIndexes(draftId, sentences);
    const vocab = body.vocabularyKanji?.entries ?? [];
    const grammar = body.grammar?.entries ?? [];
    const quiz = body.quiz?.entries ?? [];
    const storyAudio = body.audio?.storyAudio ?? null;

    const updated = await this.prisma.$transaction(async (tx) => {
      const current = await tx.storyDraft.findFirst({
        where: { id: draftId, ownerId },
        select: { version: true, publishState: true, publishedMonoId: true },
      });
      if (!current) {
        throw apiError(HttpStatus.NOT_FOUND, 'draft_not_found', 'Draft not found');
      }

      const hasLinkedMono =
        current.publishedMonoId != null && String(current.publishedMonoId).trim() !== '';

      /** Staging edits on a published-linked draft must not demote publishState via PUT. */
      const nextPublishState = hasLinkedMono
        ? current.publishState
        : (body.publishState as PublishState);

      const becomesPublishedRelated =
        current.publishState !== PublishState.draft ||
        body.publishState !== PublishState.draft;

      /** Linked publishes: any core PUT marks workspace dirty; visibility hides catalog until republish. */
      const nextHasUnpublishedCoreChanges = hasLinkedMono ? true : becomesPublishedRelated;

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
            const base =
              s != null && typeof s === 'object' && !Array.isArray(s)
                ? (s as Record<string, unknown>)
                : {};
            const content = { ...base, orderIndex: idx } as Prisma.InputJsonValue;
            return { draftId, order: idx, content };
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
          publishState: nextPublishState,
          hasUnpublishedCoreChanges: nextHasUnpublishedCoreChanges,
          title: basics.title ?? '',
          category: basics.category ?? '',
          level: basics.level ?? '',
          description: basics.description ?? '',
          promptSourceNote: basics.promptSourceNote ?? '',
          targetDurationBandKey: basics.targetDurationBandKey ?? null,
          coverImageUrl: basics.coverImageUrl ?? null,
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
          publishedMono: { select: { id: true, trashedAt: true, content: true } },
        },
      });

      if (!reloaded) {
        throw apiError(HttpStatus.NOT_FOUND, 'draft_not_found', 'Draft not found');
      }

      const pmRef = reloaded.publishedMonoId?.trim() || null;
      const linked = !!(pmRef && pmRef.length > 0);
      if (linked && reloaded.hasUnpublishedCoreChanges) {
        const pm = reloaded.publishedMono;
        this.logM17e4EditStage({
          trigger: 'updateDraft',
          ownerId,
          workspaceDraftId: draftId,
          publishedMonoIdFromDraft: pmRef,
          draftPublishState: reloaded.publishState,
          draftHasDirty: reloaded.hasUnpublishedCoreChanges,
          publishedMonoTrashedAtIso: pm?.trashedAt?.toISOString() ?? null,
          publishedMonoSourceDraftId: this.jsonSourceDraftId(pm?.content),
          createdDraftId: null,
        });
      }

      return reloaded;
    });

    return this.mapFullDraft(updated);
  }

  async listDrafts(
    ownerId: string,
    q: ListStoryDraftsQuery,
  ): Promise<StoryDraftListEnvelopeDto> {
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

  async publishReadOnly(ownerId: string, draftId: string, ifMatch?: string) {
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

      const pubCheck = validateStoryPublishInput(
        storyPublishInputFromDraftRow(draft),
        ValidationMode.ReadOnlyPublish,
      );
      assertNoBlockingValidationIssues(pubCheck);

      const resolution = await resolvePublishedMonoIdForReadOnlyPublish(
        tx as unknown as PublishedMonoReadOnlyPublishScope,
        ownerId,
        { id: draft.id, publishedMonoId: draft.publishedMonoId },
      );
      let publishedMonoId = resolution.publishedMonoId;
      const isFirstPublish = publishedMonoId == null;

      this.logM17e4PublishEntry({
        methodName: 'publishReadOnly',
        ownerId,
        draftId,
        publishState: draft.publishState,
        publishedMonoIdOnDraft: draft.publishedMonoId ?? null,
        hasDirty: draft.hasUnpublishedCoreChanges,
        isFirstPublish,
        resolutionVia: resolution.via,
      });

      if (!publishedMonoId) {
        await assertCanRevealOnePublishedTabMono(
          tx,
          ownerId,
          {
            tag: 'publish-quota',
            draftId,
            publishedMonoId: undefined,
            actionName: 'publishReadOnly_firstPublish',
          },
          (line) => this.logger.log(line),
        );
        const mono = await tx.publishedMono.create({
          data: {
            ownerId,
            title: draft.title ?? '',
            category: draft.category ?? '',
            level: draft.level ?? '',
            description: draft.description ?? '',
            contentLocale: 'en',
            learningLanguage: 'ja',
            content: { sourceDraftId: draft.id },
          },
          select: { id: true },
        });
        publishedMonoId = mono.id;
      } else {
        const wouldReveal =
          (await isOwnerPublishedMonoTabVisible(tx, ownerId, publishedMonoId)) === false;
        if (wouldReveal) {
          await assertCanRevealOnePublishedTabMono(
            tx,
            ownerId,
            {
              tag: 'publish-quota',
              draftId,
              publishedMonoId,
              actionName: 'publishReadOnly_revealCatalogRow',
            },
            (line) => this.logger.log(line),
          );
        } else {
          await logPublishedTabPublishQuotaIfDev(
            tx,
            ownerId,
            { tag: 'publish-quota', draftId, publishedMonoId },
            (line) => this.logger.log(line),
            false,
          );
        }
      }

      // V1 update path:
      // - first publish creates a PublishedMono
      // - subsequent "publish read-only" updates the SAME PublishedMono (reuses id)
      // so "Update Read Only" is backend-safe and does not create a new logical publish.
      // Merge with existing content so a prior full_learn snapshot (`content.learn`) is preserved.
      const existingPm = await tx.publishedMono.findUnique({
        where: { id: publishedMonoId },
        select: { content: true, trashedAt: true },
      });
      const prevContent = (existingPm?.content ?? {}) as Record<string, unknown>;
      const clearTrash = existingPm?.trashedAt != null;
      await tx.publishedMono.update({
        where: { id: publishedMonoId },
        data: {
          ...(clearTrash ? { trashedAt: null } : {}),
          title: draft.title ?? '',
          category: draft.category ?? '',
          level: draft.level ?? '',
          description: draft.description ?? '',
          contentLocale: 'en',
          learningLanguage: 'ja',
          content: {
            ...prevContent,
            sourceDraftId: draft.id,
            publishKind: 'read_only_v1',
            updatedAt: now.toISOString(),
            core: this.buildPublishedCorePayloadFromDraft(draft),
          } as Prisma.InputJsonValue,
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

    if (process.env.NODE_ENV !== 'production') {
      this.logger.log(
        `[M20E backend-edit-update] ownerId=${ownerId} draftId=${draftId} ` +
          `publishedMonoId=${updated.publishedMonoId ?? 'null'} ` +
          `hasUnpublishedCoreChanges_after=${updated.hasUnpublishedCoreChanges} ` +
          `publishState_after=${updated.publishState} publishedMonoExists=true trashedAt=n/a`,
      );
    }

    return this.mapFullDraft(updated);
  }

  async publishFullLearn(ownerId: string, draftId: string, ifMatch?: string) {
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

      const learnCheck = validateStoryPublishInput(
        storyPublishInputFromDraftRow(draft),
        ValidationMode.FullLearnPublish,
      );
      assertNoBlockingValidationIssues(learnCheck);

      this.logM17e4PublishEntry({
        methodName: 'publishFullLearn',
        ownerId,
        draftId,
        publishState: draft.publishState,
        publishedMonoIdOnDraft: draft.publishedMonoId ?? null,
        hasDirty: draft.hasUnpublishedCoreChanges,
        isFirstPublish: false,
        resolutionVia: 'n/a_full_learn_no_row_create',
      });

      if (!draft.publishedMonoId) {
        throw apiError(
          HttpStatus.UNPROCESSABLE_ENTITY,
          'unprocessable_entity',
          'Full-learn publish requires an existing publishedMonoId',
          { unmet: ['published_mono_missing'] },
        );
      }

      const pmIdForQuota = String(draft.publishedMonoId).trim();
      const wouldReveal =
        (await isOwnerPublishedMonoTabVisible(tx, ownerId, pmIdForQuota)) === false;
      if (wouldReveal) {
        await assertCanRevealOnePublishedTabMono(
          tx,
          ownerId,
          {
            tag: 'publish-quota',
            draftId,
            publishedMonoId: pmIdForQuota,
            actionName: 'publishFullLearn_revealCatalogRow',
          },
          (line) => this.logger.log(line),
        );
      } else {
        await logPublishedTabPublishQuotaIfDev(
          tx,
          ownerId,
          { tag: 'publish-quota', draftId, publishedMonoId: pmIdForQuota },
          (line) => this.logger.log(line),
          false,
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

      const publishedMonoId = reloaded.publishedMonoId;
      if (publishedMonoId) {
        const pm = await tx.publishedMono.findUnique({ where: { id: publishedMonoId } });
        if (pm) {
          const prev = (pm.content ?? {}) as Record<string, unknown>;
          const learn = this.buildLearnSnapshotFromDraft(reloaded);
          const core = this.buildPublishedCorePayloadFromDraft(reloaded);
          await tx.publishedMono.update({
            where: { id: publishedMonoId },
            data: {
              title: reloaded.title ?? '',
              category: reloaded.category ?? '',
              level: reloaded.level ?? '',
              description: reloaded.description ?? '',
              contentLocale: 'en',
              learningLanguage: 'ja',
              content: {
                ...prev,
                sourceDraftId: reloaded.id,
                publishKind: 'full_learn_v1',
                updatedAt: now.toISOString(),
                core,
                learn,
              } as Prisma.InputJsonValue,
            },
          });
        }
      }

      return reloaded;
    });

    if (process.env.NODE_ENV !== 'production') {
      this.logger.log(
        `[M20E backend-edit-update] ownerId=${ownerId} draftId=${draftId} ` +
          `publishedMonoId=${updated.publishedMonoId ?? 'null'} ` +
          `hasUnpublishedCoreChanges_after=${updated.hasUnpublishedCoreChanges} ` +
          `publishState_after=${updated.publishState} publishedMonoExists=true trashedAt=n/a`,
      );
    }

    return this.mapFullDraft(updated);
  }
}

