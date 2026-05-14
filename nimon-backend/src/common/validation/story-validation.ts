import {
  charLength,
  containsHtmlOrScript,
  countEmojis,
  countHashtags,
  countUrls,
  hasExcessiveRepeatedCharacters,
  isOnlyNumbers,
  isOnlySymbols,
  normalizeSingleLineText,
  trimText,
} from './text-normalization';
import type { ValidationIssue } from './validation-issue';
import { ValidationMode } from './validation-mode';
import { ValidationSeverity } from './validation-severity';
import { ok, resultFromIssues } from './validation-result';
import type { ValidationResult } from './validation-result';

export type JlptLevel = 'N5' | 'N4' | 'N3' | 'N2' | 'N1';
export type StoryDurationBand = '3_5' | '5_7' | '7_9';

export type StorySentenceBandLimits = {
  minSentences: number;
  maxSentences: number;
  maxChars: number;
};

/** Exact sentence / character bands by JLPT × duration (product table). */
export const STORY_SENTENCE_LIMITS: Record<
  JlptLevel,
  Record<StoryDurationBand, StorySentenceBandLimits>
> = {
  N5: {
    '3_5': { minSentences: 10, maxSentences: 35, maxChars: 900 },
    '5_7': { minSentences: 18, maxSentences: 50, maxChars: 1250 },
    '7_9': { minSentences: 25, maxSentences: 65, maxChars: 1600 },
  },
  N4: {
    '3_5': { minSentences: 8, maxSentences: 30, maxChars: 1000 },
    '5_7': { minSentences: 15, maxSentences: 45, maxChars: 1400 },
    '7_9': { minSentences: 22, maxSentences: 60, maxChars: 1800 },
  },
  N3: {
    '3_5': { minSentences: 7, maxSentences: 25, maxChars: 1150 },
    '5_7': { minSentences: 12, maxSentences: 38, maxChars: 1600 },
    '7_9': { minSentences: 18, maxSentences: 52, maxChars: 2100 },
  },
  N2: {
    '3_5': { minSentences: 6, maxSentences: 20, maxChars: 1300 },
    '5_7': { minSentences: 10, maxSentences: 32, maxChars: 1850 },
    '7_9': { minSentences: 15, maxSentences: 45, maxChars: 2350 },
  },
  N1: {
    '3_5': { minSentences: 5, maxSentences: 18, maxChars: 1500 },
    '5_7': { minSentences: 8, maxSentences: 28, maxChars: 2100 },
    '7_9': { minSentences: 12, maxSentences: 38, maxChars: 2700 },
  },
};

function blocking(
  field: string,
  code: string,
  messageKey: string,
  params?: Record<string, unknown>,
): ValidationIssue {
  return {
    field,
    code,
    messageKey,
    severity: ValidationSeverity.Blocking,
    source: 'story-validation',
    params,
  };
}

function warning(
  field: string,
  code: string,
  messageKey: string,
  params?: Record<string, unknown>,
): ValidationIssue {
  return {
    field,
    code,
    messageKey,
    severity: ValidationSeverity.Warning,
    source: 'story-validation',
    params,
  };
}

export function validateStoryTitle(
  raw: string | null | undefined,
  mode: ValidationMode,
): ValidationResult {
  const normalized = normalizeSingleLineText(trimText(raw ?? ''));
  const publishLike =
    mode === ValidationMode.ReadOnlyPublish ||
    mode === ValidationMode.FullLearnPublish;

  if (!normalized) {
    if (publishLike) {
      return resultFromIssues([
        blocking(
          'story.title',
          'story.title.required',
          'story.title.required',
        ),
      ]);
    }
    return resultFromIssues([
      warning('story.title', 'story.title.empty', 'story.title.recommended'),
    ]);
  }

  /** Draft saves stay lenient on length/style; block dangerous patterns only. */
  if (mode === ValidationMode.Draft) {
    const draftIssues: ValidationIssue[] = [];
    if (containsHtmlOrScript(normalized)) {
      draftIssues.push(
        blocking(
          'story.title',
          'story.title.unsafe',
          'story.title.unsafe',
        ),
      );
    }
    if (/[\r\n]/.test(trimText(raw ?? ''))) {
      draftIssues.push(
        blocking(
          'story.title',
          'story.title.lineBreak',
          'story.title.lineBreak',
        ),
      );
    }
    return resultFromIssues(draftIssues);
  }

  const issues: ValidationIssue[] = [];
  const len = charLength(normalized);
  if (len < 5) {
    issues.push(
      blocking(
        'story.title',
        'story.title.tooShort',
        'story.title.tooShort',
        { min: 5, actual: len },
      ),
    );
  }
  if (len > 80) {
    issues.push(
      blocking(
        'story.title',
        'story.title.tooLong',
        'story.title.tooLong',
        { max: 80, actual: len },
      ),
    );
  }

  if (containsHtmlOrScript(normalized)) {
    issues.push(
      blocking(
        'story.title',
        'story.title.unsafe',
        'story.title.unsafe',
      ),
    );
  }

  if (/[\r\n]/.test(trimText(raw ?? ''))) {
    issues.push(
      blocking(
        'story.title',
        'story.title.lineBreak',
        'story.title.lineBreak',
      ),
    );
  }

  const emojis = countEmojis(normalized);
  if (emojis > 1) {
    issues.push(
      blocking(
        'story.title',
        'story.title.tooManyEmoji',
        'story.title.tooManyEmoji',
        { max: 1, actual: emojis },
      ),
    );
  }

  if (isOnlyNumbers(normalized)) {
    issues.push(
      blocking(
        'story.title',
        'story.title.onlyNumbers',
        'story.title.onlyNumbers',
      ),
    );
  }

  if (isOnlySymbols(normalized)) {
    issues.push(
      blocking(
        'story.title',
        'story.title.onlySymbols',
        'story.title.onlySymbols',
      ),
    );
  }

  if (hasExcessiveRepeatedCharacters(normalized, 4)) {
    issues.push(
      blocking(
        'story.title',
        'story.title.excessiveRepeat',
        'story.title.excessiveRepeat',
      ),
    );
  }

  return resultFromIssues(issues.length ? issues : []);
}

