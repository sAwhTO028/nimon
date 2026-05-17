import { PublishState } from '@prisma/client';
import { DEFAULT_DEV_OWNER_ID } from '../auth/dev-owner.constants';
import { FREE_TIER_QUOTAS, FREE_TIER_QUOTA_KEYS } from '../../common/limits/free-tier-quotas';
import { QuotaExceededException } from '../../common/limits/quota-exceeded.exception';
import { StoryDraftsService } from './story-drafts.service';

const OWNER = DEFAULT_DEV_OWNER_ID;
const draftId = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
const pmId = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';

/**
 * `publishedMono.count` for M17E-6 tab-visible quota:
 * - `where` with `NOT` + `id` → per-mono tab visibility (0/1)
 * - `where` with `NOT` only → owner Published tab total
 * - `where` `{ ownerId }` only → total rows (M17E-9 diagnostics)
 * - `where` `{ ownerId, trashedAt: null }` → active non-trashed rows (M17E-9 diagnostics)
 */
function mockPublishedMonoCountForPublishedTab(opts: {
  tabVisibleTotal: number;
  /** When set, `count({ id: monoId, NOT: … })` returns this instead of 0. */
  monoTabVisible?: boolean;
  monoIdForPerRowCheck?: string;
  /** `count({ where: { ownerId } })` — defaults to tabVisibleTotal. */
  totalPublishedMonosIncludingTrashed?: number;
  /** `count({ where: { ownerId, trashedAt: null } })` — defaults to tabVisibleTotal. */
  activeNonTrashedPublishedMonos?: number;
}) {
  return jest.fn((call: { where: Record<string, unknown> }) => {
    const w = call.where as Record<string, unknown> & { id?: string };
    const keysExOwner = Object.keys(w).filter((k) => k !== 'ownerId');
    if (w.ownerId != null && keysExOwner.length === 0) {
      return Promise.resolve(opts.totalPublishedMonosIncludingTrashed ?? opts.tabVisibleTotal);
    }
    if (
      w.ownerId != null &&
      w.trashedAt === null &&
      !w.NOT &&
      w.id === undefined &&
      keysExOwner.length === 1 &&
      keysExOwner[0] === 'trashedAt'
    ) {
      return Promise.resolve(opts.activeNonTrashedPublishedMonos ?? opts.tabVisibleTotal);
    }
    if (w.NOT != null && typeof w.id === 'string') {
      const want = opts.monoIdForPerRowCheck;
      if (want != null && w.id === want) {
        return Promise.resolve(opts.monoTabVisible === true ? 1 : 0);
      }
      return Promise.resolve(0);
    }
    if (w.NOT != null) {
      return Promise.resolve(opts.tabVisibleTotal);
    }
    if (w.trashedAt && typeof w.trashedAt === 'object' && (w.trashedAt as { not?: unknown }).not === null) {
      return Promise.resolve(0);
    }
    return Promise.resolve(0);
  });
}

function fullLearnValidDraft(overrides: Record<string, unknown> = {}) {
  return {
    id: 'draft-fl-quota',
    ownerId: OWNER,
    version: 4,
    schemaVersion: 1,
    createdAt: new Date('2026-01-01'),
    updatedAt: new Date('2026-01-01'),
    promptSourceNote: '',
    publishState: PublishState.reading_only_published,
    readingOnlyPublishedAt: new Date('2026-01-01'),
    fullLearnPublishedAt: null,
    publishedMonoId: pmId,
    title: 'Title',
    category: 'cat',
    level: 'n5',
    description: 'desc',
    targetDurationBandKey: null,
    hasUnpublishedCoreChanges: false,
    moduleWorkflowStatuses: {
      vocabulary_kanji: 'completed',
      grammar: 'completed',
      quiz: 'completed',
      audio: 'completed',
    },
    sentences: [
      { order: 1, content: { japaneseText: 'い'.repeat(20) } },
      {
        order: 0,
        content: {
          japaneseText: 'あ'.repeat(20),
          furiganaSpans: [{ start: 0, end: 1, reading: 'a' }],
        },
      },
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
    ],
    grammarEntries: [{ order: 0, content: { headline: 'について（パターン）' } }],
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
    ],
    audios: [{ kind: 'storyAudio', content: { id: 'aud', sourceUrl: 'https://cdn/x.mp3' } }],
    ...overrides,
  };
}

