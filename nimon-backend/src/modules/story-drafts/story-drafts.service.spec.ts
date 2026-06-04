import { BadRequestException } from '@nestjs/common';
import { PublishState } from '@prisma/client';
import { DEFAULT_DEV_OWNER_ID } from '../auth/dev-owner.constants';
import { StoryDraftsService } from './story-drafts.service';

/** Matches legacy dev list queries — service scopes all list rows by this owner id. */
const LIST_OWNER = DEFAULT_DEV_OWNER_ID;

/** AI import + N5 + 3–5 mins — smallest HTML-valid publish fixture (JP). */
const HTML_AI_N5_3_5 = {
  targetDurationBandKey: '3_5' as const,
  promptSourceNote: 'promptDataTab=AI_mode',
  sentenceCount: 24,
  charsPerSentence: 15,
  vocabCount: 8,
  grammarCount: 3,
  quizVocab: 5,
  quizGrammar: 3,
  quizSentence: 3,
  quizTotal: 11,
};

function htmlValidSentences(count: number, charsPerSentence: number) {
  const t = 'あ'.repeat(charsPerSentence);
  return Array.from({ length: count }, (_, order) => ({
    order,
    content: { japaneseText: t },
  }));
}

function htmlValidVocabFiller(fromOrder: number, count: number) {
  return Array.from({ length: count }, (_, i) => ({
    order: fromOrder + i,
    content: {
      termJapanese: `たんご${fromOrder + i}`,
      type: 'vocabulary' as const,
      reading: 'あ',
      glosses: { my: 'meaning' },
    },
  }));
}

function htmlValidGrammarFiller(fromOrder: number, count: number) {
  return Array.from({ length: count }, (_, i) => ({
    order: fromOrder + i,
    content: { headline: `ぶんぽう${fromOrder + i}` },
  }));
}

function htmlValidQuizFiller(
  fromOrder: number,
  opts: { vocab: number; grammar: number; sentence: number },
) {
  const rows: Array<{
    order: number;
    content: {
      category: string;
      prompt: string;
      options: string[];
      correctIndex: number;
    };
  }> = [];
  let order = fromOrder;
  for (let i = 0; i < opts.vocab; i++) {
    rows.push({
      order: order++,
      content: {
        category: 'vocabulary',
        prompt: `Vocab quiz filler ${fromOrder + i}?`,
        options: ['a', 'b', 'c', 'd'],
        correctIndex: 0,
      },
    });
  }
  for (let i = 0; i < opts.grammar; i++) {
    rows.push({
      order: order++,
      content: {
        category: 'grammar',
        prompt: `Grammar quiz filler ${fromOrder + i}?`,
        options: ['a', 'b', 'c', 'd'],
        correctIndex: 0,
      },
    });
  }
  for (let i = 0; i < opts.sentence; i++) {
    rows.push({
      order: order++,
      content: {
        category: 'sample_sentence',
        prompt: `Sentence quiz filler ${fromOrder + i}?`,
        options: ['a', 'b', 'c', 'd'],
        correctIndex: 0,
      },
    });
  }
  return rows;
}

