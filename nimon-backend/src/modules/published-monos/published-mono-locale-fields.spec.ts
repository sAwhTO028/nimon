import { PublishedMonosService } from './published-monos.service';
import {
  publishedMonoListItemFromCatalogSummaryRow,
  publishedMonoListItemFromRow,
} from './published-mono-common';

const ownerId = '00000000-0000-4000-8000-000000000001';
const monoId = '11111111-1111-4111-8111-000000000001';

function mkMedia() {
  return {
    mediaPublicBaseUrl: () => 'https://media.test',
    url: (u: string | null) => u,
  } as any;
}

function mkPublicWeb() {
  return { monoShareUrl: (id: string) => `https://web.test/mono/${id}` } as any;
}

describe('M22F-1 published mono locale fields', () => {
  it('publishedMonoListItemFromRow maps contentLocale and learningLanguage', () => {
    const dto = publishedMonoListItemFromRow(
      {
        id: monoId,
        ownerId,
        title: 'T',
        category: '',
        level: 'N5',
        description: '',
        createdAt: new Date('2026-01-01T00:00:00.000Z'),
        updatedAt: new Date('2026-01-02T00:00:00.000Z'),
        content: {},
        contentLocale: 'my',
        learningLanguage: 'ja',
      },
      'https://media.test',
    );
    expect(dto.contentLocale).toBe('my');
    expect(dto.learningLanguage).toBe('ja');
  });

  it('publishedMonoListItemFromRow serializes null legacy locales', () => {
    const dto = publishedMonoListItemFromRow(
      {
        id: monoId,
        ownerId,
        title: 'T',
        category: '',
        level: '',
        description: '',
        createdAt: new Date(),
        updatedAt: new Date(),
        content: {},
        contentLocale: null,
        learningLanguage: null,
      },
      'https://media.test',
    );
    expect(dto.contentLocale).toBeNull();
    expect(dto.learningLanguage).toBeNull();
  });

  it('publishedMonoListItemFromCatalogSummaryRow maps locale columns', () => {
    const dto = publishedMonoListItemFromCatalogSummaryRow(
      {
        id: monoId,
        ownerId,
        title: 'T',
        category: '',
        level: '',
        description: '',
        createdAt: new Date(),
        updatedAt: new Date(),
        contentLocale: 'en',
        learningLanguage: 'ja',
      },
      'https://media.test',
    );
    expect(dto.contentLocale).toBe('en');
    expect(dto.learningLanguage).toBe('ja');
  });

  it('listPublishedMonos returns contentLocale and learningLanguage on items', async () => {
    const row = {
      id: monoId,
      ownerId,
      title: 'T',
      category: '',
      level: 'N4',
      description: '',
      createdAt: new Date('2026-01-01T00:00:00.000Z'),
      updatedAt: new Date('2026-01-02T00:00:00.000Z'),
      content: {},
      contentLocale: 'my',
      learningLanguage: 'ja',
    };
    const prisma = {
      publishedMono: {
        findMany: jest.fn().mockResolvedValue([row]),
        count: jest.fn().mockResolvedValue(1),
      },
      userProfile: {
        findUnique: jest.fn().mockResolvedValue(null),
      },
    } as any;

    const out = await new PublishedMonosService(prisma, mkMedia(), mkPublicWeb()).listPublishedMonos(
      ownerId,
    );

    expect(out.items).toHaveLength(1);
    expect(out.items[0]?.contentLocale).toBe('my');
    expect(out.items[0]?.learningLanguage).toBe('ja');
    expect(prisma.publishedMono.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        select: expect.objectContaining({
          contentLocale: true,
          learningLanguage: true,
        }),
      }),
    );
  });
});