function minimalReadOnlyDraft(overrides: Record<string, unknown> = {}) {
  return {
    id: draftId,
    ownerId: OWNER,
    version: 1,
    publishState: PublishState.draft,
    publishedMonoId: null,
    title: 'Valid story title',
    category: 'drama',
    level: 'n5',
    description: '',
    targetDurationBandKey: null,
    moduleWorkflowStatuses: {},
    readingOnlyPublishedAt: null,
    fullLearnPublishedAt: null,
    hasUnpublishedCoreChanges: false,
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
    updatedAt: new Date('2026-01-01T00:00:00.000Z'),
    sentences: [{ order: 0, content: { japaneseText: 'あ'.repeat(20) } }],
    vocabEntries: [],
    grammarEntries: [],
    quizEntries: [],
    audios: [],
    publishedMono: null,
    ...overrides,
  };
}

describe('StoryDraftsService M17E free quotas', () => {
  it('createDraft throws when user already has 50 drafts', async () => {
    const prisma = {
      storyDraft: {
        count: jest.fn().mockResolvedValue(50),
        create: jest.fn(),
      },
      user: { upsert: jest.fn().mockResolvedValue(undefined) },
    } as any;

    const svc = new StoryDraftsService(prisma);
    try {
      await svc.createDraft(OWNER, {
        basics: { title: 'Hello' },
      } as any);
      throw new Error('expected QuotaExceededException');
    } catch (e) {
      expect(e).toBeInstanceOf(QuotaExceededException);
      expect((e as QuotaExceededException).getResponse()).toEqual({
        code: 'quota_exceeded',
        key: FREE_TIER_QUOTA_KEYS.draftStories,
        limit: FREE_TIER_QUOTAS.draftStories,
        current: 50,
      });
    }
    expect(prisma.storyDraft.create).not.toHaveBeenCalled();
  });

  it('createDraft allows when count is 49', async () => {
    const created = minimalReadOnlyDraft({
      publishState: PublishState.draft,
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    const prisma = {
      storyDraft: {
        count: jest.fn().mockResolvedValue(49),
        create: jest.fn().mockResolvedValue(created),
      },
      user: { upsert: jest.fn().mockResolvedValue(undefined) },
    } as any;

    await new StoryDraftsService(prisma).createDraft(OWNER, {
      basics: { title: 'Hello' },
    } as any);
    expect(prisma.storyDraft.create).toHaveBeenCalled();
  });

  it('M17E-7: draft first publish allowed when Published tab visible count is 28', async () => {
    const draft = minimalReadOnlyDraft();
    const newPmId = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
    const reloaded = {
      ...draft,
      version: 2,
      publishState: PublishState.reading_only_published,
      publishedMonoId: newPmId,
    };
    const tx = {
      storyDraft: {
        findFirst: jest.fn().mockResolvedValueOnce(draft).mockResolvedValueOnce(reloaded),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      publishedMono: {
        count: mockPublishedMonoCountForPublishedTab({ tabVisibleTotal: 28 }),
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: newPmId }),
        findUnique: jest.fn().mockResolvedValue({ content: {}, trashedAt: null }),
        update: jest.fn().mockResolvedValue({}),
      },
    };
    const prisma = {
      $transaction: jest.fn((fn: (t: typeof tx) => Promise<unknown>) => fn(tx)),
      user: { upsert: jest.fn() },
    } as any;

    await new StoryDraftsService(prisma).publishReadOnly(OWNER, draftId, '"v1"');
    expect(tx.publishedMono.create).toHaveBeenCalled();
  });

  it('M17E-6: draft first publish blocked when Published tab visible count is 30', async () => {
    const draft = minimalReadOnlyDraft();
    const tx = {
      storyDraft: {
        findFirst: jest.fn().mockResolvedValueOnce(draft),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
        count: jest.fn().mockResolvedValue(32),
      },
      publishedMono: {
        count: mockPublishedMonoCountForPublishedTab({
          tabVisibleTotal: 30,
          totalPublishedMonosIncludingTrashed: 30,
          activeNonTrashedPublishedMonos: 30,
        }),
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
      },
    };
    const prisma = {
      $transaction: jest.fn((fn: (t: typeof tx) => Promise<unknown>) => fn(tx)),
      user: { upsert: jest.fn() },
    } as any;

    try {
      await new StoryDraftsService(prisma).publishReadOnly(OWNER, draftId, '"v1"');
      throw new Error('expected QuotaExceededException');
    } catch (e) {
      expect(e).toBeInstanceOf(QuotaExceededException);
      expect((e as QuotaExceededException).getResponse()).toEqual({
        code: 'quota_exceeded',
        key: FREE_TIER_QUOTA_KEYS.publishedMonos,
        limit: FREE_TIER_QUOTAS.publishedMonos,
        current: 30,
      });
    }
    expect(tx.publishedMono.create).not.toHaveBeenCalled();
  });

  it('M17E-6: draft first publish allowed when Published tab visible count is 29', async () => {
    const draft = minimalReadOnlyDraft();
    const newPmId = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
    const reloaded = {
      ...draft,
      version: 2,
      publishState: PublishState.reading_only_published,
      publishedMonoId: newPmId,
    };
    const tx = {
      storyDraft: {
        findFirst: jest.fn().mockResolvedValueOnce(draft).mockResolvedValueOnce(reloaded),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      publishedMono: {
        count: mockPublishedMonoCountForPublishedTab({ tabVisibleTotal: 29 }),
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: newPmId }),
        findUnique: jest.fn().mockResolvedValue({ content: {}, trashedAt: null }),
        update: jest.fn().mockResolvedValue({}),
      },
    };
    const prisma = {
      $transaction: jest.fn((fn: (t: typeof tx) => Promise<unknown>) => fn(tx)),
      user: { upsert: jest.fn() },
    } as any;

    await new StoryDraftsService(prisma).publishReadOnly(OWNER, draftId, '"v1"');
    expect(tx.publishedMono.create).toHaveBeenCalled();
  });

  it('M17E-9: first publish allowed with 29 catalog-visible monos and 32 story_drafts rows', async () => {
    const draft = minimalReadOnlyDraft();
    const newPmId = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
    const reloaded = {
      ...draft,
      version: 2,
      publishState: PublishState.reading_only_published,
      publishedMonoId: newPmId,
    };
    const tx = {
      storyDraft: {
        findFirst: jest.fn().mockResolvedValueOnce(draft).mockResolvedValueOnce(reloaded),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        count: jest.fn().mockResolvedValue(32),
      },
      publishedMono: {
        count: mockPublishedMonoCountForPublishedTab({
          tabVisibleTotal: 29,
          totalPublishedMonosIncludingTrashed: 29,
          activeNonTrashedPublishedMonos: 29,
        }),
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: newPmId }),
        findUnique: jest.fn().mockResolvedValue({ content: {}, trashedAt: null }),
        update: jest.fn().mockResolvedValue({}),
      },
    };
    const prisma = {
      $transaction: jest.fn((fn: (t: typeof tx) => Promise<unknown>) => fn(tx)),
      user: { upsert: jest.fn() },
    } as any;

    await new StoryDraftsService(prisma).publishReadOnly(OWNER, draftId, '"v1"');
    expect(tx.publishedMono.create).toHaveBeenCalled();
  });

  it('M17E-7: read-only update allowed when tab visible is 30 and target mono is tab-visible (no +1)', async () => {
    const draft = minimalReadOnlyDraft({
      publishedMonoId: pmId,
      publishState: PublishState.reading_only_published,
    });
    const reloaded = { ...draft, version: 2, hasUnpublishedCoreChanges: false };
    const tx = {
      storyDraft: {
        findFirst: jest.fn().mockResolvedValueOnce(draft).mockResolvedValueOnce(reloaded),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      publishedMono: {
        count: mockPublishedMonoCountForPublishedTab({
          tabVisibleTotal: 30,
          monoIdForPerRowCheck: pmId,
          monoTabVisible: true,
        }),
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
        findUnique: jest.fn().mockResolvedValue({ content: {}, trashedAt: null }),
        update: jest.fn().mockResolvedValue({}),
      },
    };
    const prisma = {
      $transaction: jest.fn((fn: (t: typeof tx) => Promise<unknown>) => fn(tx)),
      user: { upsert: jest.fn() },
    } as any;

    await new StoryDraftsService(prisma).publishReadOnly(OWNER, draftId, '"v1"');
    expect(tx.publishedMono.create).not.toHaveBeenCalled();
    expect(tx.publishedMono.update).toHaveBeenCalled();
  });

  it('M17E-7: read-only update blocked when tab visible is 30 and target mono is not tab-visible (reveal would be 31)', async () => {
    const draft = minimalReadOnlyDraft({
      publishedMonoId: pmId,
      publishState: PublishState.reading_only_published,
      hasUnpublishedCoreChanges: true,
    });
    const reloaded = { ...draft, version: 2, hasUnpublishedCoreChanges: false };
    const tx = {
      storyDraft: {
        findFirst: jest.fn().mockResolvedValueOnce(draft).mockResolvedValueOnce(reloaded),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      publishedMono: {
        count: mockPublishedMonoCountForPublishedTab({
          tabVisibleTotal: 30,
          monoIdForPerRowCheck: pmId,
          monoTabVisible: false,
        }),
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
        findUnique: jest.fn().mockResolvedValue({ content: {}, trashedAt: null }),
        update: jest.fn().mockResolvedValue({}),
      },
    };
    const prisma = {
      $transaction: jest.fn((fn: (t: typeof tx) => Promise<unknown>) => fn(tx)),
      user: { upsert: jest.fn() },
    } as any;

    try {
      await new StoryDraftsService(prisma).publishReadOnly(OWNER, draftId, '"v1"');
      throw new Error('expected QuotaExceededException');
    } catch (e) {
      expect(e).toBeInstanceOf(QuotaExceededException);
      expect((e as QuotaExceededException).getResponse()).toMatchObject({
        code: 'quota_exceeded',
        current: 30,
      });
    }
    expect(tx.publishedMono.create).not.toHaveBeenCalled();
    expect(tx.publishedMono.update).not.toHaveBeenCalled();
  });

  it('M17E-6: read-only update allowed when tab visible is 29 and target mono is not tab-visible (edit staging)', async () => {
    const draft = minimalReadOnlyDraft({
      publishedMonoId: pmId,
      publishState: PublishState.reading_only_published,
      hasUnpublishedCoreChanges: true,
    });
    const reloaded = { ...draft, version: 2, hasUnpublishedCoreChanges: false };
    const tx = {
      storyDraft: {
        findFirst: jest.fn().mockResolvedValueOnce(draft).mockResolvedValueOnce(reloaded),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      publishedMono: {
        count: mockPublishedMonoCountForPublishedTab({
          tabVisibleTotal: 29,
          monoIdForPerRowCheck: pmId,
          monoTabVisible: false,
        }),
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
        findUnique: jest.fn().mockResolvedValue({ content: {}, trashedAt: null }),
        update: jest.fn().mockResolvedValue({}),
      },
    };
    const prisma = {
      $transaction: jest.fn((fn: (t: typeof tx) => Promise<unknown>) => fn(tx)),
      user: { upsert: jest.fn() },
    } as any;

    await new StoryDraftsService(prisma).publishReadOnly(OWNER, draftId, '"v1"');
    expect(tx.publishedMono.create).not.toHaveBeenCalled();
    expect(tx.publishedMono.update).toHaveBeenCalled();
  });

  it('M17E-7: full-learn update allowed when tab visible is 30 and target mono tab-visible', async () => {
    const flId = 'draft-fl-quota';
    const draftBefore = fullLearnValidDraft({ id: flId });
    const draftAfter = {
      ...draftBefore,
      version: 5,
      publishState: PublishState.full_learn_published,
    };
    const tx = {
      storyDraft: {
        findFirst: jest.fn().mockResolvedValueOnce(draftBefore).mockResolvedValueOnce(draftAfter),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      publishedMono: {
        count: mockPublishedMonoCountForPublishedTab({
          tabVisibleTotal: 30,
          monoIdForPerRowCheck: pmId,
          monoTabVisible: true,
        }),
        findUnique: jest.fn().mockResolvedValue({
          content: { core: {}, publishKind: 'read_only_v1' },
        }),
        update: jest.fn().mockResolvedValue({}),
      },
    };
    const prisma = {
      $transaction: jest.fn((fn: (t: typeof tx) => Promise<unknown>) => fn(tx)),
      user: { upsert: jest.fn() },
    } as any;

    await new StoryDraftsService(prisma).publishFullLearn(OWNER, flId, '"v4"');
    expect(tx.publishedMono.update).toHaveBeenCalled();
  });

  it('M17E-7: full-learn update blocked when tab visible is 30 and target mono not tab-visible', async () => {
    const flId = 'draft-fl-quota';
    const draftBefore = fullLearnValidDraft({
      id: flId,
      hasUnpublishedCoreChanges: true,
    });
    const draftAfter = {
      ...draftBefore,
      version: 5,
      publishState: PublishState.full_learn_published,
    };
    const tx = {
      storyDraft: {
        findFirst: jest.fn().mockResolvedValueOnce(draftBefore).mockResolvedValueOnce(draftAfter),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      publishedMono: {
        count: mockPublishedMonoCountForPublishedTab({
          tabVisibleTotal: 30,
          monoIdForPerRowCheck: pmId,
          monoTabVisible: false,
        }),
        findUnique: jest.fn().mockResolvedValue({
          content: { core: {}, publishKind: 'read_only_v1' },
        }),
        update: jest.fn().mockResolvedValue({}),
      },
    };
    const prisma = {
      $transaction: jest.fn((fn: (t: typeof tx) => Promise<unknown>) => fn(tx)),
      user: { upsert: jest.fn() },
    } as any;

    try {
      await new StoryDraftsService(prisma).publishFullLearn(OWNER, flId, '"v4"');
      throw new Error('expected QuotaExceededException');
    } catch (e) {
      expect(e).toBeInstanceOf(QuotaExceededException);
      expect((e as QuotaExceededException).getResponse()).toMatchObject({
        code: 'quota_exceeded',
        current: 30,
      });
    }
    expect(tx.publishedMono.update).not.toHaveBeenCalled();
  });

  it('M17E-6: full-learn update allowed when tab visible is 29', async () => {
    const flId = 'draft-fl-quota-2';
    const draftBefore = fullLearnValidDraft({ id: flId });
    const draftAfter = {
      ...draftBefore,
      version: 5,
      publishState: PublishState.full_learn_published,
    };
    const tx = {
      storyDraft: {
        findFirst: jest.fn().mockResolvedValueOnce(draftBefore).mockResolvedValueOnce(draftAfter),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      publishedMono: {
        count: mockPublishedMonoCountForPublishedTab({
          tabVisibleTotal: 29,
          monoIdForPerRowCheck: pmId,
          monoTabVisible: true,
        }),
        findUnique: jest.fn().mockResolvedValue({
          content: { core: {}, publishKind: 'read_only_v1' },
        }),
        update: jest.fn().mockResolvedValue({}),
      },
    };
    const prisma = {
      $transaction: jest.fn((fn: (t: typeof tx) => Promise<unknown>) => fn(tx)),
      user: { upsert: jest.fn() },
    } as any;

    await new StoryDraftsService(prisma).publishFullLearn(OWNER, flId, '"v4"');
    expect(tx.storyDraft.updateMany).toHaveBeenCalled();
  });

  it('M20E: cancel editing (discard staging delete) allowed even when tab visible is 30 and mono not tab-visible', async () => {
    const prisma = {
      storyDraft: {
        findFirst: jest.fn().mockResolvedValue({
          publishedMonoId: pmId,
          hasUnpublishedCoreChanges: true,
          publishState: PublishState.reading_only_published,
        }),
        deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      publishedMono: {
        findUnique: jest.fn().mockResolvedValue({ trashedAt: null, ownerId: OWNER }),
        count: mockPublishedMonoCountForPublishedTab({
          tabVisibleTotal: 30,
          monoIdForPerRowCheck: pmId,
          monoTabVisible: false,
        }),
      },
    } as any;

    await new StoryDraftsService(prisma).deleteDraft(OWNER, draftId);
    expect(prisma.storyDraft.deleteMany).toHaveBeenCalled();
  });

  it('M17E-6: cancel editing allowed when tab visible is 29', async () => {
    const prisma = {
      storyDraft: {
        findFirst: jest.fn().mockResolvedValue({
          publishedMonoId: pmId,
          hasUnpublishedCoreChanges: true,
          publishState: PublishState.reading_only_published,
        }),
        deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      publishedMono: {
        findUnique: jest.fn().mockResolvedValue({ trashedAt: null, ownerId: OWNER }),
        count: mockPublishedMonoCountForPublishedTab({
          tabVisibleTotal: 29,
          monoIdForPerRowCheck: pmId,
          monoTabVisible: false,
        }),
      },
    } as any;

    await new StoryDraftsService(prisma).deleteDraft(OWNER, draftId);
    expect(prisma.storyDraft.deleteMany).toHaveBeenCalled();
  });

  it('M17E-6: whitespace-only publishedMonoId still uses first-publish path and tab quota', async () => {
    const draft = minimalReadOnlyDraft({ publishedMonoId: '  \t  ' });
    const tx = {
      storyDraft: {
        findFirst: jest.fn().mockResolvedValueOnce(draft),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      publishedMono: {
        count: mockPublishedMonoCountForPublishedTab({ tabVisibleTotal: 30 }),
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
      },
    };
    const prisma = {
      $transaction: jest.fn((fn: (t: typeof tx) => Promise<unknown>) => fn(tx)),
      user: { upsert: jest.fn() },
    } as any;

    await expect(
      new StoryDraftsService(prisma).publishReadOnly(OWNER, draftId, '"v1"'),
    ).rejects.toBeInstanceOf(QuotaExceededException);
    expect(tx.publishedMono.create).not.toHaveBeenCalled();
  });

  it('publishReadOnly resolves existing mono via PublishedMono.content.sourceDraftId (no duplicate row)', async () => {
    const resolvedPm = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
    const draft = minimalReadOnlyDraft();
    const reloaded = {
      ...draft,
      version: 2,
      publishState: PublishState.reading_only_published,
      publishedMonoId: resolvedPm,
    };
    const tx = {
      storyDraft: {
        findFirst: jest.fn().mockResolvedValueOnce(draft).mockResolvedValueOnce(reloaded),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      publishedMono: {
        count: mockPublishedMonoCountForPublishedTab({
          tabVisibleTotal: 29,
          monoIdForPerRowCheck: resolvedPm,
          monoTabVisible: false,
        }),
        findFirst: jest.fn().mockResolvedValue({ id: resolvedPm }),
        create: jest.fn(),
        findUnique: jest.fn().mockResolvedValue({ content: { sourceDraftId: draftId }, trashedAt: null }),
        update: jest.fn().mockResolvedValue({}),
      },
    };
    const prisma = {
      $transaction: jest.fn((fn: (t: typeof tx) => Promise<unknown>) => fn(tx)),
      user: { upsert: jest.fn() },
    } as any;

    await new StoryDraftsService(prisma).publishReadOnly(OWNER, draftId, '"v1"');
    expect(tx.publishedMono.create).not.toHaveBeenCalled();
    expect(tx.publishedMono.update).toHaveBeenCalled();
  });
});
