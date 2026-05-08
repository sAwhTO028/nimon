import { NotFoundException } from '@nestjs/common';
import { PUBLISHED_MONO_CATALOG_VISIBLE } from './published-mono-visibility';
import { PublishedMonosService } from './published-monos.service';
import { HttpStatus } from '@nestjs/common';

describe('PublishedMonosService owner scoping', () => {
  const ownerId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  const monoId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  it('listPublishedMonos scopes by ownerId and excludes dirty-linked published rows', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = {
      publishedMono: { findMany },
      userProfile: { findUnique: jest.fn().mockResolvedValue(null) },
    } as any;

    await new PublishedMonosService(prisma).listPublishedMonos(ownerId, '20');

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { ownerId, ...PUBLISHED_MONO_CATALOG_VISIBLE },
      }),
    );
  });

  it('getPublishedMonoById throws NotFound when row not owned', async () => {
    const findFirst = jest.fn().mockResolvedValue(null);
    const prisma = { publishedMono: { findFirst } } as any;

    await expect(
      new PublishedMonosService(prisma).getPublishedMonoById(
        ownerId,
        'mono-missing',
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('getPublishedMonoById applies catalog visibility (404 when draft has unpublished edits)', async () => {
    const findFirst = jest.fn().mockResolvedValue(null);
    const prisma = { publishedMono: { findFirst } } as any;

    await expect(
      new PublishedMonosService(prisma).getPublishedMonoById(ownerId, monoId),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          id: monoId,
          ownerId,
          ...PUBLISHED_MONO_CATALOG_VISIBLE,
        },
      }),
    );
  });

  it('listPublishedMonos stamps writer fields from owner UserProfile', async () => {
    const row = {
      id: monoId,
      ownerId,
      title: 'T',
      category: '',
      level: '',
      description: '',
      createdAt: new Date('2026-01-01T00:00:00.000Z'),
      updatedAt: new Date('2026-01-02T00:00:00.000Z'),
      content: {},
    };
    const findMany = jest.fn().mockResolvedValue([row]);
    const findUnique = jest.fn().mockResolvedValue({
      displayName: 'Owner Name',
      handle: 'own_h',
      avatarUrl: 'https://avatars.test/o.png',
    });
    const prisma = {
      publishedMono: { findMany },
      userProfile: { findUnique },
    } as any;

    const out = await new PublishedMonosService(prisma).listPublishedMonos(ownerId);

    expect(out.items).toHaveLength(1);
    expect(findUnique).toHaveBeenCalledWith({
      where: { userId: ownerId },
      select: { displayName: true, handle: true, avatarUrl: true },
    });
    expect(out.items[0]?.writerDisplayName).toBe('Owner Name');
    expect(out.items[0]?.writerHandle).toBe('own_h');
    expect(out.items[0]?.writerAvatarUrl).toBe('https://avatars.test/o.png');
  });

  it('getPublishedMonoById attaches writer identity', async () => {
    const findFirst = jest.fn().mockResolvedValue({
      id: monoId,
      ownerId,
      title: 'T',
      category: '',
      level: '',
      description: '',
      createdAt: new Date(),
      updatedAt: new Date(),
      content: { publishKind: 'read_only_v1' },
    });
    const findUnique = jest.fn().mockResolvedValue({
      displayName: 'Me',
      handle: 'me_h',
      avatarUrl: 'https://avatars.test/me.png',
    });
    const prisma = { publishedMono: { findFirst }, userProfile: { findUnique } } as any;

    const d = await new PublishedMonosService(prisma).getPublishedMonoById(ownerId, monoId);

    expect(d.writerDisplayName).toBe('Me');
    expect(d.writerHandle).toBe('me_h');
    expect(d.writerAvatarUrl).toBe('https://avatars.test/me.png');
  });

  it('listPublishedMonos with trashed=true queries trashedAt not null only', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = {
      publishedMono: { findMany },
      userProfile: { findUnique: jest.fn().mockResolvedValue(null) },
    } as any;

    await new PublishedMonosService(prisma).listPublishedMonos(ownerId, '20', 'true');

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { ownerId, trashedAt: { not: null } },
      }),
    );
  });
});

