import { HttpException } from '@nestjs/common';
import { PublishState } from '@prisma/client';
import { StoryDraftsService } from './story-drafts.service';

describe('StoryDraftsService owner scoping', () => {
  const ownerA = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const ownerB = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

  it('listDrafts passes ownerId into prisma findMany where', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = {
      storyDraft: { findMany },
      user: { upsert: jest.fn().mockResolvedValue(undefined) },
    } as any;

    await new StoryDraftsService(prisma).listDrafts(ownerA, { limit: '5' });

    expect(findMany).toHaveBeenCalled();
    const where = findMany.mock.calls[0][0].where as { ownerId?: string };
    expect(where).toMatchObject({ ownerId: ownerA });
  });

  it('getDraftById throws when draft not owned', async () => {
    const prisma = {
      storyDraft: {
        findFirst: jest.fn().mockResolvedValue(null),
      },
    } as any;

    const svc = new StoryDraftsService(prisma);

    await expect(svc.getDraftById(ownerB, 'draft-x')).rejects.toBeInstanceOf(
      HttpException,
    );
  });

  it('deleteDraft throws when no row matches id+owner (wrong owner or missing draft)', async () => {
    const findFirst = jest.fn().mockResolvedValue(null);
    const deleteMany = jest.fn();
    const prisma = {
      storyDraft: { findFirst, deleteMany },
      publishedMono: {},
    } as any;

    await expect(
      new StoryDraftsService(prisma).deleteDraft(ownerB, 'draft-x'),
    ).rejects.toBeInstanceOf(HttpException);

    expect(findFirst).toHaveBeenCalledWith({
      where: { id: 'draft-x', ownerId: ownerB },
      select: { publishedMonoId: true, hasUnpublishedCoreChanges: true, publishState: true },
    });
    expect(deleteMany).not.toHaveBeenCalled();
  });

  const monoId = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

  it('deleteDraft rejects when plain draft links an active published mono and has no unpublished edits', async () => {
    const findFirst = jest.fn().mockResolvedValue({
      publishedMonoId: monoId,
      hasUnpublishedCoreChanges: false,
      publishState: PublishState.draft,
    });
    const deleteMany = jest.fn();
    const prisma = {
      storyDraft: { findFirst, deleteMany },
      publishedMono: {
        findUnique: jest.fn().mockResolvedValue({ trashedAt: null, ownerId: ownerA }),
      },
    } as any;

    await expect(
      new StoryDraftsService(prisma).deleteDraft(ownerA, 'draft-y'),
    ).rejects.toMatchObject({ status: 409 });

    expect(deleteMany).not.toHaveBeenCalled();
  });

  it('deleteDraft allows when linked published mono is trashed', async () => {
    const findFirst = jest.fn().mockResolvedValue({
      publishedMonoId: monoId,
      hasUnpublishedCoreChanges: false,
      publishState: PublishState.draft,
    });
    const deleteMany = jest.fn().mockResolvedValue({ count: 1 });
    const prisma = {
      storyDraft: { findFirst, deleteMany },
      publishedMono: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ trashedAt: new Date('2026-03-01T00:00:00Z') }),
      },
    } as any;

    await new StoryDraftsService(prisma).deleteDraft(ownerA, 'draft-z');

    expect(deleteMany).toHaveBeenCalledWith({
      where: { id: 'draft-z', ownerId: ownerA },
    });
  });

  it('deleteDraft allows when linked active mono but publishState is not plain draft (synced workspace)', async () => {
    const findFirst = jest.fn().mockResolvedValue({
      publishedMonoId: monoId,
      hasUnpublishedCoreChanges: false,
      publishState: PublishState.reading_only_published,
    });
    const deleteMany = jest.fn().mockResolvedValue({ count: 1 });
    const prisma = {
      storyDraft: { findFirst, deleteMany },
      publishedMono: {
        findUnique: jest.fn().mockResolvedValue({ trashedAt: null, ownerId: ownerA }),
      },
    } as any;

    await new StoryDraftsService(prisma).deleteDraft(ownerA, 'draft-sync');

    expect(deleteMany).toHaveBeenCalledWith({
      where: { id: 'draft-sync', ownerId: ownerA },
    });
  });
});
