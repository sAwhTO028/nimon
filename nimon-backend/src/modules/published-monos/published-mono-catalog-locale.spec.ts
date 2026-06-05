import { BadRequestException } from '@nestjs/common';
import {
  publishedMonoCatalogLocaleWhere,
  resolveCatalogLanguageContext,
  safeStoredContentLocale,
  safeStoredLearningLanguage,
  ensureAllowedLearningLanguageQuery,
} from './published-mono-catalog-locale';

describe('published-mono-catalog-locale', () => {
  it('publishedMonoCatalogLocaleWhere matches feed OR-null rule', () => {
    expect(publishedMonoCatalogLocaleWhere({
      effectiveContentLocale: 'my',
      effectiveLearningLanguage: 'ja',
    })).toEqual({
      AND: [
        { OR: [{ contentLocale: 'my' }, { contentLocale: null }] },
        { OR: [{ learningLanguage: 'ja' }, { learningLanguage: null }] },
      ],
    });
  });

  it('resolveCatalogLanguageContext uses guest defaults without viewer', async () => {
    const prisma = { userPreference: { findUnique: jest.fn() } } as any;
    const ctx = await resolveCatalogLanguageContext(prisma, { viewerUserId: null });
    expect(ctx).toEqual({
      effectiveContentLocale: 'en',
      effectiveLearningLanguage: 'ja',
    });
    expect(prisma.userPreference.findUnique).not.toHaveBeenCalled();
  });

  it('resolveCatalogLanguageContext reads prefs for authenticated viewer', async () => {
    const prisma = {
      userPreference: {
        findUnique: jest.fn().mockResolvedValue({
          contentLocale: 'my',
          learningLanguage: 'ja',
        }),
      },
    } as any;
    const ctx = await resolveCatalogLanguageContext(prisma, {
      viewerUserId: 'u1',
    });
    expect(ctx.effectiveContentLocale).toBe('my');
  });

  it('query override wins over prefs', async () => {
    const prisma = {
      userPreference: {
        findUnique: jest.fn().mockResolvedValue({
          contentLocale: 'my',
          learningLanguage: 'ja',
        }),
      },
    } as any;
    const ctx = await resolveCatalogLanguageContext(prisma, {
      viewerUserId: 'u1',
      contentLocaleQuery: 'en',
    });
    expect(ctx.effectiveContentLocale).toBe('en');
  });

  it('rejects invalid contentLocale query', async () => {
    const prisma = { userPreference: { findUnique: jest.fn() } } as any;
    await expect(
      resolveCatalogLanguageContext(prisma, {
        viewerUserId: null,
        contentLocaleQuery: 'th',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('safeStoredContentLocale falls back for invalid stored', () => {
    expect(safeStoredContentLocale('xx')).toBe('en');
  });

  it('publishedMonoCatalogLocaleWhere supports en learning language', () => {
    expect(publishedMonoCatalogLocaleWhere({
      effectiveContentLocale: 'my',
      effectiveLearningLanguage: 'en',
    })).toEqual({
      AND: [
        { OR: [{ contentLocale: 'my' }, { contentLocale: null }] },
        { OR: [{ learningLanguage: 'en' }, { learningLanguage: null }] },
      ],
    });
  });

  it('safeStoredLearningLanguage preserves en and ja', () => {
    expect(safeStoredLearningLanguage('en')).toBe('en');
    expect(safeStoredLearningLanguage('ja')).toBe('ja');
    expect(safeStoredLearningLanguage(null)).toBe('ja');
    expect(safeStoredLearningLanguage('ko')).toBe('ja');
  });

  it('ensureAllowedLearningLanguageQuery accepts en and rejects ko', () => {
    expect(ensureAllowedLearningLanguageQuery('en')).toBe('en');
    expect(ensureAllowedLearningLanguageQuery('ja')).toBe('ja');
    expect(() => ensureAllowedLearningLanguageQuery('ko')).toThrow(
      BadRequestException,
    );
  });

  it('resolveCatalogLanguageContext preserves en prefs for authenticated viewer', async () => {
    const prisma = {
      userPreference: {
        findUnique: jest.fn().mockResolvedValue({
          contentLocale: 'my',
          learningLanguage: 'en',
        }),
      },
    } as any;
    const ctx = await resolveCatalogLanguageContext(prisma, {
      viewerUserId: 'u-en',
    });
    expect(ctx).toEqual({
      effectiveContentLocale: 'my',
      effectiveLearningLanguage: 'en',
    });
  });

  it('learningLanguage query override en wins over ja prefs', async () => {
    const prisma = {
      userPreference: {
        findUnique: jest.fn().mockResolvedValue({
          contentLocale: 'my',
          learningLanguage: 'ja',
        }),
      },
    } as any;
    const ctx = await resolveCatalogLanguageContext(prisma, {
      viewerUserId: 'u1',
      learningLanguageQuery: 'en',
      contentLocaleQuery: 'my',
    });
    expect(ctx.effectiveLearningLanguage).toBe('en');
    expect(ctx.effectiveContentLocale).toBe('my');
  });

  it('rejects invalid learningLanguage query', async () => {
    const prisma = { userPreference: { findUnique: jest.fn() } } as any;
    await expect(
      resolveCatalogLanguageContext(prisma, {
        viewerUserId: null,
        learningLanguageQuery: 'ko',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
