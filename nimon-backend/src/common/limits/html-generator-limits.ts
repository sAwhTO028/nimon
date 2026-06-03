/**
 * HTML generator limitation rules (source of truth).
 *
 * IMPORTANT (Phase 1B config-only):
 * - This module must NOT change backend production behavior by itself.
 * - Values are copied verbatim from:
 *   `tool/html_generator/Json_Generator_ImportReadyPrompt_v7.html`
 * - Intended for future wiring only.
 */

export type HtmlPromptMode = 'manual' | 'ai';
export type HtmlLearningLanguage = 'jp' | 'en';
export type HtmlPublishKind = 'readOnly' | 'fullLearn';
export type HtmlLimitPreset = 'minimum' | 'default' | 'optimal' | 'maximum';

export function normalizeHtmlLevel(
  input: string | null | undefined,
): 'N5/A1' | 'N4/A2' | 'N3/B1' | 'N2/B2' | 'N1/C1' | null {
  const raw = String(input ?? '').trim();
  if (!raw) return null;
  // Mirrors HTML: normalizeLevel(v) strips `^\d+\.` and trims.
  const stripped = raw.replace(/^\d+\./, '').trim();
  if (!stripped) return null;

  const jlpt = stripped.split('/')[0]?.trim().toUpperCase() ?? '';
  if (jlpt === 'N5') return 'N5/A1';
  if (jlpt === 'N4') return 'N4/A2';
  if (jlpt === 'N3') return 'N3/B1';
  if (jlpt === 'N2') return 'N2/B2';
  if (jlpt === 'N1') return 'N1/C1';

  // Already concrete; only accept supported values.
  const s = stripped.toUpperCase();
  if (s === 'N5/A1') return 'N5/A1';
  if (s === 'N4/A2') return 'N4/A2';
  if (s === 'N3/B1') return 'N3/B1';
  if (s === 'N2/B2') return 'N2/B2';
  if (s === 'N1/C1') return 'N1/C1';
  return null;
}

export function normalizeHtmlDuration(
  input: string | null | undefined,
): '3-5 mins' | '5-7 mins' | '7-9 mins' | null {
  const raw = String(input ?? '').trim();
  if (!raw) return null;
  const s = raw.toLowerCase();
  if (s.includes('3_5') || s.includes('3-5')) return '3-5 mins';
  if (s.includes('5_7') || s.includes('5-7')) return '5-7 mins';
  if (s.includes('7_9') || s.includes('7-9')) return '7-9 mins';
  return null;
}

export function normalizeHtmlLanguage(
  input: string | null | undefined,
): HtmlLearningLanguage | null {
  const raw = String(input ?? '').trim();
  if (!raw) return null;
  const s = raw.toLowerCase();

  // JP (broad for config lookup)
  if (s === 'jp' || s === 'ja' || s.includes('japanese') || s.includes('jp')) {
    // avoid mapping "English" to jp.
    if (s.includes('english') || s === 'en') {
      // fall through
    } else {
      return 'jp';
    }
  }

  // EN (config lookup only; does not enable product behavior)
  if (s === 'en' || s.includes('english')) return 'en';
  return null;
}

export function normalizeHtmlPromptMode(
  input: string | null | undefined,
): HtmlPromptMode | null {
  const raw = String(input ?? '').trim();
  if (!raw) return null;
  const s = raw.toLowerCase();
  if (s === 'manual' || s === 'manual_mode') return 'manual';
  if (s === 'ai' || s === 'ai_mode') return 'ai';
  return null;
}

export function normalizeHtmlPublishKind(
  input: string | null | undefined,
): HtmlPublishKind | null {
  const raw = String(input ?? '').trim();
  if (!raw) return null;
  const stripped = raw.replace(/^\d+\./, '').trim();
  const s = stripped.toLowerCase();

  if (s.includes('read_only') || s === 'read only' || s === 'readonly') {
    return 'readOnly';
  }
  if (
    s.includes('full_learn') ||
    s === 'full' ||
    s.includes('full learn') ||
    s === 'full_learn'
  ) {
    return 'fullLearn';
  }
  return null;
}

export interface HtmlSentenceLimit {
  minSentences: number;
  maxSentences: number;
  minChars: number;
  maxChars: number;
}

export interface HtmlLearnModuleLimit {
  manualMin: number;
  manualMax: number;
  minimum: number;
  defaultValue: number;
  optimal: number;
  maximum: number;
}

export interface HtmlQuizCategoryLimit {
  manualMin: number;
  manualMax: number;
  minimum: number;
  defaultValue: number;
  optimal: number;
  maximum: number;
}

