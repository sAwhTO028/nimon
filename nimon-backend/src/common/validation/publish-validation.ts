import {
  GRAMMAR_PATTERN_LIMITS,
  QUIZ_GLOBAL_HARD_MAX,
  QUIZ_LIMITS,
  VOCABULARY_LIMITS,
  validateFuriganaReading,
  validateGrammarPatternTitle,
  validateQuizItem,
  validateVocabularyMeaning,
} from './learn-validation';
import type { FuriganaKind } from './learn-validation';
import { normalizeJlptLevel, resolveStoryDurationBand } from './story-duration-band';
import { STORY_SENTENCE_LIMITS, validateStoryDescription, validateStoryTitle } from './story-validation';
import type { ValidationIssue } from './validation-issue';
import { ValidationMode } from './validation-mode';
import { ValidationSeverity } from './validation-severity';
import { combine, resultFromIssues } from './validation-result';
import type { ValidationResult } from './validation-result';
import { charLength } from './text-normalization';

export type StoryPublishValidationInput = {
  title: string | null;
  description: string | null;
  levelRaw: string | null;
  targetDurationBandKey: string | null;
  /** Optional; when not on draft row, omit — limits may be skipped. */
  durationSeconds?: number | null;
  sentences: Array<{ content: unknown }>;
  vocabEntries: Array<{ content: unknown }>;
  grammarEntries: Array<{ content: unknown }>;
  quizEntries: Array<{ content: unknown }>;
  moduleWorkflowStatuses: Record<string, string> | null;
};

function warn(field: string, code: string, messageKey: string, params?: Record<string, unknown>): ValidationIssue {
  return {
    field,
    code,
    messageKey,
    severity: ValidationSeverity.Warning,
    source: 'publish-validation',
    params,
  };
}

function block(field: string, code: string, messageKey: string, params?: Record<string, unknown>): ValidationIssue {
  return {
    field,
    code,
    messageKey,
    severity: ValidationSeverity.Blocking,
    source: 'publish-validation',
    params,
  };
}

/** Primary Japanese line for sentence body metrics (aligned with StoryDraftsService.sentenceHasJapaneseText). */
export function extractJapanesePrimaryText(content: unknown): string {
  if (!content || typeof content !== 'object') return '';
  const c = content as Record<string, unknown>;
  const candidates = [c.japanese, c.japaneseText, c.jp, c.textJa, c.text, c.value];
  for (const v of candidates) {
    if (typeof v === 'string' && v.trim().length > 0) return v.trim();
  }
  return '';
}

export function extractStorySentenceMetrics(sentences: Array<{ content: unknown }>): {
  validCount: number;
  totalJapaneseChars: number;
} {
  let validCount = 0;
  let totalJapaneseChars = 0;
  for (const s of sentences) {
    const t = extractJapanesePrimaryText(s.content);
    if (t.length > 0) {
      validCount++;
      totalJapaneseChars += charLength(t);
    }
  }
  return { validCount, totalJapaneseChars };
}

function parseVocabEntry(content: unknown): {
  termJapanese: string;
  reading: string | null;
  meaningPrimary: string;
  isKanjiType: boolean;
} {
  if (!content || typeof content !== 'object') {
    return { termJapanese: '', reading: null, meaningPrimary: '', isKanjiType: false };
  }
  const c = content as Record<string, unknown>;
  const term =
    (typeof c.termJapanese === 'string' ? c.termJapanese : null) ??
    (typeof c.term === 'string' ? c.term : '') ??
    '';
  const typ = String(c.type ?? c.entryType ?? '').toLowerCase();
  const isKanjiType = typ === 'kanji';
  const gloss = (c.glosses ?? c.meanings) as Record<string, unknown> | undefined;
  const my = gloss && typeof gloss.my === 'string' ? gloss.my : '';
  const en = gloss && typeof gloss.en === 'string' ? gloss.en : '';
  const meaningPrimary = [my.trim(), en.trim()].find((s) => s.length > 0) ?? '';
  const reading = typeof c.reading === 'string' ? c.reading : null;
  return {
    termJapanese: typeof term === 'string' ? term : '',
    reading,
    meaningPrimary,
    isKanjiType,
  };
}

function parseGrammarEntry(content: unknown): { headline: string } {
  if (!content || typeof content !== 'object') return { headline: '' };
  const c = content as Record<string, unknown>;
  const h =
    (typeof c.headline === 'string' ? c.headline : null) ??
    (typeof c.title === 'string' ? c.title : '') ??
    '';
  return { headline: typeof h === 'string' ? h : '' };
}

