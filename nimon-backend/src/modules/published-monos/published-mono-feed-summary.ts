/**
 * M22B: denormalized feed summary fields derived from `published_monos.content`.
 * Used on publish/write and for `GET /v1/mono/feed` list (no `content` select).
 */

export type PublishedMonoFeedSummaryFields = {
  coverImageUrl: string | null;
  publishKind: string | null;
  hasAudio: boolean;
  sentenceCount: number | null;
  vocabCount: number | null;
  grammarCount: number | null;
  quizCount: number | null;
};

function nonEmptyString(v: unknown): string | null {
  if (typeof v !== 'string') return null;
  const t = v.trim();
  return t.length > 0 ? t : null;
}

function arrayLength(v: unknown): number | null {
  if (!Array.isArray(v)) return null;
  return v.length;
}

/**
 * Extracts feed summary from a published content JSON blob (same rules as legacy feed parser).
 */
export function feedSummaryFromContent(content: unknown): PublishedMonoFeedSummaryFields {
  const c = (content ?? {}) as Record<string, unknown>;
  const publishKind = nonEmptyString(c.publishKind);

  const core =
    c.core && typeof c.core === 'object'
      ? (c.core as Record<string, unknown>)
      : {};
  const coverImageUrl = nonEmptyString(core.coverImageUrl);
  const sentenceCount = arrayLength(core.sentences);

  const learn =
    c.learn && typeof c.learn === 'object'
      ? (c.learn as Record<string, unknown>)
      : {};
  const vocab =
    learn.vocabularyKanji && typeof learn.vocabularyKanji === 'object'
      ? (learn.vocabularyKanji as Record<string, unknown>)
      : {};
  const grammar =
    learn.grammar && typeof learn.grammar === 'object'
      ? (learn.grammar as Record<string, unknown>)
      : {};
  const quiz =
    learn.quiz && typeof learn.quiz === 'object'
      ? (learn.quiz as Record<string, unknown>)
      : {};
  const audio =
    learn.audio && typeof learn.audio === 'object'
      ? (learn.audio as Record<string, unknown>)
      : {};
  const storyAudio =
    audio.storyAudio && typeof audio.storyAudio === 'object'
      ? (audio.storyAudio as Record<string, unknown>)
      : null;
  const sourceUrl = nonEmptyString(storyAudio?.sourceUrl);
  const hasAudio = sourceUrl != null;

  return {
    coverImageUrl,
    publishKind,
    hasAudio,
    sentenceCount,
    vocabCount: arrayLength(vocab.entries),
    grammarCount: arrayLength(grammar.entries),
    quizCount: arrayLength(quiz.entries),
  };
}

/**
 * Derives feed summary directly from draft rows (used when writing `content` on publish).
 */
export function feedSummaryFromDraft(
  draft: {
    coverImageUrl?: string | null;
    sentences?: unknown[] | null;
    vocabEntries?: unknown[] | null;
    grammarEntries?: unknown[] | null;
    quizEntries?: unknown[] | null;
    audios?: Array<{ kind?: string; content?: unknown }> | null;
  },
  publishKind: string,
): PublishedMonoFeedSummaryFields {
  const storyAudioRow = (draft.audios ?? []).find((a) => a?.kind === 'storyAudio');
  const storyAudio =
    storyAudioRow?.content && typeof storyAudioRow.content === 'object'
      ? (storyAudioRow.content as Record<string, unknown>)
      : null;
  const sourceUrl = nonEmptyString(storyAudio?.sourceUrl);

  return {
    coverImageUrl: nonEmptyString(draft.coverImageUrl),
    publishKind: nonEmptyString(publishKind),
    hasAudio: sourceUrl != null,
    sentenceCount: arrayLength(draft.sentences),
    vocabCount: arrayLength(draft.vocabEntries),
    grammarCount: arrayLength(draft.grammarEntries),
    quizCount: arrayLength(draft.quizEntries),
  };
}

/** Prisma `PublishedMono` create/update data fragment for denormalized columns. */
export function prismaFeedSummaryData(
  fields: PublishedMonoFeedSummaryFields,
): {
  coverImageUrl: string | null;
  publishKind: string | null;
  hasAudio: boolean;
  sentenceCount: number | null;
  vocabCount: number | null;
  grammarCount: number | null;
  quizCount: number | null;
} {
  return {
    coverImageUrl: fields.coverImageUrl,
    publishKind: fields.publishKind,
    hasAudio: fields.hasAudio,
    sentenceCount: fields.sentenceCount,
    vocabCount: fields.vocabCount,
    grammarCount: fields.grammarCount,
    quizCount: fields.quizCount,
  };
}
