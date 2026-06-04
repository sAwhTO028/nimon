import { BadRequestException } from '@nestjs/common';
import type { Prisma } from '@prisma/client';

import type { PrismaService } from '../prisma/prisma.service';

export const DEFAULT_CATALOG_CONTENT_LOCALE = 'en' as const;
export const DEFAULT_CATALOG_LEARNING_LANGUAGE = 'ja' as const;

export type CatalogContentLocale = 'en' | 'my' | 'ja';
export type CatalogLearningLanguage = 'ja';

export type CatalogLanguageContext = {
  effectiveContentLocale: CatalogContentLocale;
  effectiveLearningLanguage: CatalogLearningLanguage;
};

export type CatalogLanguageResolveOptions = {
  viewerUserId: string | null;
  contentLocaleQuery?: string | null;
  learningLanguageQuery?: string | null;
};

function normalizeCode(v: string | null | undefined): string | null {
  if (v == null) return null;
  const t = String(v).trim().toLowerCase();
  return t ? t : null;
}

export function ensureAllowedContentLocaleQuery(
  v: string | null,
): CatalogContentLocale | null {
  if (v == null) return null;
  if (v === 'en' || v === 'my' || v === 'ja') return v;
  throw new BadRequestException('contentLocale_invalid');
}

export function ensureAllowedLearningLanguageQuery(
  v: string | null,
): CatalogLearningLanguage | null {
  if (v == null) return null;
  if (v === 'ja') return v;
  throw new BadRequestException('learningLanguage_invalid');
}

/** User-preference values may be invalid if written by older clients; never take down catalog surfaces. */
export function safeStoredContentLocale(
  raw: string | null | undefined,
): CatalogContentLocale {
  const n = normalizeCode(raw);
  if (n === null) return DEFAULT_CATALOG_CONTENT_LOCALE;
  if (n === 'en' || n === 'my' || n === 'ja') return n;
  return DEFAULT_CATALOG_CONTENT_LOCALE;
}

export function safeStoredLearningLanguage(
  raw: string | null | undefined,
): CatalogLearningLanguage {
  const n = normalizeCode(raw);
  if (n === null) return DEFAULT_CATALOG_LEARNING_LANGUAGE;
  if (n === 'ja') return 'ja';
  return DEFAULT_CATALOG_LEARNING_LANGUAGE;
}

/**
 * Resolves effective catalog language tags (Mono feed + public collections parity).
 * Guest: en + ja. Authenticated: UserPreference with query overrides.
 */
export async function resolveCatalogLanguageContext(
  prisma: PrismaService,
  options: CatalogLanguageResolveOptions,
): Promise<CatalogLanguageContext> {
  const contentLocaleQ = ensureAllowedContentLocaleQuery(
    normalizeCode(options.contentLocaleQuery),
  );
  const learningLanguageQ = ensureAllowedLearningLanguageQuery(
    normalizeCode(options.learningLanguageQuery),
  );

  let effectiveContentLocale: CatalogContentLocale = DEFAULT_CATALOG_CONTENT_LOCALE;
  let effectiveLearningLanguage: CatalogLearningLanguage =
    DEFAULT_CATALOG_LEARNING_LANGUAGE;

  const viewerId = (options.viewerUserId ?? '').trim();
  if (viewerId) {
    const pref = await prisma.userPreference.findUnique({
      where: { userId: viewerId },
      select: { contentLocale: true, learningLanguage: true },
    });
    effectiveContentLocale = safeStoredContentLocale(pref?.contentLocale);
    effectiveLearningLanguage = safeStoredLearningLanguage(pref?.learningLanguage);
  }

  if (contentLocaleQ) effectiveContentLocale = contentLocaleQ;
  if (learningLanguageQ) effectiveLearningLanguage = learningLanguageQ;

  return { effectiveContentLocale, effectiveLearningLanguage };
}

/** Legacy OR-null inclusion — same as MonoFeedService.listFeed. */
export function publishedMonoCatalogLocaleWhere(
  ctx: CatalogLanguageContext,
): Prisma.PublishedMonoWhereInput {
  return {
    AND: [
      {
        OR: [
          { contentLocale: ctx.effectiveContentLocale },
          { contentLocale: null },
        ],
      },
      {
        OR: [
          { learningLanguage: ctx.effectiveLearningLanguage },
          { learningLanguage: null },
        ],
      },
    ],
  };
}