describe('PublishedMonosService trash / restore', () => {
  const ownerId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  const monoId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const t0 = new Date('2026-04-01T12:00:00.000Z');

  it('trash sets trashedAt when active', async () => {
    const findFirst = jest
      .fn()
      .mockResolvedValueOnce({ id: monoId, trashedAt: null })
      .mockResolvedValueOnce({ trashedAt: t0 });
    const updateMany = jest.fn().mockResolvedValue({ count: 1 });
    const prisma = { publishedMono: { findFirst, updateMany } } as any;

    const out = await new PublishedMonosService(prisma).trashPublishedMono(ownerId, monoId);

    expect(out.id).toBe(monoId);
    expect(out.trashedAt).toBe(t0.toISOString());
    expect(updateMany).toHaveBeenCalledWith({
      where: { id: monoId, ownerId, trashedAt: null },
      data: { trashedAt: expect.any(Date) },
    });
  });

  it('trash is idempotent when already trashed', async () => {
    const findFirst = jest.fn().mockResolvedValue({ id: monoId, trashedAt: t0 });
    const updateMany = jest.fn();
    const prisma = { publishedMono: { findFirst, updateMany } } as any;

    const out = await new PublishedMonosService(prisma).trashPublishedMono(ownerId, monoId);

    expect(out).toEqual({ id: monoId, trashedAt: t0.toISOString() });
    expect(updateMany).not.toHaveBeenCalled();
  });

  it('trash 404 when not owner', async () => {
    const findFirst = jest.fn().mockResolvedValue(null);
    const prisma = { publishedMono: { findFirst, updateMany: jest.fn() } } as any;

    await expect(
      new PublishedMonosService(prisma).trashPublishedMono(ownerId, monoId),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('restore clears trashedAt', async () => {
    const findFirst = jest.fn().mockResolvedValue({ id: monoId, trashedAt: t0 });
    const updateMany = jest.fn().mockResolvedValue({ count: 1 });
    const prisma = { publishedMono: { findFirst, updateMany } } as any;

    const out = await new PublishedMonosService(prisma).restorePublishedMono(ownerId, monoId);

    expect(out).toEqual({ id: monoId, trashedAt: null });
    expect(updateMany).toHaveBeenCalledWith({
      where: { id: monoId, ownerId },
      data: { trashedAt: null },
    });
  });

  it('restore 400 when mono was never trashed', async () => {
    const findFirst = jest.fn().mockResolvedValue({ id: monoId, trashedAt: null });
    const prisma = { publishedMono: { findFirst, updateMany: jest.fn() } } as any;

    await expect(
      new PublishedMonosService(prisma).restorePublishedMono(ownerId, monoId),
    ).rejects.toMatchObject({ status: 400 });
  });
});

describe('PublishedMonosService permanent delete', () => {
  const ownerId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  const monoId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const t0 = new Date('2026-04-01T12:00:00.000Z');

  function prismaWithTx(impl: (tx: any) => Promise<void>) {
    return {
      $transaction: jest.fn().mockImplementation(impl),
    } as any;
  }

  it('requires confirm body', async () => {
    const prisma = prismaWithTx(async () => {});
    await expect(
      new PublishedMonosService(prisma).permanentlyDeletePublishedMono(
        ownerId,
        monoId,
        'NOPE',
      ),
    ).rejects.toMatchObject({ status: HttpStatus.BAD_REQUEST });
  });

  it('404 when missing/not owner', async () => {
    const tx = {
      publishedMono: { findFirst: jest.fn().mockResolvedValue(null) },
      storyDraft: { deleteMany: jest.fn() },
    };
    const prisma = prismaWithTx(async (fn) => fn(tx));

    await expect(
      new PublishedMonosService(prisma).permanentlyDeletePublishedMono(
        ownerId,
        monoId,
        'DELETE',
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('400 when row is not trashed', async () => {
    const tx = {
      publishedMono: {
        findFirst: jest.fn().mockResolvedValue({ id: monoId, trashedAt: null }),
        deleteMany: jest.fn(),
      },
      storyDraft: { deleteMany: jest.fn() },
    };
    const prisma = prismaWithTx(async (fn) => fn(tx));

    await expect(
      new PublishedMonosService(prisma).permanentlyDeletePublishedMono(
        ownerId,
        monoId,
        'DELETE',
      ),
    ).rejects.toMatchObject({ status: HttpStatus.BAD_REQUEST });
    expect(tx.storyDraft.deleteMany).not.toHaveBeenCalled();
    expect(tx.publishedMono.deleteMany).not.toHaveBeenCalled();
  });

  it('deletes linked drafts then deletes mono (trashed only)', async () => {
    const tx = {
      publishedMono: {
        findFirst: jest.fn().mockResolvedValue({ id: monoId, trashedAt: t0 }),
        deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      storyDraft: { deleteMany: jest.fn().mockResolvedValue({ count: 2 }) },
    };
    const prisma = prismaWithTx(async (fn) => fn(tx));

    await new PublishedMonosService(prisma).permanentlyDeletePublishedMono(
      ownerId,
      monoId,
      'DELETE',
    );

    expect(tx.storyDraft.deleteMany).toHaveBeenCalledWith({
      where: { ownerId, publishedMonoId: monoId },
    });
    expect(tx.publishedMono.deleteMany).toHaveBeenCalledWith({
      where: { ownerId, id: monoId },
    });
  });
});
