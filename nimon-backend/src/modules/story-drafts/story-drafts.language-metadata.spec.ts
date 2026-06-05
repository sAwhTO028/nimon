import { HttpException } from '@nestjs/common';
import { PublishState } from '@prisma/client';
import { StoryDraftsService } from './story-drafts.service';

const OWNER = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const DRAFT_ID = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

function emptyWriteBody(overrides: {
  contentLocale?: string | null;
  learningLanguage?: string | null;
}) {
  return {
    schemaVersion: 1,
    basics: {
      storyId: DRAFT_ID,
      title: 'English draft',
      category: 'drama',
      level: 'N5',
      description: 'Desc',
      promptSourceNote: '',
      targetDurationBandKey: '3_5',
      coverImageUrl: null,
      contentLocale: overrides.contentLocale ?? 'my',
      learningLanguage: overrides.learningLanguage ?? 'en',
    },
    sentences: [
      {
        orderIndex: 0,
        japaneseText: 'Hello world',
        meanings: { en: 'hi' },
      },
    ],
    vocabularyKanji: { entries: [] },
    grammar: { entries: [] },
    quiz: { entries: [] },
    audio: { storyAudio: null },
    publishState: PublishState.draft,
    moduleWorkflowStatuses: {},
  };
}

describe('StoryDraftsService draft language metadata (M23A-3)', () => {
  it('updateDraft persists learningLanguage=en with contentLocale=my', async () => {
    const updateMany = jest.fn().mockResolvedValue({ count: 1 });
    const findFirst = jest
      .fn()
      .mockResolvedValueOnce({
        version: 1,
        publishState: PublishState.draft,
        publishedMonoId: null,
      })
      .mockResolvedValueOnce({
        id: DRAFT_ID,
        ownerId: OWNER,
        schemaVersion: 1,
        version: 2,
        publishState: PublishState.draft,
        title: 'English draft',
        category: 'drama',
        level: 'N5',
        description: 'Desc',
        promptSourceNote: '',
        targetDurationBandKey: '3_5',
        coverImageUrl: null,
        contentLocale: 'my',
        learningLanguage: 'en',
        moduleWorkflowStatuses: {},
        hasUnpublishedCoreChanges: false,
        publishedMonoId: null,
        readingOnlyPublishedAt: null,
        fullLearnPublishedAt: null,
        createdAt: new Date(),
        updatedAt: new Date(),
        sentences: [],
        vocabEntries: [],
        grammarEntries: [],
        quizEntries: [],
        audios: [],
      });

    const prisma = {
      userPreference: {
        findUnique: jest.fn().mockResolvedValue({
          contentLocale: 'en',
          learningLanguage: 'ja',
        }),
      },
      $transaction: jest.fn(async (fn: (tx: unknown) => unknown) =>
        fn({
          storyDraft: { findFirst, updateMany },
          draftSentence: { deleteMany: jest.fn(), createMany: jest.fn() },
          draftVocabEntry: { deleteMany: jest.fn(), createMany: jest.fn() },
          draftGrammarEntry: { deleteMany: jest.fn(), createMany: jest.fn() },
          draftQuizEntry: { deleteMany: jest.fn(), createMany: jest.fn() },
          draftAudio: { deleteMany: jest.fn(), createMany: jest.fn() },
        }),
      ),
    } as any;

    const svc = new StoryDraftsService(prisma);
    const out = await svc.updateDraft(
      OWNER,
      DRAFT_ID,
      emptyWriteBody({ contentLocale: 'my', learningLanguage: 'en' }) as any,
      '"v1"',
    );

    expect(out.basics.learningLanguage).toBe('en');
    expect(out.basics.contentLocale).toBe('my');
    expect(updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          learningLanguage: 'en',
          contentLocale: 'my',
        }),
      }),
    );
  });

  it('updateDraft persists learningLanguage=en with contentLocale=ja', async () => {
    const updateMany = jest.fn().mockResolvedValue({ count: 1 });
    const findFirst = jest
      .fn()
      .mockResolvedValueOnce({
        version: 1,
        publishState: PublishState.draft,
        publishedMonoId: null,
      })
      .mockResolvedValueOnce({
        id: DRAFT_ID,
        ownerId: OWNER,
        schemaVersion: 1,
        version: 2,
        publishState: PublishState.draft,
        title: 'English draft',
        category: 'drama',
        level: 'N5',
        description: 'Desc',
        promptSourceNote: '',
        targetDurationBandKey: '3_5',
        coverImageUrl: null,
        contentLocale: 'ja',
        learningLanguage: 'en',
        moduleWorkflowStatuses: {},
        hasUnpublishedCoreChanges: false,
        publishedMonoId: null,
        readingOnlyPublishedAt: null,
        fullLearnPublishedAt: null,
        createdAt: new Date(),
        updatedAt: new Date(),
        sentences: [],
        vocabEntries: [],
        grammarEntries: [],
        quizEntries: [],
        audios: [],
      });

    const prisma = {
      userPreference: {
        findUnique: jest.fn().mockResolvedValue({
          contentLocale: 'my',
          learningLanguage: 'ja',
        }),
      },
      $transaction: jest.fn(async (fn: (tx: unknown) => unknown) =>
        fn({
          storyDraft: { findFirst, updateMany },
          draftSentence: { deleteMany: jest.fn(), createMany: jest.fn() },
          draftVocabEntry: { deleteMany: jest.fn(), createMany: jest.fn() },
          draftGrammarEntry: { deleteMany: jest.fn(), createMany: jest.fn() },
          draftQuizEntry: { deleteMany: jest.fn(), createMany: jest.fn() },
          draftAudio: { deleteMany: jest.fn(), createMany: jest.fn() },
        }),
      ),
    } as any;

    const svc = new StoryDraftsService(prisma);
    const out = await svc.updateDraft(
      OWNER,
      DRAFT_ID,
      emptyWriteBody({ contentLocale: 'ja', learningLanguage: 'en' }) as any,
      '"v1"',
    );

    expect(out.basics.learningLanguage).toBe('en');
    expect(out.basics.contentLocale).toBe('ja');
  });

  it('updateDraft rejects en+en language pair', async () => {
    const prisma = {
      userPreference: {
        findUnique: jest.fn().mockResolvedValue({
          contentLocale: 'en',
          learningLanguage: 'ja',
        }),
      },
      $transaction: jest.fn(),
    } as any;

    const svc = new StoryDraftsService(prisma);
    let caught: unknown;
    try {
      await svc.updateDraft(
        OWNER,
        DRAFT_ID,
        emptyWriteBody({ contentLocale: 'en', learningLanguage: 'en' }) as any,
        '"v1"',
      );
    } catch (e) {
      caught = e;
    }

    expect(caught).toBeInstanceOf(HttpException);
    const body = (caught as HttpException).getResponse() as {
      error?: { code?: string };
    };
    expect(body.error?.code).toBe('language_pair_same_not_allowed');
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
});