describe('StoryDraftsService.listDrafts', () => {
  type RowOpts = {
    targetDurationBandKey?: string | null;
    moduleWorkflowStatuses?: unknown;
    title?: string | null;
    description?: string | null;
    hasUnpublishedCoreChanges?: boolean;
    contentLocale?: string | null;
    learningLanguage?: string | null;
  };

  const row = (
    id: string,
    updatedAt: string,
    sentences: number,
    publishState: PublishState = PublishState.draft,
    opts: RowOpts = {},
  ) => ({
    id,
    title: opts.title ?? 'Hello',
    category: 'drama',
    level: 'n5',
    description: opts.description ?? 'Preview body',
    coverImageUrl: null as string | null,
    publishState,
    updatedAt: new Date(updatedAt),
    targetDurationBandKey: opts.targetDurationBandKey ?? null,
    moduleWorkflowStatuses: opts.moduleWorkflowStatuses ?? {},
    hasUnpublishedCoreChanges:
      opts.hasUnpublishedCoreChanges ??
      (publishState === PublishState.draft ? false : true),
    contentLocale: opts.contentLocale ?? null,
    learningLanguage: opts.learningLanguage ?? null,
    _count: { sentences },
  });

  it('returns paginated envelope with nextCursor when more rows exist', async () => {
    const findMany = jest
      .fn()
      .mockResolvedValue([row('a', '2026-01-02T00:00:00.000Z', 2), row('b', '2026-01-01T00:00:00.000Z', 1)]);
    const prisma = {
      storyDraft: { findMany },
      user: { upsert: jest.fn().mockResolvedValue(undefined) },
    } as any;

    const svc = new StoryDraftsService(prisma);
    const out = await svc.listDrafts(LIST_OWNER, { limit: '1' });

    expect(out.items).toHaveLength(1);
    expect(out.items[0].draftId).toBe('a');
    expect(out.hasMore).toBe(true);
    expect(out.nextCursor).toBeTruthy();
    expect(out.totalCount).toBeNull();
    expect(out.items[0].sentenceCount).toBe(2);
    expect(out.items[0].previewText).toContain('Preview');
    expect(out.items[0].workspaceState).toBe('draft');
    expect(out.items[0].hasUnpublishedCoreChanges).toBe(false);
    expect(out.items[0].completionPercent).toBeGreaterThanOrEqual(0);
    expect(out.items[0].completionPercent).toBeLessThanOrEqual(100);
    expect(out.items[0].processingStatus).toBeNull();
  });

  it('includes contentLocale and learningLanguage on summary items (M22F-1)', async () => {
    const findMany = jest.fn().mockResolvedValue([
      row('loc', '2026-01-02T00:00:00.000Z', 1, PublishState.draft, {
        contentLocale: 'my',
        learningLanguage: 'ja',
      }),
      row('leg', '2026-01-01T00:00:00.000Z', 0, PublishState.draft, {
        contentLocale: null,
        learningLanguage: null,
      }),
    ]);
    const prisma = {
      storyDraft: { findMany },
      user: { upsert: jest.fn().mockResolvedValue(undefined) },
    } as any;
    const svc = new StoryDraftsService(prisma);
    const out = await svc.listDrafts(LIST_OWNER, { limit: '5' });
    expect(out.items[0].contentLocale).toBe('my');
    expect(out.items[0].learningLanguage).toBe('ja');
    expect(out.items[1].contentLocale).toBeNull();
    expect(out.items[1].learningLanguage).toBeNull();
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        select: expect.objectContaining({
          contentLocale: true,
          learningLanguage: true,
        }),
      }),
    );
  });

  it('includes targetDurationBandKey on summary items', async () => {
    const findMany = jest.fn().mockResolvedValue([
      row('x', '2026-01-02T00:00:00.000Z', 1, PublishState.draft, {
        targetDurationBandKey: '5_7',
      }),
    ]);
    const prisma = {
      storyDraft: { findMany },
      user: { upsert: jest.fn().mockResolvedValue(undefined) },
    } as any;
    const svc = new StoryDraftsService(prisma);
    const out = await svc.listDrafts(LIST_OWNER, { limit: '5' });
    expect(out.items[0].targetDurationBandKey).toBe('5_7');
  });

  it('maps empty moduleWorkflowStatuses to defaults with learnModeEnabled false', async () => {
    const findMany = jest.fn().mockResolvedValue([
      row('x', '2026-01-02T00:00:00.000Z', 0, PublishState.draft, {
        moduleWorkflowStatuses: {},
      }),
    ]);
    const prisma = {
      storyDraft: { findMany },
      user: { upsert: jest.fn().mockResolvedValue(undefined) },
    } as any;
    const svc = new StoryDraftsService(prisma);
    const item = (await svc.listDrafts(LIST_OWNER, { limit: '5' })).items[0];
    expect(item.moduleWorkflowStatuses.vocabulary_kanji).toBe('not_started');
    expect(item.learnModeEnabled).toBe(false);
    expect(item.lastEditingStep).toBeNull();
  });

  it('learnModeEnabled true when at least one module is not not_started', async () => {
    const findMany = jest.fn().mockResolvedValue([
      row('x', '2026-01-02T00:00:00.000Z', 1, PublishState.draft, {
        moduleWorkflowStatuses: {
          vocabulary_kanji: 'in_progress',
          grammar: 'not_started',
          quiz: 'not_started',
          audio: 'not_started',
        },
      }),
    ]);
    const prisma = {
      storyDraft: { findMany },
      user: { upsert: jest.fn().mockResolvedValue(undefined) },
    } as any;
    const item = (
      await new StoryDraftsService(prisma).listDrafts(LIST_OWNER, { limit: '5' })
    ).items[0];
    expect(item.learnModeEnabled).toBe(true);
    expect(item.lastEditingStep).toBe('vocabulary_kanji');
  });

  it('learnModeEnabled false when all modules not_started', async () => {
    const findMany = jest.fn().mockResolvedValue([
      row('x', '2026-01-02T00:00:00.000Z', 1, PublishState.draft, {
        moduleWorkflowStatuses: {
          vocabulary_kanji: 'not_started',
          grammar: 'not_started',
          quiz: 'not_started',
          audio: 'not_started',
        },
      }),
    ]);
    const prisma = {
      storyDraft: { findMany },
      user: { upsert: jest.fn().mockResolvedValue(undefined) },
    } as any;
    const item = (
      await new StoryDraftsService(prisma).listDrafts(LIST_OWNER, { limit: '5' })
    ).items[0];
    expect(item.learnModeEnabled).toBe(false);
  });

  it('workspaceState is editing for published dirty rows', async () => {
    const findMany = jest.fn().mockResolvedValue([
      row('x', '2026-01-02T00:00:00.000Z', 2, PublishState.reading_only_published, {
        hasUnpublishedCoreChanges: true,
      }),
    ]);
    const prisma = {
      storyDraft: { findMany },
      user: { upsert: jest.fn().mockResolvedValue(undefined) },
    } as any;
    const item = (
      await new StoryDraftsService(prisma).listDrafts(LIST_OWNER, { limit: '5' })
    ).items[0];
    expect(item.workspaceState).toBe('editing');
    expect(item.hasUnpublishedCoreChanges).toBe(true);
  });

  it('workspaceState is synced for published clean rows', async () => {
    const findMany = jest.fn().mockResolvedValue([
      row('x', '2026-01-02T00:00:00.000Z', 2, PublishState.reading_only_published, {
        hasUnpublishedCoreChanges: false,
      }),
    ]);
    const prisma = {
      storyDraft: { findMany },
      user: { upsert: jest.fn().mockResolvedValue(undefined) },
    } as any;
    const item = (
      await new StoryDraftsService(prisma).listDrafts(LIST_OWNER, { limit: '5' })
    ).items[0];
    expect(item.workspaceState).toBe('synced');
    expect(item.hasUnpublishedCoreChanges).toBe(false);
  });

  it('full_learn published dirty maps to editing', async () => {
    const findMany = jest.fn().mockResolvedValue([
      row('x', '2026-01-02T00:00:00.000Z', 1, PublishState.full_learn_published, {
        hasUnpublishedCoreChanges: true,
      }),
    ]);
    const prisma = {
      storyDraft: { findMany },
      user: { upsert: jest.fn().mockResolvedValue(undefined) },
    } as any;
    const item = (
      await new StoryDraftsService(prisma).listDrafts(LIST_OWNER, { limit: '5' })
    ).items[0];
    expect(item.workspaceState).toBe('editing');
  });

  it('completionPercent stays within 0–100', async () => {
    const findMany = jest.fn().mockResolvedValue([
      row('x', '2026-01-02T00:00:00.000Z', 99, PublishState.draft, {
        moduleWorkflowStatuses: {
          vocabulary_kanji: 'completed',
          grammar: 'completed',
          quiz: 'completed',
          audio: 'completed',
        },
        targetDurationBandKey: '7_9',
      }),
    ]);
    const prisma = {
      storyDraft: { findMany },
      user: { upsert: jest.fn().mockResolvedValue(undefined) },
    } as any;
    const item = (
      await new StoryDraftsService(prisma).listDrafts(LIST_OWNER, { limit: '5' })
    ).items[0];
    expect(item.completionPercent).toBeGreaterThanOrEqual(0);
    expect(item.completionPercent).toBeLessThanOrEqual(100);
  });

  it('decodes cursor and requests next page', async () => {
    const svcNoCursor = new StoryDraftsService({
      storyDraft: {
        findMany: jest.fn().mockResolvedValue([
          row('first', '2026-01-03T00:00:00.000Z', 0),
          row('second', '2026-01-02T00:00:00.000Z', 0),
        ]),
      },
      user: { upsert: jest.fn().mockResolvedValue(undefined) },
    } as any);

    const first = await svcNoCursor.listDrafts(LIST_OWNER, { limit: '1' });
    expect(first.nextCursor).toBeTruthy();

    const findMany = jest.fn().mockResolvedValue([]);
    const svc = new StoryDraftsService({
      storyDraft: { findMany },
      user: { upsert: jest.fn().mockResolvedValue(undefined) },
    } as any);

    await svc.listDrafts(LIST_OWNER, { limit: '5', cursor: first.nextCursor! });

    expect(findMany).toHaveBeenCalled();
    const arg = findMany.mock.calls[0][0];
    expect(arg.where).toBeDefined();
    expect(arg.take).toBe(6);
  });
});