export function validateStoryDescription(
  raw: string | null | undefined,
  mode: ValidationMode,
): ValidationResult {
  const normalized = normalizeSingleLineText(trimText(raw ?? ''));
  if (!normalized) {
    if (
      mode === ValidationMode.ReadOnlyPublish ||
      mode === ValidationMode.FullLearnPublish
    ) {
      return resultFromIssues([
        warning(
          'story.description',
          'story.description.recommended',
          'story.description.recommended',
        ),
      ]);
    }
    return ok();
  }

  /** Draft saves stay lenient on publish-oriented rules; block dangerous patterns only. */
  if (mode === ValidationMode.Draft) {
    const draftIssues: ValidationIssue[] = [];
    if (containsHtmlOrScript(normalized)) {
      draftIssues.push(
        blocking(
          'story.description',
          'story.description.unsafe',
          'story.description.unsafe',
        ),
      );
    }
    if (/[\r\n]/.test(trimText(raw ?? ''))) {
      draftIssues.push(
        blocking(
          'story.description',
          'story.description.lineBreak',
          'story.description.lineBreak',
        ),
      );
    }
    return resultFromIssues(draftIssues);
  }

  const issues: ValidationIssue[] = [];
  const len = charLength(normalized);
  if (len > 160) {
    issues.push(
      blocking(
        'story.description',
        'story.description.tooLong',
        'story.description.tooLong',
        { max: 160, actual: len },
      ),
    );
  }

  if (containsHtmlOrScript(normalized)) {
    issues.push(
      blocking(
        'story.description',
        'story.description.unsafe',
        'story.description.unsafe',
      ),
    );
  }

  if (/[\r\n]/.test(trimText(raw ?? ''))) {
    issues.push(
      blocking(
        'story.description',
        'story.description.lineBreak',
        'story.description.lineBreak',
      ),
    );
  }

  if (countUrls(normalized) > 1) {
    issues.push(
      blocking(
        'story.description',
        'story.description.tooManyUrls',
        'story.description.tooManyUrls',
      ),
    );
  }

  const tags = countHashtags(normalized);
  if (tags > 4) {
    issues.push(
      blocking(
        'story.description',
        'story.description.hashtagStuffing',
        'story.description.hashtagStuffing',
        { max: 4, actual: tags },
      ),
    );
  }

  const emojis = countEmojis(normalized);
  if (emojis > 2) {
    issues.push(
      blocking(
        'story.description',
        'story.description.tooManyEmoji',
        'story.description.tooManyEmoji',
        { max: 2, actual: emojis },
      ),
    );
  }

  if (hasExcessiveRepeatedCharacters(normalized, 4)) {
    issues.push(
      blocking(
        'story.description',
        'story.description.excessiveRepeat',
        'story.description.excessiveRepeat',
      ),
    );
  }

  return resultFromIssues(issues);
}

/** Draft update helper: normalize title/description for storage (does not validate publish). */
export function normalizeStoryDraftTextFields(input: {
  title?: string | null;
  description?: string | null;
}): { title?: string | null; description?: string | null } {
  const out: { title?: string | null; description?: string | null } = {};
  if (input.title !== undefined) {
    const t = trimText(input.title);
    out.title = t === '' ? null : normalizeSingleLineText(t);
  }
  if (input.description !== undefined) {
    const d = trimText(input.description);
    out.description = d === '' ? null : normalizeSingleLineText(d);
  }
  return out;
}
