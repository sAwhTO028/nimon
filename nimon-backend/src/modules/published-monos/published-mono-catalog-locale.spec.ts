import { BadRequestException } from '@nestjs/common';
import {
  publishedMonoCatalogLocaleWhere,
  resolveCatalogLanguageContext,
  safeStoredContentLocale,
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
});