export interface HtmlFullLearnSelectedLimits {
  vocabularyCount: number;
  grammarCount: number;
  vocabularyQuizCount: number;
  grammarQuizCount: number;
  sentenceQuizCount: number;
  totalQuizCount: number;
}

export const sliderKeys = ['minimum', 'default', 'optimal', 'maximum'] as const;

export function isSliderEnabled(input: {
  publishKind: HtmlPublishKind;
  mode: HtmlPromptMode;
}): boolean {
  // Mirrors HTML: FULL + AI only.
  return input.publishKind === 'fullLearn' && input.mode === 'ai';
}

export function readOnlyNeedsLearnModules(): boolean {
  return false;
}

export function fullLearnNeedsLearnModules(): boolean {
  return true;
}

export function fullLearnNeedsAudio(): boolean {
  return true;
}

export function sentenceLimit(input: {
  mode: HtmlPromptMode;
  language: HtmlLearningLanguage;
  duration: '3-5 mins' | '5-7 mins' | '7-9 mins';
  level: 'N5/A1' | 'N4/A2' | 'N3/B1' | 'N2/B2' | 'N1/C1';
}): HtmlSentenceLimit | null {
  return (
    SENTENCE_LIMITS[input.mode]?.[input.language]?.[input.duration]?.[input.level] ??
    null
  );
}

export function vocabularyLimit(input: {
  language: HtmlLearningLanguage;
  duration: '3-5 mins' | '5-7 mins' | '7-9 mins';
  level: 'N5/A1' | 'N4/A2' | 'N3/B1' | 'N2/B2' | 'N1/C1';
}): HtmlLearnModuleLimit | null {
  return LEARN_LIMITS[input.language]?.[input.duration]?.[input.level]?.Vocabulary ?? null;
}

export function grammarLimit(input: {
  language: HtmlLearningLanguage;
  duration: '3-5 mins' | '5-7 mins' | '7-9 mins';
  level: 'N5/A1' | 'N4/A2' | 'N3/B1' | 'N2/B2' | 'N1/C1';
}): HtmlLearnModuleLimit | null {
  return LEARN_LIMITS[input.language]?.[input.duration]?.[input.level]?.Grammar ?? null;
}

export function quizLimit(input: {
  duration: '3-5 mins' | '5-7 mins' | '7-9 mins';
  level: 'N5/A1' | 'N4/A2' | 'N3/B1' | 'N2/B2' | 'N1/C1';
  quizCategory: 'Vocabulary Quiz' | 'Grammar Quiz' | 'Sentence Quiz' | 'Total Quiz';
}): HtmlQuizCategoryLimit | null {
  return QUIZ_LIMITS[input.duration]?.[input.level]?.[input.quizCategory] ?? null;
}

function selectedFor(
  mode: HtmlPromptMode,
  preset: HtmlLimitPreset,
  row: { manualMin: number; manualMax: number } & Record<
    'minimum' | 'defaultValue' | 'optimal' | 'maximum',
    number
  >,
): number {
  if (mode === 'manual') return row.manualMax;
  if (preset === 'minimum') return row.minimum;
  if (preset === 'default') return row.defaultValue;
  if (preset === 'optimal') return row.optimal;
  return row.maximum;
}

export function selectedFullLearnLimits(input: {
  mode: HtmlPromptMode;
  language: HtmlLearningLanguage;
  duration: '3-5 mins' | '5-7 mins' | '7-9 mins';
  level: 'N5/A1' | 'N4/A2' | 'N3/B1' | 'N2/B2' | 'N1/C1';
  preset: HtmlLimitPreset;
}): HtmlFullLearnSelectedLimits | null {
  const vocab = vocabularyLimit(input);
  const grammar = grammarLimit(input);
  const vQuiz = quizLimit({
    duration: input.duration,
    level: input.level,
    quizCategory: 'Vocabulary Quiz',
  });
  const gQuiz = quizLimit({
    duration: input.duration,
    level: input.level,
    quizCategory: 'Grammar Quiz',
  });
  const sQuiz = quizLimit({
    duration: input.duration,
    level: input.level,
    quizCategory: 'Sentence Quiz',
  });
  const tQuiz = quizLimit({
    duration: input.duration,
    level: input.level,
    quizCategory: 'Total Quiz',
  });
  if (!vocab || !grammar || !vQuiz || !gQuiz || !sQuiz || !tQuiz) return null;

  return {
    vocabularyCount: selectedFor(input.mode, input.preset, vocab),
    grammarCount: selectedFor(input.mode, input.preset, grammar),
    vocabularyQuizCount: selectedFor(input.mode, input.preset, vQuiz),
    grammarQuizCount: selectedFor(input.mode, input.preset, gQuiz),
    sentenceQuizCount: selectedFor(input.mode, input.preset, sQuiz),
    totalQuizCount: selectedFor(input.mode, input.preset, tQuiz),
  };
}