function mapQuizCategoryToValidatorCategory(raw: string): string {
  const k = raw.trim().toLowerCase();
  if (k === 'grammar') return 'Grammar';
  if (k === 'sample_sentence' || k === 'sentence') return 'Sentence';
  if (k === 'kanji' || k === 'vocabulary') return 'Vocabulary';
  return 'Vocabulary';
}

function parseQuizEntry(content: unknown): {
  category: string;
  question: string;
  options: string[];
  correctAnswer: string;
} | null {
  if (!content || typeof content !== 'object') return null;
  const c = content as Record<string, unknown>;
  const catRaw = String(c.category ?? 'vocabulary');
  const category = mapQuizCategoryToValidatorCategory(catRaw);
  const question =
    (typeof c.prompt === 'string' ? c.prompt : null) ??
    (typeof c.question === 'string' ? c.question : '') ??
    '';
  const optsRaw = c.options;
  const options: string[] = Array.isArray(optsRaw)
    ? optsRaw.filter((x): x is string => typeof x === 'string')
    : [];
  let correctAnswer = '';
  if (typeof c.correctAnswer === 'string') {
    correctAnswer = c.correctAnswer;
  } else if (typeof c.correctIndex === 'number' && options[c.correctIndex] != null) {
    correctAnswer = options[c.correctIndex]!;
  }
  return { category, question, options, correctAnswer };
}

function fullLearnModulesComplete(statuses: Record<string, string>): ValidationIssue | null {
  const keys = ['vocabulary_kanji', 'grammar', 'quiz', 'audio'] as const;
  for (const k of keys) {
    if ((statuses[k] ?? '').toLowerCase() !== 'completed') {
      return block(
        `module.${k}`,
        `learn.module.${k}.notCompleted`,
        `learn.module.notCompleted`,
        { module: k },
      );
    }
  }
  return null;
}

/**
 * Central publish gate: validates draft-shaped input for Read-only vs Full Learn publish.
 */
