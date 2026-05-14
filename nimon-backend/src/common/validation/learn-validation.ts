import {
  charLength,
  containsHtmlOrScript,
  containsUrl,
  normalizeSingleLineText,
  trimText,
} from './text-normalization';
import type { ValidationIssue } from './validation-issue';
import { ValidationMode } from './validation-mode';
import { ValidationSeverity } from './validation-severity';
import { ok, resultFromIssues } from './validation-result';
import type { ValidationResult } from './validation-result';
import type { JlptLevel, StoryDurationBand } from './story-validation';

export type VocabBandLimits = { min: number; max: number };
export type GrammarBandLimits = { min: number; max: number };
export type QuizBandLimits = { min: number; max: number; absoluteMax: number };

export const VOCABULARY_LIMITS: Record<
  JlptLevel,
  Record<StoryDurationBand, VocabBandLimits>
> = {
  N5: {
    '3_5': { min: 8, max: 18 },
    '5_7': { min: 12, max: 28 },
    '7_9': { min: 18, max: 40 },
  },
  N4: {
    '3_5': { min: 10, max: 22 },
    '5_7': { min: 15, max: 32 },
    '7_9': { min: 22, max: 45 },
  },
  N3: {
    '3_5': { min: 12, max: 25 },
    '5_7': { min: 18, max: 38 },
    '7_9': { min: 25, max: 55 },
  },
  N2: {
    '3_5': { min: 10, max: 24 },
    '5_7': { min: 16, max: 36 },
    '7_9': { min: 22, max: 50 },
  },
  N1: {
    '3_5': { min: 8, max: 20 },
    '5_7': { min: 14, max: 32 },
    '7_9': { min: 20, max: 45 },
  },
};

export const GRAMMAR_PATTERN_LIMITS: Record<
  JlptLevel,
  Record<StoryDurationBand, GrammarBandLimits>
> = {
  N5: {
    '3_5': { min: 3, max: 5 },
    '5_7': { min: 4, max: 7 },
    '7_9': { min: 5, max: 9 },
  },
  N4: {
    '3_5': { min: 4, max: 6 },
    '5_7': { min: 5, max: 8 },
    '7_9': { min: 6, max: 10 },
  },
  N3: {
    '3_5': { min: 4, max: 7 },
    '5_7': { min: 6, max: 9 },
    '7_9': { min: 7, max: 12 },
  },
  N2: {
    '3_5': { min: 3, max: 6 },
    '5_7': { min: 5, max: 8 },
    '7_9': { min: 6, max: 10 },
  },
  N1: {
    '3_5': { min: 3, max: 5 },
    '5_7': { min: 4, max: 7 },
    '7_9': { min: 5, max: 9 },
  },
};

export const QUIZ_LIMITS: Record<
  JlptLevel,
  Record<StoryDurationBand, QuizBandLimits>
> = {
  N5: {
    '3_5': { min: 6, max: 10, absoluteMax: 18 },
    '5_7': { min: 9, max: 14, absoluteMax: 18 },
    '7_9': { min: 12, max: 18, absoluteMax: 18 },
  },
  N4: {
    '3_5': { min: 7, max: 11, absoluteMax: 20 },
    '5_7': { min: 10, max: 16, absoluteMax: 20 },
    '7_9': { min: 14, max: 20, absoluteMax: 20 },
  },
  N3: {
    '3_5': { min: 8, max: 12, absoluteMax: 24 },
    '5_7': { min: 12, max: 18, absoluteMax: 24 },
    '7_9': { min: 16, max: 24, absoluteMax: 24 },
  },
  N2: {
    '3_5': { min: 7, max: 11, absoluteMax: 22 },
    '5_7': { min: 10, max: 16, absoluteMax: 22 },
    '7_9': { min: 14, max: 22, absoluteMax: 22 },
  },
  N1: {
    '3_5': { min: 6, max: 10, absoluteMax: 20 },
    '5_7': { min: 9, max: 15, absoluteMax: 20 },
    '7_9': { min: 12, max: 20, absoluteMax: 20 },
  },
};

/** Product-wide ceiling for quiz items (matches N3 upper band). */
export const QUIZ_GLOBAL_HARD_MAX = 24;

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
    source: 'learn-validation',
    params,
  };
}

const KANJI_RE = /[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF々〇]/u;

export function containsKanji(text: string): boolean {
  return KANJI_RE.test(text);
}

/** Kana + middle dot + slash for furigana readings (no kanji/romaji/digits). */
const FURIGANA_ALLOWED =
  /^[\u3041-\u3096\u30A1-\u30FC\u30FB\u002F\uFF0F]+$/u;