// ---------------------------------------------------------------------------
// Embedded source-of-truth tables (verbatim values from HTML)
// ---------------------------------------------------------------------------

const SENTENCE_LIMITS: Record<
  HtmlPromptMode,
  Record<
    HtmlLearningLanguage,
    Record<
      '3-5 mins' | '5-7 mins' | '7-9 mins',
      Record<'N5/A1' | 'N4/A2' | 'N3/B1' | 'N2/B2' | 'N1/C1', HtmlSentenceLimit>
    >
  >
> = {
  manual: {
    jp: {
      '3-5 mins': {
        'N5/A1': { minSentences: 18, maxSentences: 30, minChars: 250, maxChars: 450 },
        'N4/A2': { minSentences: 20, maxSentences: 34, minChars: 350, maxChars: 600 },
        'N3/B1': { minSentences: 22, maxSentences: 36, minChars: 500, maxChars: 800 },
        'N2/B2': { minSentences: 20, maxSentences: 34, minChars: 650, maxChars: 1050 },
        'N1/C1': { minSentences: 18, maxSentences: 32, minChars: 800, maxChars: 1300 },
      },
      '5-7 mins': {
        'N5/A1': { minSentences: 28, maxSentences: 45, minChars: 400, maxChars: 650 },
        'N4/A2': { minSentences: 32, maxSentences: 50, minChars: 550, maxChars: 900 },
        'N3/B1': { minSentences: 34, maxSentences: 55, minChars: 750, maxChars: 1150 },
        'N2/B2': { minSentences: 32, maxSentences: 52, minChars: 1000, maxChars: 1550 },
        'N1/C1': { minSentences: 30, maxSentences: 50, minChars: 1250, maxChars: 1900 },
      },
      '7-9 mins': {
        'N5/A1': { minSentences: 40, maxSentences: 60, minChars: 600, maxChars: 900 },
        'N4/A2': { minSentences: 45, maxSentences: 65, minChars: 800, maxChars: 1200 },
        'N3/B1': { minSentences: 48, maxSentences: 70, minChars: 1050, maxChars: 1550 },
        'N2/B2': { minSentences: 45, maxSentences: 68, minChars: 1350, maxChars: 2050 },
        'N1/C1': { minSentences: 42, maxSentences: 65, minChars: 1650, maxChars: 2500 },
      },
    },
    en: {
      '3-5 mins': {
        'N5/A1': { minSentences: 18, maxSentences: 30, minChars: 900, maxChars: 1600 },
        'N4/A2': { minSentences: 20, maxSentences: 34, minChars: 1200, maxChars: 2200 },
        'N3/B1': { minSentences: 22, maxSentences: 36, minChars: 1600, maxChars: 2800 },
        'N2/B2': { minSentences: 20, maxSentences: 34, minChars: 2000, maxChars: 3400 },
        'N1/C1': { minSentences: 18, maxSentences: 32, minChars: 2400, maxChars: 4200 },
      },
      '5-7 mins': {
        'N5/A1': { minSentences: 28, maxSentences: 45, minChars: 1400, maxChars: 2400 },
        'N4/A2': { minSentences: 32, maxSentences: 50, minChars: 1900, maxChars: 3300 },
        'N3/B1': { minSentences: 34, maxSentences: 55, minChars: 2500, maxChars: 4200 },
        'N2/B2': { minSentences: 32, maxSentences: 52, minChars: 3300, maxChars: 5400 },
        'N1/C1': { minSentences: 30, maxSentences: 50, minChars: 4200, maxChars: 6800 },
      },
      '7-9 mins': {
        'N5/A1': { minSentences: 40, maxSentences: 60, minChars: 2200, maxChars: 3500 },
        'N4/A2': { minSentences: 45, maxSentences: 65, minChars: 3000, maxChars: 4800 },
        'N3/B1': { minSentences: 48, maxSentences: 70, minChars: 4000, maxChars: 6200 },
        'N2/B2': { minSentences: 45, maxSentences: 68, minChars: 5200, maxChars: 7800 },
        'N1/C1': { minSentences: 42, maxSentences: 65, minChars: 6500, maxChars: 9500 },
      },
    },
  },
  ai: {
    jp: {
      '3-5 mins': {
        'N5/A1': { minSentences: 24, maxSentences: 38, minChars: 350, maxChars: 550 },
        'N4/A2': { minSentences: 28, maxSentences: 42, minChars: 500, maxChars: 750 },
        'N3/B1': { minSentences: 30, maxSentences: 45, minChars: 650, maxChars: 950 },
        'N2/B2': { minSentences: 28, maxSentences: 42, minChars: 850, maxChars: 1250 },
        'N1/C1': { minSentences: 26, maxSentences: 40, minChars: 1050, maxChars: 1550 },
      },
      '5-7 mins': {
        'N5/A1': { minSentences: 38, maxSentences: 55, minChars: 550, maxChars: 800 },
        'N4/A2': { minSentences: 42, maxSentences: 60, minChars: 750, maxChars: 1100 },
        'N3/B1': { minSentences: 45, maxSentences: 65, minChars: 950, maxChars: 1400 },
        'N2/B2': { minSentences: 42, maxSentences: 62, minChars: 1250, maxChars: 1800 },
        'N1/C1': { minSentences: 40, maxSentences: 60, minChars: 1550, maxChars: 2250 },
      },
      '7-9 mins': {
        'N5/A1': { minSentences: 55, maxSentences: 75, minChars: 800, maxChars: 1100 },
        'N4/A2': { minSentences: 60, maxSentences: 82, minChars: 1050, maxChars: 1500 },
        'N3/B1': { minSentences: 62, maxSentences: 88, minChars: 1350, maxChars: 1900 },
        'N2/B2': { minSentences: 58, maxSentences: 84, minChars: 1700, maxChars: 2450 },
        'N1/C1': { minSentences: 55, maxSentences: 80, minChars: 2100, maxChars: 3000 },
      },
    },
    en: {
      '3-5 mins': {
        'N5/A1': { minSentences: 24, maxSentences: 38, minChars: 1200, maxChars: 2100 },
        'N4/A2': { minSentences: 28, maxSentences: 42, minChars: 1600, maxChars: 2800 },
        'N3/B1': { minSentences: 30, maxSentences: 45, minChars: 2200, maxChars: 3600 },
        'N2/B2': { minSentences: 28, maxSentences: 42, minChars: 2800, maxChars: 4400 },
        'N1/C1': { minSentences: 26, maxSentences: 40, minChars: 3400, maxChars: 5400 },
      },
      '5-7 mins': {
        'N5/A1': { minSentences: 38, maxSentences: 55, minChars: 2000, maxChars: 3200 },
        'N4/A2': { minSentences: 42, maxSentences: 60, minChars: 2600, maxChars: 4200 },
        'N3/B1': { minSentences: 45, maxSentences: 65, minChars: 3400, maxChars: 5200 },
        'N2/B2': { minSentences: 42, maxSentences: 62, minChars: 4400, maxChars: 6600 },
        'N1/C1': { minSentences: 40, maxSentences: 60, minChars: 5600, maxChars: 8200 },
      },
      '7-9 mins': {
        'N5/A1': { minSentences: 55, maxSentences: 75, minChars: 3000, maxChars: 4500 },
        'N4/A2': { minSentences: 60, maxSentences: 82, minChars: 4000, maxChars: 6000 },
        'N3/B1': { minSentences: 62, maxSentences: 88, minChars: 5200, maxChars: 7600 },
        'N2/B2': { minSentences: 58, maxSentences: 84, minChars: 6800, maxChars: 9500 },
        'N1/C1': { minSentences: 55, maxSentences: 80, minChars: 8500, maxChars: 12000 },
      },
    },
  },
};