export function validateStoryPublishInput(
  input: StoryPublishValidationInput,
  mode: ValidationMode.ReadOnlyPublish | ValidationMode.FullLearnPublish,
): ValidationResult {
  const vm =
    mode === ValidationMode.ReadOnlyPublish
      ? ValidationMode.ReadOnlyPublish
      : ValidationMode.FullLearnPublish;

  const pieces: ValidationResult[] = [];

  pieces.push(validateStoryTitle(input.title, vm));

  const descRes = validateStoryDescription(input.description, vm);
  pieces.push(descRes);

  const jlpt = normalizeJlptLevel(input.levelRaw);
  const band = resolveStoryDurationBand({
    targetDurationBandKey: input.targetDurationBandKey,
    durationSeconds: input.durationSeconds ?? null,
  });

  if (!jlpt) {
    pieces.push(
      resultFromIssues([
        warn(
          'story.level',
          'story.limits.skippedNoJlpt',
          'story.limits.skippedNoJlpt',
        ),
      ]),
    );
  }
  if (!band) {
    pieces.push(
      resultFromIssues([
        warn(
          'story.duration',
          'story.limits.skippedNoBand',
          'story.limits.skippedNoBand',
        ),
      ]),
    );
  }

  const metrics = extractStorySentenceMetrics(input.sentences);
  if (metrics.validCount === 0) {
    pieces.push(
      resultFromIssues([
        block(
          'story.sentences',
          'story.sentences.required',
          'story.sentences.required',
        ),
      ]),
    );
  }

  if (jlpt && band && metrics.validCount > 0) {
    const limits = STORY_SENTENCE_LIMITS[jlpt][band];
    if (metrics.validCount < limits.minSentences) {
      pieces.push(
        resultFromIssues([
          block(
            'story.sentences',
            'story.sentences.tooFew',
            'story.sentences.tooFew',
            {
              min: limits.minSentences,
              actual: metrics.validCount,
            },
          ),
        ]),
      );
    }
    if (metrics.validCount > limits.maxSentences) {
      pieces.push(
        resultFromIssues([
          block(
            'story.sentences',
            'story.sentences.tooMany',
            'story.sentences.tooMany',
            {
              max: limits.maxSentences,
              actual: metrics.validCount,
            },
          ),
        ]),
      );
    }
    if (metrics.totalJapaneseChars > limits.maxChars) {
      pieces.push(
        resultFromIssues([
          block(
            'story.body',
            'story.body.tooLong',
            'story.body.tooLong',
            { max: limits.maxChars, actual: metrics.totalJapaneseChars },
          ),
        ]),
      );
    }
  }

  if (mode === ValidationMode.FullLearnPublish) {
    const statuses = {
      vocabulary_kanji: '',
      grammar: '',
      quiz: '',
      audio: '',
      ...(input.moduleWorkflowStatuses ?? {}),
    };
    const modIssue = fullLearnModulesComplete(statuses);
    if (modIssue) {
      pieces.push(resultFromIssues([modIssue]));
    }

    if (jlpt && band) {
      const vLimits = VOCABULARY_LIMITS[jlpt][band];
      const gLimits = GRAMMAR_PATTERN_LIMITS[jlpt][band];
      const qLimits = QUIZ_LIMITS[jlpt][band];

      const vocabCount = input.vocabEntries.filter((e) => {
        const p = parseVocabEntry(e.content);
        return p.termJapanese.trim().length > 0;
      }).length;
      const grammarCount = input.grammarEntries.filter((e) => {
        return parseGrammarEntry(e.content).headline.trim().length > 0;
      }).length;
      const quizCount = input.quizEntries.filter((e) => parseQuizEntry(e.content) != null).length;

      if (vocabCount < vLimits.min || vocabCount > vLimits.max) {
        pieces.push(
          resultFromIssues([
            block(
              'learn.vocab.count',
              'learn.count.vocab.range',
              'learn.count.vocab.range',
              { min: vLimits.min, max: vLimits.max, actual: vocabCount },
            ),
          ]),
        );
      }
      if (grammarCount < gLimits.min || grammarCount > gLimits.max) {
        pieces.push(
          resultFromIssues([
            block(
              'learn.grammar.count',
              'learn.count.grammar.range',
              'learn.count.grammar.range',
              { min: gLimits.min, max: gLimits.max, actual: grammarCount },
            ),
          ]),
        );
      }
      const qMaxAllowed = Math.min(qLimits.absoluteMax, QUIZ_GLOBAL_HARD_MAX, qLimits.max);
      if (quizCount < qLimits.min || quizCount > qMaxAllowed) {
        pieces.push(
          resultFromIssues([
            block(
              'learn.quiz.count',
              'learn.count.quiz.range',
              'learn.count.quiz.range',
              {
                min: qLimits.min,
                max: qMaxAllowed,
                actual: quizCount,
              },
            ),
          ]),
        );
      }
    }

    for (const row of input.vocabEntries) {
      const v = parseVocabEntry(row.content);
      if (!v.termJapanese.trim()) continue;

      pieces.push(validateVocabularyMeaning(v.meaningPrimary, ValidationMode.FullLearnPublish));

      const furiganaKind: FuriganaKind = v.isKanjiType ? 'kanji' : 'kana';
      pieces.push(
        validateFuriganaReading(v.reading, v.termJapanese, furiganaKind),
      );
    }

    for (const row of input.grammarEntries) {
      const g = parseGrammarEntry(row.content);
      pieces.push(validateGrammarPatternTitle(g.headline));
    }

    const seenQuestions = new Set<string>();
    for (const row of input.quizEntries) {
      const parsed = parseQuizEntry(row.content);
      if (!parsed) continue;
      const qNorm = parsed.question.trim().toLowerCase();
      pieces.push(
        validateQuizItem(
          {
            category: parsed.category,
            question: parsed.question,
            options: parsed.options,
            correctAnswer: parsed.correctAnswer,
          },
          qNorm.length > 0 ? { existingQuestionsNormalized: seenQuestions } : undefined,
        ),
      );
      if (qNorm.length > 0) seenQuestions.add(qNorm);
    }
  }

  return combine(...pieces);
}

/** Adapter for Prisma draft rows included in publish transactions. */
export function storyPublishInputFromDraftRow(draft: {
  title?: string | null;
  description?: string | null;
  level?: string | null;
  targetDurationBandKey?: string | null;
  moduleWorkflowStatuses?: unknown;
  sentences?: Array<{ content: unknown }>;
  vocabEntries?: Array<{ content: unknown }>;
  grammarEntries?: Array<{ content: unknown }>;
  quizEntries?: Array<{ content: unknown }>;
}): StoryPublishValidationInput {
  let moduleWorkflowStatuses: Record<string, string> | null = null;
  const raw = draft.moduleWorkflowStatuses;
  if (raw && typeof raw === 'object' && !Array.isArray(raw)) {
    moduleWorkflowStatuses = Object.fromEntries(
      Object.entries(raw as Record<string, unknown>).map(([k, v]) => [
        k,
        typeof v === 'string' ? v : String(v ?? ''),
      ]),
    );
  }

  return {
    title: draft.title ?? null,
    description: draft.description ?? null,
    levelRaw: draft.level ?? null,
    targetDurationBandKey: draft.targetDurationBandKey ?? null,
    durationSeconds: null,
    sentences: draft.sentences ?? [],
    vocabEntries: draft.vocabEntries ?? [],
    grammarEntries: draft.grammarEntries ?? [],
    quizEntries: draft.quizEntries ?? [],
    moduleWorkflowStatuses,
  };
}