export function validateVocabularyMeaning(
  raw: string | null | undefined,
  mode: ValidationMode,
): ValidationResult {
  const normalized = normalizeSingleLineText(trimText(raw ?? ''));
  const fullLearn = mode === ValidationMode.FullLearnPublish;

  if (!normalized) {
    if (fullLearn) {
      return resultFromIssues([
        blocking(
          'learn.vocab.meaning',
          'learn.vocab.meaning.required',
          'learn.vocab.meaning.required',
        ),
      ]);
    }
    return ok();
  }

  const issues: ValidationIssue[] = [];
  const len = charLength(normalized);
  if (len < 1 || len > 80) {
    issues.push(
      blocking(
        'learn.vocab.meaning',
        'learn.vocab.meaning.length',
        'learn.vocab.meaning.length',
        { min: 1, max: 80, actual: len },
      ),
    );
  }

  if (/\p{Extended_Pictographic}/u.test(normalized)) {
    issues.push(
      blocking(
        'learn.vocab.meaning',
        'learn.vocab.meaning.noEmoji',
        'learn.vocab.meaning.noEmoji',
      ),
    );
  }

  if (/[\r\n]/.test(trimText(raw ?? ''))) {
    issues.push(
      blocking(
        'learn.vocab.meaning',
        'learn.vocab.meaning.lineBreak',
        'learn.vocab.meaning.lineBreak',
      ),
    );
  }

  if (containsHtmlOrScript(normalized)) {
    issues.push(
      blocking(
        'learn.vocab.meaning',
        'learn.vocab.meaning.unsafe',
        'learn.vocab.meaning.unsafe',
      ),
    );
  }

  if (containsUrl(normalized)) {
    issues.push(
      blocking(
        'learn.vocab.meaning',
        'learn.vocab.meaning.noUrl',
        'learn.vocab.meaning.noUrl',
      ),
    );
  }

  if (/#/.test(normalized)) {
    issues.push(
      blocking(
        'learn.vocab.meaning',
        'learn.vocab.meaning.noHashtag',
        'learn.vocab.meaning.noHashtag',
      ),
    );
  }

  return resultFromIssues(issues);
}

export type FuriganaKind = 'kanji' | 'kana';

export function validateFuriganaReading(
  raw: string | null | undefined,
  surfaceText: string,
  kind: FuriganaKind,
): ValidationResult {
  const normalized = normalizeSingleLineText(trimText(raw ?? ''));
  const needReading =
    kind === 'kanji' || containsKanji(trimText(surfaceText));

  if (!normalized) {
    if (needReading) {
      return resultFromIssues([
        blocking(
          'learn.vocab.reading',
          'learn.vocab.reading.required',
          'learn.vocab.reading.required',
        ),
      ]);
    }
    return ok();
  }

  const issues: ValidationIssue[] = [];
  const len = charLength(normalized);
  if (len > 40) {
    issues.push(
      blocking(
        'learn.vocab.reading',
        'learn.vocab.reading.tooLong',
        'learn.vocab.reading.tooLong',
        { max: 40, actual: len },
      ),
    );
  }

  const segmentCount = normalized.split('/').filter((s) => s.trim().length > 0).length;
  if (segmentCount > 3) {
    issues.push(
      blocking(
        'learn.vocab.reading',
        'learn.vocab.reading.tooManyAlternatives',
        'learn.vocab.reading.tooManyAlternatives',
        { max: 3, actual: segmentCount },
      ),
    );
  }

  if (!FURIGANA_ALLOWED.test(normalized)) {
    issues.push(
      blocking(
        'learn.vocab.reading',
        'learn.vocab.reading.invalidChars',
        'learn.vocab.reading.invalidChars',
      ),
    );
  }

  if (containsHtmlOrScript(normalized)) {
    issues.push(
      blocking(
        'learn.vocab.reading',
        'learn.vocab.reading.unsafe',
        'learn.vocab.reading.unsafe',
      ),
    );
  }

  return resultFromIssues(issues);
}