const LEARN_LIMITS: Record<
  HtmlLearningLanguage,
  Record<
    '3-5 mins' | '5-7 mins' | '7-9 mins',
    Record<
      'N5/A1' | 'N4/A2' | 'N3/B1' | 'N2/B2' | 'N1/C1',
      Record<'Vocabulary' | 'Grammar', HtmlLearnModuleLimit>
    >
  >
> = {
  // Matches Flutter `lib/core/limits/html_generator_limits.dart`
  jp: {
    '3-5 mins': {
      'N5/A1': {
        Vocabulary: { manualMin: 6, manualMax: 12, minimum: 6, defaultValue: 8, optimal: 10, maximum: 12 },
        Grammar: { manualMin: 2, manualMax: 5, minimum: 2, defaultValue: 3, optimal: 4, maximum: 5 },
      },
      'N4/A2': {
        Vocabulary: { manualMin: 8, manualMax: 16, minimum: 8, defaultValue: 11, optimal: 13, maximum: 16 },
        Grammar: { manualMin: 3, manualMax: 7, minimum: 3, defaultValue: 4, optimal: 5, maximum: 7 },
      },
      'N3/B1': {
        Vocabulary: { manualMin: 10, manualMax: 22, minimum: 10, defaultValue: 14, optimal: 17, maximum: 22 },
        Grammar: { manualMin: 4, manualMax: 10, minimum: 4, defaultValue: 6, optimal: 8, maximum: 10 },
      },
      'N2/B2': {
        Vocabulary: { manualMin: 12, manualMax: 28, minimum: 12, defaultValue: 18, optimal: 22, maximum: 28 },
        Grammar: { manualMin: 5, manualMax: 13, minimum: 5, defaultValue: 8, optimal: 10, maximum: 13 },
      },
      'N1/C1': {
        Vocabulary: { manualMin: 15, manualMax: 36, minimum: 15, defaultValue: 22, optimal: 28, maximum: 36 },
        Grammar: { manualMin: 6, manualMax: 16, minimum: 6, defaultValue: 10, optimal: 12, maximum: 16 },
      },
    },
    '5-7 mins': {
      'N5/A1': {
        Vocabulary: { manualMin: 9, manualMax: 18, minimum: 9, defaultValue: 12, optimal: 14, maximum: 18 },
        Grammar: { manualMin: 3, manualMax: 7, minimum: 3, defaultValue: 4, optimal: 5, maximum: 7 },
      },
      'N4/A2': {
        Vocabulary: { manualMin: 12, manualMax: 24, minimum: 12, defaultValue: 16, optimal: 19, maximum: 24 },
        Grammar: { manualMin: 4, manualMax: 10, minimum: 4, defaultValue: 6, optimal: 8, maximum: 10 },
      },
      'N3/B1': {
        Vocabulary: { manualMin: 16, manualMax: 32, minimum: 16, defaultValue: 22, optimal: 26, maximum: 32 },
        Grammar: { manualMin: 5, manualMax: 14, minimum: 5, defaultValue: 8, optimal: 10, maximum: 14 },
      },
      'N2/B2': {
        Vocabulary: { manualMin: 20, manualMax: 42, minimum: 20, defaultValue: 28, optimal: 33, maximum: 42 },
        Grammar: { manualMin: 7, manualMax: 18, minimum: 7, defaultValue: 11, optimal: 14, maximum: 18 },
      },
      'N1/C1': {
        Vocabulary: { manualMin: 26, manualMax: 55, minimum: 26, defaultValue: 36, optimal: 43, maximum: 55 },
        Grammar: { manualMin: 9, manualMax: 22, minimum: 9, defaultValue: 14, optimal: 17, maximum: 22 },
      },
    },
    '7-9 mins': {
      'N5/A1': {
        Vocabulary: { manualMin: 12, manualMax: 24, minimum: 12, defaultValue: 16, optimal: 19, maximum: 24 },
        Grammar: { manualMin: 4, manualMax: 9, minimum: 4, defaultValue: 6, optimal: 7, maximum: 9 },
      },
      'N4/A2': {
        Vocabulary: { manualMin: 16, manualMax: 32, minimum: 16, defaultValue: 22, optimal: 26, maximum: 32 },
        Grammar: { manualMin: 5, manualMax: 13, minimum: 5, defaultValue: 8, optimal: 10, maximum: 13 },
      },
      'N3/B1': {
        Vocabulary: { manualMin: 22, manualMax: 42, minimum: 22, defaultValue: 29, optimal: 34, maximum: 42 },
        Grammar: { manualMin: 7, manualMax: 18, minimum: 7, defaultValue: 11, optimal: 14, maximum: 18 },
      },
      'N2/B2': {
        Vocabulary: { manualMin: 28, manualMax: 55, minimum: 28, defaultValue: 37, optimal: 44, maximum: 55 },
        Grammar: { manualMin: 9, manualMax: 24, minimum: 9, defaultValue: 14, optimal: 18, maximum: 24 },
      },
      'N1/C1': {
        Vocabulary: { manualMin: 36, manualMax: 70, minimum: 36, defaultValue: 48, optimal: 56, maximum: 70 },
        Grammar: { manualMin: 12, manualMax: 30, minimum: 12, defaultValue: 18, optimal: 23, maximum: 30 },
      },
    },
  },
  en: {
    '3-5 mins': {
      'N5/A1': {
        Vocabulary: { manualMin: 6, manualMax: 13, minimum: 6, defaultValue: 8, optimal: 10, maximum: 13 },
        Grammar: { manualMin: 2, manualMax: 5, minimum: 2, defaultValue: 3, optimal: 4, maximum: 5 },
      },
      'N4/A2': {
        Vocabulary: { manualMin: 8, manualMax: 17, minimum: 8, defaultValue: 11, optimal: 13, maximum: 17 },
        Grammar: { manualMin: 3, manualMax: 7, minimum: 3, defaultValue: 4, optimal: 5, maximum: 7 },
      },
      'N3/B1': {
        Vocabulary: { manualMin: 11, manualMax: 24, minimum: 11, defaultValue: 16, optimal: 19, maximum: 24 },
        Grammar: { manualMin: 4, manualMax: 10, minimum: 4, defaultValue: 6, optimal: 8, maximum: 10 },
      },
      'N2/B2': {
        Vocabulary: { manualMin: 15, manualMax: 32, minimum: 15, defaultValue: 21, optimal: 25, maximum: 32 },
        Grammar: { manualMin: 5, manualMax: 13, minimum: 5, defaultValue: 8, optimal: 10, maximum: 13 },
      },
      'N1/C1': {
        Vocabulary: { manualMin: 20, manualMax: 42, minimum: 20, defaultValue: 28, optimal: 33, maximum: 42 },
        Grammar: { manualMin: 6, manualMax: 16, minimum: 6, defaultValue: 10, optimal: 12, maximum: 16 },
      },
    },
    '5-7 mins': {
      'N5/A1': {
        Vocabulary: { manualMin: 10, manualMax: 20, minimum: 10, defaultValue: 14, optimal: 16, maximum: 20 },
        Grammar: { manualMin: 3, manualMax: 7, minimum: 3, defaultValue: 4, optimal: 5, maximum: 7 },
      },
      'N4/A2': {
        Vocabulary: { manualMin: 13, manualMax: 26, minimum: 13, defaultValue: 18, optimal: 21, maximum: 26 },
        Grammar: { manualMin: 4, manualMax: 10, minimum: 4, defaultValue: 6, optimal: 8, maximum: 10 },
      },
      'N3/B1': {
        Vocabulary: { manualMin: 18, manualMax: 36, minimum: 18, defaultValue: 24, optimal: 29, maximum: 36 },
        Grammar: { manualMin: 5, manualMax: 14, minimum: 5, defaultValue: 8, optimal: 10, maximum: 14 },
      },
      'N2/B2': {
        Vocabulary: { manualMin: 24, manualMax: 48, minimum: 24, defaultValue: 32, optimal: 38, maximum: 48 },
        Grammar: { manualMin: 7, manualMax: 18, minimum: 7, defaultValue: 11, optimal: 14, maximum: 18 },
      },
      'N1/C1': {
        Vocabulary: { manualMin: 32, manualMax: 64, minimum: 32, defaultValue: 43, optimal: 51, maximum: 64 },
        Grammar: { manualMin: 9, manualMax: 22, minimum: 9, defaultValue: 14, optimal: 17, maximum: 22 },
      },
    },
    '7-9 mins': {
      'N5/A1': {
        Vocabulary: { manualMin: 14, manualMax: 28, minimum: 14, defaultValue: 19, optimal: 22, maximum: 28 },
        Grammar: { manualMin: 4, manualMax: 9, minimum: 4, defaultValue: 6, optimal: 7, maximum: 9 },
      },
      'N4/A2': {
        Vocabulary: { manualMin: 18, manualMax: 36, minimum: 18, defaultValue: 24, optimal: 29, maximum: 36 },
        Grammar: { manualMin: 5, manualMax: 13, minimum: 5, defaultValue: 8, optimal: 10, maximum: 13 },
      },
      'N3/B1': {
        Vocabulary: { manualMin: 25, manualMax: 50, minimum: 25, defaultValue: 34, optimal: 40, maximum: 50 },
        Grammar: { manualMin: 7, manualMax: 18, minimum: 7, defaultValue: 11, optimal: 14, maximum: 18 },
      },
      'N2/B2': {
        Vocabulary: { manualMin: 34, manualMax: 66, minimum: 34, defaultValue: 45, optimal: 53, maximum: 66 },
        Grammar: { manualMin: 9, manualMax: 24, minimum: 9, defaultValue: 14, optimal: 18, maximum: 24 },
      },
      'N1/C1': {
        Vocabulary: { manualMin: 45, manualMax: 85, minimum: 45, defaultValue: 59, optimal: 69, maximum: 85 },
        Grammar: { manualMin: 12, manualMax: 30, minimum: 12, defaultValue: 18, optimal: 23, maximum: 30 },
      },
    },
  },
};

