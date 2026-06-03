import { BadRequestException } from '@nestjs/common';

/** V1 wire codes — `contentLocale` is community / audience language. */
export type V1ContentLocale = 'en' | 'my' | 'ja';

/** V1 wire codes — target language being learned. */
export type V1LearningLanguage = 'ja';

const DEFAULT_CONTENT_LOCALE: V1ContentLocale = 'en';
const DEFAULT_LEARNING_LANGUAGE: V1LearningLanguage = 'ja';

export function normalizeV1ContentLocale(
  raw: string | null | undefined,
): V1ContentLocale | null {
  if (raw == null) return null;
  const t = String(raw).trim().toLowerCase();
  if (!t) return null;
  if (t === 'en' || t === 'my' || t === 'ja') return t;
  return null;
}

export function normalizeV1LearningLanguage(
  raw: string | null | undefined,
): V1LearningLanguage | null {
  if (raw == null) return null;
  const t = String(raw).trim().toLowerCase();
  if (!t) return null;
  if (t === 'ja') return 'ja';
  return null;
}

export function safeV1ContentLocale(raw: string | null | undefined): V1ContentLocale {
  return normalizeV1ContentLocale(raw) ?? DEFAULT_CONTENT_LOCALE;
}

export function safeV1LearningLanguage(
  raw: string | null | undefined,
): V1LearningLanguage {
  return normalizeV1LearningLanguage(raw) ?? DEFAULT_LEARNING_LANGUAGE;
}

/**
 * V1 invariant: community (`contentLocale`) must differ from learning target.
 * Blocks ja+ja and en+en (when en learning is supported later).
 */
export function assertDistinctLanguagePair(
  contentLocale: V1ContentLocale,
  learningLanguage: V1LearningLanguage,
): void {
  if (contentLocale === learningLanguage) {
    throw new BadRequestException('language_pair_same_not_allowed');
  }
}

export type ResolvedPublishLanguageTags = {
  contentLocale: V1ContentLocale;
  learningLanguage: V1LearningLanguage;
};

export function resolvePublishLanguageTags(input: {
  draftContentLocale?: string | null;
  draftLearningLanguage?: string | null;
  prefContentLocale?: string | null;
  prefLearningLanguage?: string | null;
}): ResolvedPublishLanguageTags {
  const contentLocale = safeV1ContentLocale(
    normalizeV1ContentLocale(input.draftContentLocale) != null
      ? input.draftContentLocale
      : input.prefContentLocale,
  );
  const learningLanguage = safeV1LearningLanguage(
    normalizeV1LearningLanguage(input.draftLearningLanguage) != null
      ? input.draftLearningLanguage
      : input.prefLearningLanguage,
  );
  assertDistinctLanguagePair(contentLocale, learningLanguage);
  return { contentLocale, learningLanguage };
}