export function validateGrammarPatternTitle(raw: string | null | undefined): ValidationResult {
  const normalized = normalizeSingleLineText(trimText(raw ?? ''));
  if (!normalized) {
    return resultFromIssues([
      blocking(
        'learn.grammar.title',
        'learn.grammar.title.required',
        'learn.grammar.title.required',
      ),
    ]);
  }

  const issues: ValidationIssue[] = [];
  const len = charLength(normalized);
  if (len < 2 || len > 40) {
    issues.push(
      blocking(
        'learn.grammar.title',
        'learn.grammar.title.length',
        'learn.grammar.title.length',
        { min: 2, max: 40, actual: len },
      ),
    );
  }

  if (/\p{Extended_Pictographic}/u.test(normalized)) {
    issues.push(
      blocking(
        'learn.grammar.title',
        'learn.grammar.title.noEmoji',
        'learn.grammar.title.noEmoji',
      ),
    );
  }

  if (/[\r\n]/.test(trimText(raw ?? ''))) {
    issues.push(
      blocking(
        'learn.grammar.title',
        'learn.grammar.title.lineBreak',
        'learn.grammar.title.lineBreak',
      ),
    );
  }

  if (containsHtmlOrScript(normalized)) {
    issues.push(
      blocking(
        'learn.grammar.title',
        'learn.grammar.title.unsafe',
        'learn.grammar.title.unsafe',
      ),
    );
  }

  if (containsUrl(normalized)) {
    issues.push(
      blocking(
        'learn.grammar.title',
        'learn.grammar.title.noUrl',
        'learn.grammar.title.noUrl',
      ),
    );
  }

  return resultFromIssues(issues);
}

export type QuizCategory = 'Vocabulary' | 'Grammar' | 'Sentence';

export function validateQuizItem(
  input: {
    category: string;
    question: string;
    options: string[];
    correctAnswer: string;
  },
  ctx?: { existingQuestionsNormalized?: Set<string> },
): ValidationResult {
  const issues: ValidationIssue[] = [];
  const cat = trimText(input.category);
  const allowed: QuizCategory[] = ['Vocabulary', 'Grammar', 'Sentence'];
  if (!allowed.includes(cat as QuizCategory)) {
    issues.push(
      blocking(
        'learn.quiz.category',
        'learn.quiz.category.invalid',
        'learn.quiz.category.invalid',
      ),
    );
  }

  const qRaw = trimText(input.question);
  const question = normalizeSingleLineText(qRaw);
  const qLen = charLength(question);
  if (!question) {
    issues.push(
      blocking(
        'learn.quiz.question',
        'learn.quiz.question.required',
        'learn.quiz.question.required',
      ),
    );
  } else if (qLen < 5 || qLen > 120) {
    issues.push(
      blocking(
        'learn.quiz.question',
        'learn.quiz.question.length',
        'learn.quiz.question.length',
        { min: 5, max: 120, actual: qLen },
      ),
    );
  }

  if (containsHtmlOrScript(question) || containsUrl(question)) {
    issues.push(
      blocking(
        'learn.quiz.question',
        'learn.quiz.question.unsafe',
        'learn.quiz.question.unsafe',
      ),
    );
  }

  const opts = input.options ?? [];
  const normalizedOpts = opts
    .map((o) => normalizeSingleLineText(trimText(o)))
    .filter((o) => o.length > 0);
  if (normalizedOpts.length < 2 || normalizedOpts.length > 4) {
    issues.push(
      blocking(
        'learn.quiz.options',
        'learn.quiz.options.count',
        'learn.quiz.options.count',
        { min: 2, max: 4, actual: normalizedOpts.length },
      ),
    );
  }

  const uniq = new Set(normalizedOpts.map((o) => o.toLowerCase()));
  if (uniq.size !== normalizedOpts.length) {
    issues.push(
      blocking(
        'learn.quiz.options',
        'learn.quiz.options.duplicate',
        'learn.quiz.options.duplicate',
      ),
    );
  }

  const correct = normalizeSingleLineText(trimText(input.correctAnswer));
  if (!correct) {
    issues.push(
      blocking(
        'learn.quiz.answer',
        'learn.quiz.answer.required',
        'learn.quiz.answer.required',
      ),
    );
  } else if (!normalizedOpts.some((o) => o === correct)) {
    issues.push(
      blocking(
        'learn.quiz.answer',
        'learn.quiz.answer.notInOptions',
        'learn.quiz.answer.notInOptions',
      ),
    );
  }

  const correctCount = normalizedOpts.filter((o) => o === correct).length;
  if (correct && correctCount !== 1) {
    issues.push(
      blocking(
        'learn.quiz.answer',
        'learn.quiz.answer.singleCorrect',
        'learn.quiz.answer.singleCorrect',
      ),
    );
  }

  if (ctx?.existingQuestionsNormalized?.has(question.toLowerCase())) {
    issues.push(
      blocking(
        'learn.quiz.question',
        'learn.quiz.question.duplicate',
        'learn.quiz.question.duplicate',
      ),
    );
  }

  return resultFromIssues(issues);
}