const QUIZ_LIMITS: Record<
  '3-5 mins' | '5-7 mins' | '7-9 mins',
  Record<
    'N5/A1' | 'N4/A2' | 'N3/B1' | 'N2/B2' | 'N1/C1',
    Record<'Vocabulary Quiz' | 'Grammar Quiz' | 'Sentence Quiz' | 'Total Quiz', HtmlQuizCategoryLimit>
  >
> = {
  '3-5 mins': {
    'N5/A1': {
      'Vocabulary Quiz': { manualMin: 3, manualMax: 6, minimum: 4, defaultValue: 5, optimal: 6, maximum: 8 },
      'Grammar Quiz': { manualMin: 1, manualMax: 3, minimum: 2, defaultValue: 3, optimal: 3, maximum: 4 },
      'Sentence Quiz': { manualMin: 1, manualMax: 3, minimum: 2, defaultValue: 3, optimal: 3, maximum: 4 },
      'Total Quiz': { manualMin: 5, manualMax: 12, minimum: 8, defaultValue: 11, optimal: 13, maximum: 16 },
    },
    'N4/A2': {
      'Vocabulary Quiz': { manualMin: 4, manualMax: 8, minimum: 5, defaultValue: 7, optimal: 8, maximum: 10 },
      'Grammar Quiz': { manualMin: 2, manualMax: 4, minimum: 2, defaultValue: 3, optimal: 4, maximum: 5 },
      'Sentence Quiz': { manualMin: 2, manualMax: 4, minimum: 2, defaultValue: 3, optimal: 4, maximum: 5 },
      'Total Quiz': { manualMin: 8, manualMax: 16, minimum: 9, defaultValue: 13, optimal: 16, maximum: 20 },
    },
    'N3/B1': {
      'Vocabulary Quiz': { manualMin: 5, manualMax: 10, minimum: 6, defaultValue: 8, optimal: 10, maximum: 13 },
      'Grammar Quiz': { manualMin: 2, manualMax: 5, minimum: 3, defaultValue: 4, optimal: 5, maximum: 6 },
      'Sentence Quiz': { manualMin: 2, manualMax: 5, minimum: 3, defaultValue: 4, optimal: 5, maximum: 6 },
      'Total Quiz': { manualMin: 9, manualMax: 20, minimum: 12, defaultValue: 17, optimal: 20, maximum: 25 },
    },
    'N2/B2': {
      'Vocabulary Quiz': { manualMin: 6, manualMax: 12, minimum: 8, defaultValue: 11, optimal: 13, maximum: 16 },
      'Grammar Quiz': { manualMin: 3, manualMax: 6, minimum: 4, defaultValue: 5, optimal: 6, maximum: 8 },
      'Sentence Quiz': { manualMin: 3, manualMax: 6, minimum: 3, defaultValue: 4, optimal: 5, maximum: 7 },
      'Total Quiz': { manualMin: 12, manualMax: 24, minimum: 15, defaultValue: 21, optimal: 25, maximum: 31 },
    },
    'N1/C1': {
      'Vocabulary Quiz': { manualMin: 7, manualMax: 14, minimum: 10, defaultValue: 14, optimal: 16, maximum: 20 },
      'Grammar Quiz': { manualMin: 3, manualMax: 7, minimum: 5, defaultValue: 7, optimal: 8, maximum: 10 },
      'Sentence Quiz': { manualMin: 3, manualMax: 7, minimum: 4, defaultValue: 5, optimal: 6, maximum: 8 },
      'Total Quiz': { manualMin: 13, manualMax: 28, minimum: 19, defaultValue: 26, optimal: 30, maximum: 38 },
    },
  },
  '5-7 mins': {
    'N5/A1': {
      'Vocabulary Quiz': { manualMin: 5, manualMax: 9, minimum: 6, defaultValue: 8, optimal: 10, maximum: 12 },
      'Grammar Quiz': { manualMin: 2, manualMax: 4, minimum: 3, defaultValue: 4, optimal: 5, maximum: 6 },
      'Sentence Quiz': { manualMin: 2, manualMax: 4, minimum: 3, defaultValue: 4, optimal: 5, maximum: 6 },
      'Total Quiz': { manualMin: 9, manualMax: 17, minimum: 12, defaultValue: 16, optimal: 19, maximum: 24 },
    },
    'N4/A2': {
      'Vocabulary Quiz': { manualMin: 6, manualMax: 12, minimum: 8, defaultValue: 11, optimal: 13, maximum: 16 },
      'Grammar Quiz': { manualMin: 2, manualMax: 5, minimum: 4, defaultValue: 5, optimal: 6, maximum: 8 },
      'Sentence Quiz': { manualMin: 3, manualMax: 5, minimum: 3, defaultValue: 4, optimal: 5, maximum: 7 },
      'Total Quiz': { manualMin: 11, manualMax: 22, minimum: 15, defaultValue: 21, optimal: 25, maximum: 31 },
    },
    'N3/B1': {
      'Vocabulary Quiz': { manualMin: 8, manualMax: 16, minimum: 10, defaultValue: 14, optimal: 16, maximum: 20 },
      'Grammar Quiz': { manualMin: 3, manualMax: 7, minimum: 5, defaultValue: 7, optimal: 8, maximum: 10 },
      'Sentence Quiz': { manualMin: 3, manualMax: 7, minimum: 4, defaultValue: 5, optimal: 6, maximum: 8 },
      'Total Quiz': { manualMin: 14, manualMax: 30, minimum: 19, defaultValue: 26, optimal: 30, maximum: 38 },
    },
    'N2/B2': {
      'Vocabulary Quiz': { manualMin: 10, manualMax: 20, minimum: 13, defaultValue: 18, optimal: 21, maximum: 26 },
      'Grammar Quiz': { manualMin: 4, manualMax: 9, minimum: 6, defaultValue: 8, optimal: 10, maximum: 13 },
      'Sentence Quiz': { manualMin: 4, manualMax: 8, minimum: 5, defaultValue: 7, optimal: 8, maximum: 10 },
      'Total Quiz': { manualMin: 18, manualMax: 37, minimum: 24, defaultValue: 33, optimal: 39, maximum: 49 },
    },
    'N1/C1': {
      'Vocabulary Quiz': { manualMin: 12, manualMax: 24, minimum: 16, defaultValue: 22, optimal: 26, maximum: 32 },
      'Grammar Quiz': { manualMin: 5, manualMax: 11, minimum: 8, defaultValue: 11, optimal: 13, maximum: 16 },
      'Sentence Quiz': { manualMin: 5, manualMax: 10, minimum: 6, defaultValue: 8, optimal: 10, maximum: 12 },
      'Total Quiz': { manualMin: 22, manualMax: 45, minimum: 30, defaultValue: 41, optimal: 48, maximum: 60 },
    },
  },
  '7-9 mins': {
    'N5/A1': {
      'Vocabulary Quiz': { manualMin: 6, manualMax: 12, minimum: 8, defaultValue: 11, optimal: 13, maximum: 16 },
      'Grammar Quiz': { manualMin: 2, manualMax: 5, minimum: 4, defaultValue: 5, optimal: 6, maximum: 8 },
      'Sentence Quiz': { manualMin: 3, manualMax: 5, minimum: 4, defaultValue: 5, optimal: 6, maximum: 8 },
      'Total Quiz': { manualMin: 11, manualMax: 22, minimum: 16, defaultValue: 22, optimal: 26, maximum: 32 },
    },
    'N4/A2': {
      'Vocabulary Quiz': { manualMin: 8, manualMax: 16, minimum: 10, defaultValue: 14, optimal: 16, maximum: 20 },
      'Grammar Quiz': { manualMin: 3, manualMax: 6, minimum: 5, defaultValue: 7, optimal: 8, maximum: 10 },
      'Sentence Quiz': { manualMin: 3, manualMax: 7, minimum: 5, defaultValue: 7, optimal: 8, maximum: 10 },
      'Total Quiz': { manualMin: 14, manualMax: 29, minimum: 20, defaultValue: 27, optimal: 32, maximum: 40 },
    },
    'N3/B1': {
      'Vocabulary Quiz': { manualMin: 10, manualMax: 20, minimum: 13, defaultValue: 18, optimal: 21, maximum: 26 },
      'Grammar Quiz': { manualMin: 4, manualMax: 9, minimum: 6, defaultValue: 8, optimal: 10, maximum: 13 },
      'Sentence Quiz': { manualMin: 4, manualMax: 9, minimum: 6, defaultValue: 8, optimal: 10, maximum: 12 },
      'Total Quiz': { manualMin: 18, manualMax: 38, minimum: 25, defaultValue: 34, optimal: 41, maximum: 51 },
    },
    'N2/B2': {
      'Vocabulary Quiz': { manualMin: 13, manualMax: 26, minimum: 17, defaultValue: 23, optimal: 27, maximum: 34 },
      'Grammar Quiz': { manualMin: 5, manualMax: 12, minimum: 8, defaultValue: 11, optimal: 13, maximum: 17 },
      'Sentence Quiz': { manualMin: 5, manualMax: 11, minimum: 7, defaultValue: 9, optimal: 11, maximum: 14 },
      'Total Quiz': { manualMin: 23, manualMax: 49, minimum: 32, defaultValue: 44, optimal: 52, maximum: 65 },
    },
    'N1/C1': {
      'Vocabulary Quiz': { manualMin: 16, manualMax: 32, minimum: 22, defaultValue: 29, optimal: 34, maximum: 42 },
      'Grammar Quiz': { manualMin: 6, manualMax: 15, minimum: 10, defaultValue: 14, optimal: 17, maximum: 21 },
      'Sentence Quiz': { manualMin: 6, manualMax: 13, minimum: 8, defaultValue: 11, optimal: 13, maximum: 16 },
      'Total Quiz': { manualMin: 28, manualMax: 60, minimum: 40, defaultValue: 54, optimal: 63, maximum: 79 },
    },
  },
};