describe('StoryDraftsService.publishFullLearn + publishReadOnly content merge', () => {
  const ownerId = LIST_OWNER;

  function txFactory(mocks: {
    storyDraftFindFirst: jest.Mock;
    storyDraftUpdateMany: jest.Mock;
    publishedMonoFindUnique?: jest.Mock;
    publishedMonoUpdate?: jest.Mock;
    publishedMonoCreate?: jest.Mock;
    publishedMonoCount?: jest.Mock;
    userPreferenceFindUnique?: jest.Mock;
  }) {
    return jest.fn(async (fn: (tx: any) => Promise<any>) => {
      const tx = {
        storyDraft: {
          findFirst: mocks.storyDraftFindFirst,
          updateMany: mocks.storyDraftUpdateMany,
        },
        publishedMono: {
          findUnique: mocks.publishedMonoFindUnique ?? jest.fn(),
          update: mocks.publishedMonoUpdate ?? jest.fn().mockResolvedValue({}),
          create:
            mocks.publishedMonoCreate ??
            jest.fn().mockResolvedValue({ id: 'new-mono' }),
          count: mocks.publishedMonoCount ?? jest.fn().mockResolvedValue(0),
        },
        userPreference: {
          findUnique:
            mocks.userPreferenceFindUnique ??
            jest.fn().mockResolvedValue({
              contentLocale: 'my',
              learningLanguage: 'ja',
            }),
        },
      };
      return fn(tx);
    });
  }

  const baseDraftShape = {
    ownerId,
    schemaVersion: 1,
    createdAt: new Date('2026-01-01'),
    updatedAt: new Date('2026-01-01'),
    promptSourceNote: HTML_AI_N5_3_5.promptSourceNote,
    targetDurationBandKey: HTML_AI_N5_3_5.targetDurationBandKey,
    contentLocale: 'my',
    learningLanguage: 'ja',
    publishState: 'reading_only_published',
    readingOnlyPublishedAt: new Date('2026-01-01'),
    fullLearnPublishedAt: null as Date | null,
  };

  it('publishFullLearn writes content.learn.schemaVersion 1 and copies learn layers', async () => {
    const draftId = 'draft-fl';
    const monoId = 'mono-fl';
    const draftBefore = {
      ...baseDraftShape,
      id: draftId,
      version: 4,
      publishedMonoId: monoId,
      title: 'Title',
      category: 'cat',
      level: 'n5',
      description: 'desc',
      moduleWorkflowStatuses: {
        vocabulary_kanji: 'completed',
        grammar: 'completed',
        quiz: 'completed',
        audio: 'completed',
      },
      sentences: [
        { order: 1, content: { japaneseText: 'い'.repeat(HTML_AI_N5_3_5.charsPerSentence) } },
        {
          order: 0,
          content: {
            japaneseText: 'あ'.repeat(HTML_AI_N5_3_5.charsPerSentence),
            furiganaSpans: [{ start: 0, end: 1, reading: 'a' }],
          },
        },
        ...htmlValidSentences(HTML_AI_N5_3_5.sentenceCount - 2, HTML_AI_N5_3_5.charsPerSentence).map(
          (s, i) => ({ ...s, order: i + 2 }),
        ),
      ],
      vocabEntries: [
        {
          order: 0,
          content: {
            termJapanese: 'こんにちは',
            type: 'vocabulary',
            reading: 'こんにちは',
            glosses: { my: 'hello' },
          },
        },
        {
          order: 1,
          content: {
            termJapanese: '私',
            type: 'kanji',
            reading: 'わたし',
            glosses: { en: 'I' },
          },
        },
        ...htmlValidVocabFiller(2, HTML_AI_N5_3_5.vocabCount - 2),
      ],
      grammarEntries: [
        { order: 0, content: { headline: 'について（パターン）' } },
        ...htmlValidGrammarFiller(1, HTML_AI_N5_3_5.grammarCount - 1),
      ],
      quizEntries: [
        {
          order: 0,
          content: {
            category: 'vocabulary',
            prompt: 'Choose the best meaning for the greeting?',
            options: ['hello', 'goodbye', 'sorry', 'please'],
            correctIndex: 0,
          },
        },
        {
          order: 1,
          content: {
            category: 'grammar',
            prompt: 'Pick the grammar note that fits this story?',
            options: ['opt a', 'opt b', 'opt c', 'opt d'],
            correctIndex: 2,
          },
        },
        ...htmlValidQuizFiller(2, {
          vocab: HTML_AI_N5_3_5.quizVocab - 1,
          grammar: HTML_AI_N5_3_5.quizGrammar - 1,
          sentence: HTML_AI_N5_3_5.quizSentence,
        }),
      ],
      audios: [{ kind: 'storyAudio', content: { id: 'aud', sourceUrl: 'https://cdn/x.mp3' } }],
    };

    const publishedMonoFindUnique = jest.fn().mockResolvedValue({
      content: {
        core: { kept: true },
        publishKind: 'read_only_v1',
      },
    });
    const publishedMonoUpdate = jest.fn().mockResolvedValue({});
    const storyDraftFindFirst = jest.fn().mockResolvedValue(draftBefore);
    const storyDraftUpdateMany = jest.fn().mockResolvedValue({ count: 1 });

    const prisma = {
      $transaction: txFactory({
        storyDraftFindFirst,
        storyDraftUpdateMany,
        publishedMonoFindUnique,
        publishedMonoUpdate,
      }),
    } as any;

    await new StoryDraftsService(prisma).publishFullLearn(ownerId, draftId, '"v4"');

    expect(publishedMonoUpdate).toHaveBeenCalledTimes(1);
    const monoData = publishedMonoUpdate.mock.calls[0][0].data as Record<string, unknown>;
    expect(monoData.title).toBe('Title');
    expect(monoData.description).toBe('desc');
    expect(monoData.publishKind).toBe('full_learn_v1');
    expect(monoData.contentLocale).toBe('my');
    expect(monoData.learningLanguage).toBe('ja');
    expect(monoData.hasAudio).toBe(true);
    expect(monoData.sentenceCount).toBe(HTML_AI_N5_3_5.sentenceCount);
    expect(monoData.vocabCount).toBe(HTML_AI_N5_3_5.vocabCount);
    expect(monoData.grammarCount).toBe(HTML_AI_N5_3_5.grammarCount);
    expect(monoData.quizCount).toBe(HTML_AI_N5_3_5.quizTotal);

    const payload = monoData.content as Record<string, unknown>;
    expect(payload.publishKind).toBe('full_learn_v1');
    expect(payload.sourceDraftId).toBe(draftId);

    const core = payload.core as {
      sentences: Array<{ order: number; content: Record<string, unknown> }>;
    };
    expect(core.sentences).toHaveLength(HTML_AI_N5_3_5.sentenceCount);
    expect(core.sentences[0].order).toBe(0);
    expect(core.sentences[0].content.japaneseText).toBe('あ'.repeat(HTML_AI_N5_3_5.charsPerSentence));
    expect(core.sentences[0].content.furiganaSpans).toEqual([
      { start: 0, end: 1, reading: 'a' },
    ]);
    expect(core.sentences[1].order).toBe(1);
    expect(core.sentences[1].content.japaneseText).toBe('い'.repeat(HTML_AI_N5_3_5.charsPerSentence));

    const learn = payload.learn as Record<string, unknown>;
    expect(learn.schemaVersion).toBe(1);
    const vocab = learn.vocabularyKanji as { entries: Array<{ id: string; termJapanese?: string }> };
    expect(vocab.entries).toHaveLength(HTML_AI_N5_3_5.vocabCount);
    expect(vocab.entries[0].termJapanese).toBe('こんにちは');
    expect(vocab.entries[1].termJapanese).toBe('私');
    expect((learn.grammar as { entries: unknown[] }).entries).toHaveLength(
      HTML_AI_N5_3_5.grammarCount,
    );
    expect((learn.quiz as { entries: unknown[] }).entries).toHaveLength(HTML_AI_N5_3_5.quizTotal);
    const audio = learn.audio as { storyAudio: Record<string, unknown> | null };
    expect(audio.storyAudio).toEqual({ id: 'aud', sourceUrl: 'https://cdn/x.mp3' });
  });

  it('publishFullLearn sets storyAudio to null when no storyAudio row', async () => {
    const draftId = 'draft-no-audio';
    const draftBefore = {
      ...baseDraftShape,
      id: draftId,
      version: 2,
      publishedMonoId: 'mono-a',
      title: 'Title',
      category: 'cat',
      level: 'n5',
      description: 'desc',
      moduleWorkflowStatuses: {
        vocabulary_kanji: 'completed',
        grammar: 'completed',
        quiz: 'completed',
        audio: 'completed',
      },
      sentences: htmlValidSentences(
        HTML_AI_N5_3_5.sentenceCount,
        HTML_AI_N5_3_5.charsPerSentence,
      ),
      vocabEntries: htmlValidVocabFiller(0, HTML_AI_N5_3_5.vocabCount),
      grammarEntries: htmlValidGrammarFiller(0, HTML_AI_N5_3_5.grammarCount),
      quizEntries: htmlValidQuizFiller(0, {
        vocab: HTML_AI_N5_3_5.quizVocab,
        grammar: HTML_AI_N5_3_5.quizGrammar,
        sentence: HTML_AI_N5_3_5.quizSentence,
      }),
      audios: [],
    };

    const publishedMonoUpdate = jest.fn().mockResolvedValue({});
    const prisma = {
      $transaction: txFactory({
        storyDraftFindFirst: jest.fn().mockResolvedValue(draftBefore),
        storyDraftUpdateMany: jest.fn().mockResolvedValue({ count: 1 }),
        publishedMonoFindUnique: jest.fn().mockResolvedValue({ content: {} }),
        publishedMonoUpdate,
      }),
    } as any;

    await new StoryDraftsService(prisma).publishFullLearn(ownerId, draftId, '"v2"');

    const learn = (publishedMonoUpdate.mock.calls[0][0].data.content as Record<string, unknown>)
      .learn as Record<string, unknown>;
    expect((learn.audio as { storyAudio: null }).storyAudio).toBeNull();
  });

  it('publishReadOnly merges prior content and preserves content.learn', async () => {
    const draftId = 'draft-ro';
    const monoId = 'mono-ro';
    const draftRow = {
      id: draftId,
      ownerId,
      version: 7,
      publishedMonoId: monoId,
      title: 'Valid story title',
      category: 'c',
      level: 'n5',
      description: 'd',
      targetDurationBandKey: HTML_AI_N5_3_5.targetDurationBandKey,
      sentences: [
        { order: 0, content: { japaneseText: 'こんにちは'.repeat(HTML_AI_N5_3_5.charsPerSentence) } },
        ...htmlValidSentences(HTML_AI_N5_3_5.sentenceCount - 1, HTML_AI_N5_3_5.charsPerSentence).map(
          (s, i) => ({ ...s, order: i + 1 }),
        ),
      ],
      schemaVersion: 1,
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-01'),
      publishState: 'reading_only_published',
      readingOnlyPublishedAt: new Date('2026-01-01'),
      promptSourceNote: HTML_AI_N5_3_5.promptSourceNote,
      moduleWorkflowStatuses: {},
      vocabEntries: [],
      grammarEntries: [],
      quizEntries: [],
      audios: [],
      fullLearnPublishedAt: null as Date | null,
    };

    const publishedMonoFindUnique = jest.fn().mockResolvedValue({
      content: {
        learn: {
          schemaVersion: 1,
          vocabularyKanji: { entries: [{ id: 'keep-me' }] },
        },
        legacyTopLevel: true,
      },
    });
    const publishedMonoUpdate = jest.fn().mockResolvedValue({});
    const storyDraftFindFirst = jest.fn().mockResolvedValue(draftRow);
    const storyDraftUpdateMany = jest.fn().mockResolvedValue({ count: 1 });

    const prisma = {
      $transaction: txFactory({
        storyDraftFindFirst,
        storyDraftUpdateMany,
        publishedMonoFindUnique,
        publishedMonoUpdate,
      }),
    } as any;

    await new StoryDraftsService(prisma).publishReadOnly(ownerId, draftId, '"v7"');

    const content = publishedMonoUpdate.mock.calls[0][0].data.content as Record<string, unknown>;
    expect(content.legacyTopLevel).toBe(true);
    const learn = content.learn as Record<string, unknown>;
    expect((learn.vocabularyKanji as { entries: Array<{ id: string }> }).entries[0].id).toBe(
      'keep-me',
    );
    expect((content.core as Record<string, unknown>).sentences).toBeDefined();
    expect(content.publishKind).toBe('read_only_v1');
  });

  it('publishReadOnly emits core.sentences sorted by DraftSentence.order', async () => {
    const draftId = 'draft-ro-order';
    const monoId = 'mono-ro-order';
    const draftRow = {
      id: draftId,
      ownerId,
      version: 8,
      publishedMonoId: monoId,
      title: 'Valid story title',
      category: 'c',
      level: 'n5',
      description: 'd',
      targetDurationBandKey: HTML_AI_N5_3_5.targetDurationBandKey,
      sentences: [
        { order: 2, content: { japaneseText: '三'.repeat(HTML_AI_N5_3_5.charsPerSentence), meanings: { en: 'three' } } },
        { order: 0, content: { japaneseText: '一'.repeat(HTML_AI_N5_3_5.charsPerSentence) } },
        {
          order: 1,
          content: {
            japaneseText: '二'.repeat(HTML_AI_N5_3_5.charsPerSentence),
            furiganaSpans: [{ start: 0, end: 1, reading: 'に' }],
          },
        },
        ...htmlValidSentences(HTML_AI_N5_3_5.sentenceCount - 3, HTML_AI_N5_3_5.charsPerSentence).map(
          (s, i) => ({ ...s, order: i + 3 }),
        ),
      ],
      schemaVersion: 1,
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-01'),
      publishState: 'reading_only_published',
      readingOnlyPublishedAt: new Date('2026-01-01'),
      promptSourceNote: HTML_AI_N5_3_5.promptSourceNote,
      moduleWorkflowStatuses: {},
      vocabEntries: [],
      grammarEntries: [],
      quizEntries: [],
      audios: [],
      fullLearnPublishedAt: null as Date | null,
    };

    const publishedMonoUpdate = jest.fn().mockResolvedValue({});
    const prisma = {
      $transaction: txFactory({
        storyDraftFindFirst: jest.fn().mockResolvedValue(draftRow),
        storyDraftUpdateMany: jest.fn().mockResolvedValue({ count: 1 }),
        publishedMonoFindUnique: jest.fn().mockResolvedValue({ content: {} }),
        publishedMonoUpdate,
      }),
    } as any;

    await new StoryDraftsService(prisma).publishReadOnly(ownerId, draftId, '"v8"');

    const content = publishedMonoUpdate.mock.calls[0][0].data.content as Record<string, unknown>;
    const coreSentences = (
      content.core as { sentences: Array<{ order: number; content: Record<string, unknown> }> }
    ).sentences;
    expect(coreSentences).toHaveLength(HTML_AI_N5_3_5.sentenceCount);
    expect(coreSentences.map((r) => r.order).slice(0, 3)).toEqual([0, 1, 2]);
    expect(coreSentences[0].content.japaneseText).toBe('一'.repeat(HTML_AI_N5_3_5.charsPerSentence));
    expect(coreSentences[1].content.japaneseText).toBe('二'.repeat(HTML_AI_N5_3_5.charsPerSentence));
    expect(coreSentences[1].content.furiganaSpans).toEqual([{ start: 0, end: 1, reading: 'に' }]);
    expect(coreSentences[2].content.japaneseText).toBe('三'.repeat(HTML_AI_N5_3_5.charsPerSentence));
    expect(coreSentences[2].content.meanings).toEqual({ en: 'three' });
  });

  it('publishReadOnly stamps contentLocale from draft not hardcoded en', async () => {
    const draftId = 'draft-locale-stamp';
    const publishedMonoUpdate = jest.fn().mockResolvedValue({});
    const draftBefore = {
      ...baseDraftShape,
      id: draftId,
      version: 3,
      publishedMonoId: 'mono-ls',
      title: 'Title',
      category: 'cat',
      level: 'n5',
      description: 'desc',
      contentLocale: 'my',
      learningLanguage: 'ja',
      moduleWorkflowStatuses: {
        vocabulary_kanji: 'completed',
        grammar: 'completed',
        quiz: 'completed',
        audio: 'completed',
      },
      sentences: htmlValidSentences(
        HTML_AI_N5_3_5.sentenceCount,
        HTML_AI_N5_3_5.charsPerSentence,
      ),
      vocabEntries: htmlValidVocabFiller(0, HTML_AI_N5_3_5.vocabCount),
      grammarEntries: htmlValidGrammarFiller(0, HTML_AI_N5_3_5.grammarCount),
      quizEntries: htmlValidQuizFiller(0, {
        vocab: HTML_AI_N5_3_5.quizVocab,
        grammar: HTML_AI_N5_3_5.quizGrammar,
        sentence: HTML_AI_N5_3_5.quizSentence,
      }),
      audios: [],
    };

    const prisma = {
      $transaction: txFactory({
        storyDraftFindFirst: jest.fn().mockResolvedValue(draftBefore),
        storyDraftUpdateMany: jest.fn().mockResolvedValue({ count: 1 }),
        publishedMonoFindUnique: jest.fn().mockResolvedValue({ content: {} }),
        publishedMonoUpdate,
      }),
    } as any;

    await new StoryDraftsService(prisma).publishReadOnly(ownerId, draftId, '"v3"');

    const monoData = publishedMonoUpdate.mock.calls[0][0].data as Record<string, unknown>;
    expect(monoData.contentLocale).toBe('my');
    expect(monoData.learningLanguage).toBe('ja');
  });

  it('publishReadOnly rejects ja+ja draft language pair', async () => {
    const draftBefore = {
      ...baseDraftShape,
      id: 'draft-bad-pair',
      version: 1,
      publishedMonoId: null,
      contentLocale: 'ja',
      learningLanguage: 'ja',
      sentences: htmlValidSentences(24, 15),
      vocabEntries: [],
      grammarEntries: [],
      quizEntries: [],
      audios: [],
      moduleWorkflowStatuses: {},
    };

    const prisma = {
      $transaction: txFactory({
        storyDraftFindFirst: jest.fn().mockResolvedValue(draftBefore),
        storyDraftUpdateMany: jest.fn(),
      }),
    } as any;

    await expect(
      new StoryDraftsService(prisma).publishReadOnly(ownerId, 'draft-bad-pair', '"v1"'),
    ).rejects.toThrow(BadRequestException);
  });
});

