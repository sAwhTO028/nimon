import { PublishState } from '@prisma/client';
import { StoryDraftsService } from './story-drafts.service';

describe('StoryDraftsService.listDrafts', () => {
  type RowOpts = {
    targetDurationBandKey?: string | null;
    moduleWorkflowStatuses?: unknown;
    title?: string | null;
    description?: string | null;
    hasUnpublishedCoreChanges?: boolean;
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
    const out = await svc.listDrafts({ limit: '1' });

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
    const out = await svc.listDrafts({ limit: '5' });
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
    const item = (await svc.listDrafts({ limit: '5' })).items[0];
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
    const item = (await new StoryDraftsService(prisma).listDrafts({ limit: '5' })).items[0];
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
    const item = (await new StoryDraftsService(prisma).listDrafts({ limit: '5' })).items[0];
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
    const item = (await new StoryDraftsService(prisma).listDrafts({ limit: '5' })).items[0];
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
    const item = (await new StoryDraftsService(prisma).listDrafts({ limit: '5' })).items[0];
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
    const item = (await new StoryDraftsService(prisma).listDrafts({ limit: '5' })).items[0];
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
    const item = (await new StoryDraftsService(prisma).listDrafts({ limit: '5' })).items[0];
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

    const first = await svcNoCursor.listDrafts({ limit: '1' });
    expect(first.nextCursor).toBeTruthy();

    const findMany = jest.fn().mockResolvedValue([]);
    const svc = new StoryDraftsService({
      storyDraft: { findMany },
      user: { upsert: jest.fn().mockResolvedValue(undefined) },
    } as any);

    await svc.listDrafts({ limit: '5', cursor: first.nextCursor! });

    expect(findMany).toHaveBeenCalled();
    const arg = findMany.mock.calls[0][0];
    expect(arg.where).toBeDefined();
    expect(arg.take).toBe(6);
  });
});
