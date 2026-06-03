import {
  validateFuriganaReading,
  validateGrammarPatternTitle,
  validateQuizItem,
  validateVocabularyMeaning,
} from './learn-validation';
import type { FuriganaKind } from './learn-validation';
import { resolveStoryDurationBand } from './story-duration-band';
import { validateStoryDescription, validateStoryTitle } from './story-validation';
import type { ValidationIssue } from './validation-issue';
import { ValidationMode } from './validation-mode';
import { ValidationSeverity } from './validation-severity';
import { combine, resultFromIssues } from './validation-result';
import type { ValidationResult } from './validation-result';
import { charLength } from './text-normalization';
import {
  normalizeHtmlDuration,
  normalizeHtmlLevel,
  sentenceLimit,
  selectedFullLearnLimits,
  vocabularyLimit,
  grammarLimit,
  quizLimit,
} from '../limits/html-generator-limits';
import type { HtmlLearningLanguage, HtmlPromptMode, HtmlLimitPreset } from '../limits/html-generator-limits';

export type StoryPublishValidationInput = {
  title: string | null;
  description: string | null;
  levelRaw: string | null;
  targetDurationBandKey: string | null;
  /** Optional; when not on draft row, omit — limits may be skipped. */
  durationSeconds?: number | null;
  /** Optional; used to detect imported AI vs manual drafts (defaults to manual). */
  promptSourceNote?: string | null;
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
      totalJapaneseChars += charLength(t.trim().replace(/\s/g, ''));
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

function resolveHtmlPromptMode(input: StoryPublishValidationInput): HtmlPromptMode {
  const raw = String(input.promptSourceNote ?? '').trim().toLowerCase();
  if (raw.includes('promptdatatab=ai_mode') || raw.includes('ai_mode')) return 'ai';
  if (raw.includes('promptdatatab=manual_mode') || raw.includes('manual_mode')) return 'manual';
  return 'manual';
}

function quizCountsForHtmlRules(
  quizEntries: Array<{ content: unknown }>,
): { total: number; vocabulary: number; grammar: number; sentence: number } {
  let total = 0;
  let vocabulary = 0;
  let grammar = 0;
  let sentence = 0;
  for (const row of quizEntries) {
    const parsed = parseQuizEntry(row.content);
    if (!parsed) continue;
    total++;
    const c = row.content;
    const raw =
      c && typeof c === 'object' && !Array.isArray(c) ? String((c as Record<string, unknown>).category ?? '') : '';
    const k = raw.trim().toLowerCase();
    if (k === 'vocabulary') vocabulary++;
    else if (k === 'grammar') grammar++;
    else if (k === 'sample_sentence' || k === 'sentence') sentence++;
    else {
      // kanji/unknown: count in total only
    }
  }
  return { total, vocabulary, grammar, sentence };
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

  const band = resolveStoryDurationBand({
    targetDurationBandKey: input.targetDurationBandKey,
    durationSeconds: input.durationSeconds ?? null,
  });

  const htmlLevel = normalizeHtmlLevel(input.levelRaw);
  const htmlDuration = normalizeHtmlDuration(band);
  const promptMode = resolveHtmlPromptMode(input);
  const language: HtmlLearningLanguage = 'jp';
  const preset: HtmlLimitPreset = 'default';

  if (!htmlLevel) {
    pieces.push(
      resultFromIssues([
        block('story.level', 'publish.htmlRules.levelInvalid', 'publish.htmlRules.levelInvalid'),
      ]),
    );
  }
  if (!htmlDuration) {
    pieces.push(
      resultFromIssues([
        block(
          'story.duration',
          'publish.htmlRules.durationInvalid',
          'publish.htmlRules.durationInvalid',
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

  if (htmlLevel && htmlDuration && metrics.validCount > 0) {
    const limits = sentenceLimit({
      mode: promptMode,
      language,
      duration: htmlDuration,
      level: htmlLevel,
    });
    if (!limits) {
      pieces.push(
        resultFromIssues([
          block(
            'story.sentences',
            'publish.htmlRules.promptModeInvalid',
            'publish.htmlRules.promptModeInvalid',
          ),
        ]),
      );
    } else if (metrics.validCount < limits.minSentences) {
      pieces.push(
        resultFromIssues([
          block(
            'story.sentences',
            'publish.htmlRules.storySentenceTooFew',
            'publish.htmlRules.storySentenceTooFew',
            { min: limits.minSentences, actual: metrics.validCount },
          ),
        ]),
      );
    } else if (metrics.validCount > limits.maxSentences) {
      pieces.push(
        resultFromIssues([
          block(
            'story.sentences',
            'publish.htmlRules.storySentenceTooMany',
            'publish.htmlRules.storySentenceTooMany',
            { max: limits.maxSentences, actual: metrics.validCount },
          ),
        ]),
      );
    }
    if (limits && metrics.totalJapaneseChars < limits.minChars) {
      pieces.push(
        resultFromIssues([
          block(
            'story.body',
            'publish.htmlRules.storyCharsTooFew',
            'publish.htmlRules.storyCharsTooFew',
            { min: limits.minChars, actual: metrics.totalJapaneseChars },
          ),
        ]),
      );
    }
    if (limits && metrics.totalJapaneseChars > limits.maxChars) {
      pieces.push(
        resultFromIssues([
          block(
            'story.body',
            'publish.htmlRules.storyCharsTooMany',
            'publish.htmlRules.storyCharsTooMany',
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

    if (htmlLevel && htmlDuration) {
      const vLim = vocabularyLimit({ language, duration: htmlDuration, level: htmlLevel });
      const gLim = grammarLimit({ language, duration: htmlDuration, level: htmlLevel });

      const vocabCount = input.vocabEntries.filter((e) => {
        const p = parseVocabEntry(e.content);
        return p.termJapanese.trim().length > 0;
      }).length;
      const grammarCount = input.grammarEntries.filter((e) => {
        return parseGrammarEntry(e.content).headline.trim().length > 0;
      }).length;

      if (vLim) {
        if (promptMode === 'ai') {
          const expected = vLim.defaultValue;
          if (vocabCount !== expected) {
            pieces.push(
              resultFromIssues([
                block(
                  'learn.vocab.count',
                  'publish.htmlRules.vocabularyCountMismatch',
                  'publish.htmlRules.vocabularyCountMismatch',
                  { expected, actual: vocabCount },
                ),
              ]),
            );
          }
        } else if (vocabCount < vLim.manualMin || vocabCount > vLim.manualMax) {
          pieces.push(
            resultFromIssues([
              block(
                'learn.vocab.count',
                'publish.htmlRules.vocabularyCountMismatch',
                'publish.htmlRules.vocabularyCountMismatch',
                { min: vLim.manualMin, max: vLim.manualMax, actual: vocabCount },
              ),
            ]),
          );
        }
      }

      if (gLim) {
        if (promptMode === 'ai') {
          const expected = gLim.defaultValue;
          if (grammarCount !== expected) {
            pieces.push(
              resultFromIssues([
                block(
                  'learn.grammar.count',
                  'publish.htmlRules.grammarCountMismatch',
                  'publish.htmlRules.grammarCountMismatch',
                  { expected, actual: grammarCount },
                ),
              ]),
            );
          }
        } else if (grammarCount < gLim.manualMin || grammarCount > gLim.manualMax) {
          pieces.push(
            resultFromIssues([
              block(
                'learn.grammar.count',
                'publish.htmlRules.grammarCountMismatch',
                'publish.htmlRules.grammarCountMismatch',
                { min: gLim.manualMin, max: gLim.manualMax, actual: grammarCount },
              ),
            ]),
          );
        }
      }

      const quizCounts = quizCountsForHtmlRules(input.quizEntries);
      const selected =
        promptMode === 'ai'
          ? selectedFullLearnLimits({
              mode: 'ai',
              language,
              duration: htmlDuration,
              level: htmlLevel,
              preset,
            })
          : null;

      if (promptMode === 'ai' && selected) {
        if (quizCounts.total !== selected.totalQuizCount) {
          pieces.push(
            resultFromIssues([
              block(
                'learn.quiz.count',
                'publish.htmlRules.quizTotalMismatch',
                'publish.htmlRules.quizTotalMismatch',
                { expected: selected.totalQuizCount, actual: quizCounts.total },
              ),
            ]),
          );
        }
        if (quizCounts.vocabulary !== selected.vocabularyQuizCount) {
          pieces.push(
            resultFromIssues([
              block(
                'learn.quiz.vocabulary',
                'publish.htmlRules.quizVocabularyMismatch',
                'publish.htmlRules.quizVocabularyMismatch',
                { expected: selected.vocabularyQuizCount, actual: quizCounts.vocabulary },
              ),
            ]),
          );
        }
        if (quizCounts.grammar !== selected.grammarQuizCount) {
          pieces.push(
            resultFromIssues([
              block(
                'learn.quiz.grammar',
                'publish.htmlRules.quizGrammarMismatch',
                'publish.htmlRules.quizGrammarMismatch',
                { expected: selected.grammarQuizCount, actual: quizCounts.grammar },
              ),
            ]),
          );
        }
        if (quizCounts.sentence !== selected.sentenceQuizCount) {
          pieces.push(
            resultFromIssues([
              block(
                'learn.quiz.sentence',
                'publish.htmlRules.quizSentenceMismatch',
                'publish.htmlRules.quizSentenceMismatch',
                { expected: selected.sentenceQuizCount, actual: quizCounts.sentence },
              ),
            ]),
          );
        }
      } else if (promptMode === 'manual') {
        const totalLim = quizLimit({ duration: htmlDuration, level: htmlLevel, quizCategory: 'Total Quiz' });
        const vqLim = quizLimit({ duration: htmlDuration, level: htmlLevel, quizCategory: 'Vocabulary Quiz' });
        const gqLim = quizLimit({ duration: htmlDuration, level: htmlLevel, quizCategory: 'Grammar Quiz' });
        const sqLim = quizLimit({ duration: htmlDuration, level: htmlLevel, quizCategory: 'Sentence Quiz' });

        if (totalLim && (quizCounts.total < totalLim.manualMin || quizCounts.total > totalLim.manualMax)) {
          pieces.push(
            resultFromIssues([
              block(
                'learn.quiz.count',
                'publish.htmlRules.quizTotalMismatch',
                'publish.htmlRules.quizTotalMismatch',
                { min: totalLim.manualMin, max: totalLim.manualMax, actual: quizCounts.total },
              ),
            ]),
          );
        }
        if (vqLim && (quizCounts.vocabulary < vqLim.manualMin || quizCounts.vocabulary > vqLim.manualMax)) {
          pieces.push(
            resultFromIssues([
              block(
                'learn.quiz.vocabulary',
                'publish.htmlRules.quizVocabularyMismatch',
                'publish.htmlRules.quizVocabularyMismatch',
                { min: vqLim.manualMin, max: vqLim.manualMax, actual: quizCounts.vocabulary },
              ),
            ]),
          );
        }
        if (gqLim && (quizCounts.grammar < gqLim.manualMin || quizCounts.grammar > gqLim.manualMax)) {
          pieces.push(
            resultFromIssues([
              block(
                'learn.quiz.grammar',
                'publish.htmlRules.quizGrammarMismatch',
                'publish.htmlRules.quizGrammarMismatch',
                { min: gqLim.manualMin, max: gqLim.manualMax, actual: quizCounts.grammar },
              ),
            ]),
          );
        }
        if (sqLim && (quizCounts.sentence < sqLim.manualMin || quizCounts.sentence > sqLim.manualMax)) {
          pieces.push(
            resultFromIssues([
              block(
                'learn.quiz.sentence',
                'publish.htmlRules.quizSentenceMismatch',
                'publish.htmlRules.quizSentenceMismatch',
                { min: sqLim.manualMin, max: sqLim.manualMax, actual: quizCounts.sentence },
              ),
            ]),
          );
        }
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
  promptSourceNote?: string | null;
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
    promptSourceNote: draft.promptSourceNote ?? null,
    sentences: draft.sentences ?? [],
    vocabEntries: draft.vocabEntries ?? [],
    grammarEntries: draft.grammarEntries ?? [],
    quizEntries: draft.quizEntries ?? [],
    moduleWorkflowStatuses,
  };
}