describe('StoryDraftsService.updateDraft', () => {
  const ownerId = LIST_OWNER;
  const draftId = 'draft-update-linked';

  const userPreferenceFindUnique = jest.fn().mockResolvedValue({
    contentLocale: 'en',
    learningLanguage: 'ja',
  });

  const minimalWriteBody = {
    schemaVersion: 1 as const,
    basics: {
      storyId: draftId,
      title: 'T2',
      category: 'cat',
      level: 'n5',
      description: 'd2',
      promptSourceNote: '',
      targetDurationBandKey: '5_7',
      coverImageUrl: null,
    },
    sentences: [{ orderIndex: 0, japaneseText: '新しい' }],
    vocabularyKanji: { entries: [] as unknown[] },
    grammar: { entries: [] as unknown[] },
    quiz: { entries: [] as unknown[] },
    audio: { storyAudio: null },
    publishState: PublishState.draft,
    moduleWorkflowStatuses: {
      vocabulary_kanji: 'not_started',
      grammar: 'not_started',
      quiz: 'not_started',
      audio: 'not_started',
    },
  };

  it('linked published mono: preserves publishState and marks hasUnpublishedCoreChanges', async () => {
    const updateMany = jest.fn().mockResolvedValue({ count: 1 });
    const reloaded = {
      id: draftId,
      ownerId,
      version: 3,
      schemaVersion: 1,
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-02'),
      title: 'T2',
      category: 'cat',
      level: 'n5',
      description: 'd2',
      promptSourceNote: '',
      targetDurationBandKey: '5_7',
      coverImageUrl: null,
      publishState: PublishState.reading_only_published,
      publishedMonoId: 'pm-99',
      readingOnlyPublishedAt: new Date('2026-01-01'),
      fullLearnPublishedAt: null as Date | null,
      moduleWorkflowStatuses: {},
      sentences: [{ order: 0, content: { japaneseText: '新しい' } }],
      vocabEntries: [],
      grammarEntries: [],
      quizEntries: [],
      audios: [],
    };

    const findFirst = jest
      .fn()
      .mockResolvedValueOnce({
        version: 2,
        publishState: PublishState.reading_only_published,
        publishedMonoId: 'pm-99',
      })
      .mockResolvedValueOnce(reloaded);

    const prisma = {
      $transaction: jest.fn(async (fn: (tx: any) => Promise<any>) => {
        const tx = {
          storyDraft: {
            findFirst,
            updateMany,
          },
          draftSentence: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            createMany: jest.fn().mockResolvedValue(undefined),
          },
          draftVocabEntry: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            createMany: jest.fn().mockResolvedValue(undefined),
          },
          draftGrammarEntry: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            createMany: jest.fn().mockResolvedValue(undefined),
          },
          draftQuizEntry: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            createMany: jest.fn().mockResolvedValue(undefined),
          },
          draftAudio: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            create: jest.fn(),
          },
        };
        return fn(tx);
      }),
      userPreference: { findUnique: userPreferenceFindUnique },
    } as any;

    await new StoryDraftsService(prisma).updateDraft(
      ownerId,
      draftId,
      minimalWriteBody as any,
      '"v2"',
    );

    expect(updateMany).toHaveBeenCalledTimes(1);
    const data = updateMany.mock.calls[0][0].data;
    expect(data.publishState).toBe(PublishState.reading_only_published);
    expect(data.hasUnpublishedCoreChanges).toBe(true);
  });

  it('draft-only row follows body publishState', async () => {
    const updateMany = jest.fn().mockResolvedValue({ count: 1 });
    const reloaded = {
      id: draftId,
      ownerId,
      version: 2,
      schemaVersion: 1,
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-02'),
      title: 'T2',
      category: 'cat',
      level: 'n5',
      description: 'd2',
      promptSourceNote: '',
      targetDurationBandKey: '5_7',
      coverImageUrl: null,
      publishState: PublishState.draft,
      publishedMonoId: null,
      readingOnlyPublishedAt: null,
      fullLearnPublishedAt: null,
      moduleWorkflowStatuses: {},
      sentences: [{ order: 0, content: { japaneseText: '新しい' } }],
      vocabEntries: [],
      grammarEntries: [],
      quizEntries: [],
      audios: [],
    };

    const findFirst = jest
      .fn()
      .mockResolvedValueOnce({
        version: 1,
        publishState: PublishState.draft,
        publishedMonoId: null,
      })
      .mockResolvedValueOnce(reloaded);

    const prisma = {
      $transaction: jest.fn(async (fn: (tx: any) => Promise<any>) => {
        const tx = {
          storyDraft: {
            findFirst,
            updateMany,
          },
          draftSentence: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            createMany: jest.fn().mockResolvedValue(undefined),
          },
          draftVocabEntry: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            createMany: jest.fn().mockResolvedValue(undefined),
          },
          draftGrammarEntry: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            createMany: jest.fn().mockResolvedValue(undefined),
          },
          draftQuizEntry: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            createMany: jest.fn().mockResolvedValue(undefined),
          },
          draftAudio: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            create: jest.fn(),
          },
        };
        return fn(tx);
      }),
      userPreference: { findUnique: userPreferenceFindUnique },
    } as any;

    await new StoryDraftsService(prisma).updateDraft(
      ownerId,
      draftId,
      minimalWriteBody as any,
      '"v1"',
    );

    const data = updateMany.mock.calls[0][0].data;
    expect(data.publishState).toBe(PublishState.draft);
  });

  it('persisted draft_sentences.rows use request array order (reorder), sequential order 0..n-1', async () => {
    const reorderBody = {
      ...minimalWriteBody,
      sentences: [
        { orderIndex: 2, id: 's-c', japaneseText: '三' },
        { orderIndex: 0, id: 's-a', japaneseText: '一' },
        { orderIndex: 1, id: 's-b', japaneseText: '二' },
      ],
    };

    const createMany = jest.fn().mockResolvedValue(undefined);
    const reloaded = {
      id: draftId,
      ownerId,
      version: 2,
      schemaVersion: 1,
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-02'),
      title: 'T2',
      category: 'cat',
      level: 'n5',
      description: 'd2',
      promptSourceNote: '',
      targetDurationBandKey: '5_7',
      coverImageUrl: null,
      publishState: PublishState.draft,
      publishedMonoId: null,
      readingOnlyPublishedAt: null,
      fullLearnPublishedAt: null,
      moduleWorkflowStatuses: {},
      sentences: [],
      vocabEntries: [],
      grammarEntries: [],
      quizEntries: [],
      audios: [],
    };

    const findFirst = jest
      .fn()
      .mockResolvedValueOnce({
        version: 1,
        publishState: PublishState.draft,
        publishedMonoId: null,
      })
      .mockResolvedValueOnce(reloaded);

    const prisma = {
      $transaction: jest.fn(async (fn: (tx: any) => Promise<any>) => {
        const tx = {
          storyDraft: {
            findFirst,
            updateMany: jest.fn().mockResolvedValue({ count: 1 }),
          },
          draftSentence: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            createMany,
          },
          draftVocabEntry: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            createMany: jest.fn().mockResolvedValue(undefined),
          },
          draftGrammarEntry: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            createMany: jest.fn().mockResolvedValue(undefined),
          },
          draftQuizEntry: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            createMany: jest.fn().mockResolvedValue(undefined),
          },
          draftAudio: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            create: jest.fn(),
          },
        };
        return fn(tx);
      }),
      userPreference: { findUnique: userPreferenceFindUnique },
    } as any;

    await new StoryDraftsService(prisma).updateDraft(ownerId, draftId, reorderBody as any, '"v1"');

    const rows = createMany.mock.calls[0][0].data as Array<{
      order: number;
      content: { japaneseText?: string; orderIndex?: number };
    }>;
    expect(rows.map((r) => r.order)).toEqual([0, 1, 2]);
    expect(rows.map((r) => r.content.japaneseText)).toEqual(['三', '一', '二']);
    expect(rows.map((r) => r.content.orderIndex)).toEqual([0, 1, 2]);
  });

  it('persisted draft_sentences: duplicate incoming orderIndex does not fail; all rows kept', async () => {
    const dupBody = {
      ...minimalWriteBody,
      sentences: [
        { orderIndex: 0, id: 'a', japaneseText: 'A' },
        { orderIndex: 0, id: 'b', japaneseText: 'B' },
        { orderIndex: 1, id: 'c', japaneseText: 'C' },
      ],
    };

    const createMany = jest.fn().mockResolvedValue(undefined);
    const reloaded = {
      id: draftId,
      ownerId,
      version: 2,
      schemaVersion: 1,
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-02'),
      title: 'T2',
      category: 'cat',
      level: 'n5',
      description: 'd2',
      promptSourceNote: '',
      targetDurationBandKey: '5_7',
      coverImageUrl: null,
      publishState: PublishState.draft,
      publishedMonoId: null,
      readingOnlyPublishedAt: null,
      fullLearnPublishedAt: null,
      moduleWorkflowStatuses: {},
      sentences: [],
      vocabEntries: [],
      grammarEntries: [],
      quizEntries: [],
      audios: [],
    };

    const findFirst = jest
      .fn()
      .mockResolvedValueOnce({
        version: 1,
        publishState: PublishState.draft,
        publishedMonoId: null,
      })
      .mockResolvedValueOnce(reloaded);

    const prisma = {
      $transaction: jest.fn(async (fn: (tx: any) => Promise<any>) => {
        const tx = {
          storyDraft: {
            findFirst,
            updateMany: jest.fn().mockResolvedValue({ count: 1 }),
          },
          draftSentence: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            createMany,
          },
          draftVocabEntry: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            createMany: jest.fn().mockResolvedValue(undefined),
          },
          draftGrammarEntry: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            createMany: jest.fn().mockResolvedValue(undefined),
          },
          draftQuizEntry: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            createMany: jest.fn().mockResolvedValue(undefined),
          },
          draftAudio: {
            deleteMany: jest.fn().mockResolvedValue(undefined),
            create: jest.fn(),
          },
        };
        return fn(tx);
      }),
      userPreference: { findUnique: userPreferenceFindUnique },
    } as any;

    const svc = new StoryDraftsService(prisma);
    const logWarn = jest.fn();
    (svc as any).logger = { warn: logWarn };

    await svc.updateDraft(ownerId, draftId, dupBody as any, '"v1"');

    expect(logWarn).toHaveBeenCalledWith(
      expect.stringContaining('duplicate orderIndex'),
    );
    const rows = createMany.mock.calls[0][0].data as Array<{
      order: number;
      content: { japaneseText?: string };
    }>;
    expect(rows).toHaveLength(3);
    expect(rows.map((r) => r.order)).toEqual([0, 1, 2]);
    expect(rows.map((r) => r.content.japaneseText)).toEqual(['A', 'B', 'C']);

  });
});
