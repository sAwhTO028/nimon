/**
 * Parity tests for HTML generator limits.
 *
 * These values MUST match Flutter:
 * - `lib/core/limits/html_generator_limits.dart`
 *
 * And MUST match source HTML:
 * - `tool/html_generator/Json_Generator_ImportReadyPrompt_v7.html`
 */

import {
  grammarLimit,
  isSliderEnabled,
  normalizeHtmlDuration,
  normalizeHtmlLanguage,
  resolveHtmlLearningLanguageFromWire,
  normalizeHtmlLevel,
  normalizeHtmlPromptMode,
  normalizeHtmlPublishKind,
  quizLimit,
  selectedFullLearnLimits,
  sentenceLimit,
  vocabularyLimit,
} from './html-generator-limits';

describe('html-generator-limits normalization', () => {
  it('level normalization', () => {
    expect(normalizeHtmlLevel('1.N4/A2')).toBe('N4/A2');
    expect(normalizeHtmlLevel('N4')).toBe('N4/A2');
  });

  it('duration normalization', () => {
    expect(normalizeHtmlDuration('2. 5-7 mins')).toBe('5-7 mins');
    expect(normalizeHtmlDuration('5_7')).toBe('5-7 mins');
  });

  it('resolveHtmlLearningLanguageFromWire maps ja/en and falls back to jp', () => {
    expect(resolveHtmlLearningLanguageFromWire('ja')).toBe('jp');
    expect(resolveHtmlLearningLanguageFromWire('en')).toBe('en');
    expect(resolveHtmlLearningLanguageFromWire(null)).toBe('jp');
    expect(resolveHtmlLearningLanguageFromWire('ko')).toBe('jp');
  });

  it('language normalization (config lookup only)', () => {
    expect(normalizeHtmlLanguage('1. Jp (Japanese)')).toBe('jp');
    expect(normalizeHtmlLanguage('Japanese')).toBe('jp');

    // English values are supported for config lookup only.
    // This does NOT enable English learning in backend behavior.
    expect(normalizeHtmlLanguage('English')).toBe('en');
    expect(normalizeHtmlLanguage('en')).toBe('en');
  });

  it('prompt mode normalization', () => {
    expect(normalizeHtmlPromptMode('AI_mode')).toBe('ai');
    expect(normalizeHtmlPromptMode('Manual_mode')).toBe('manual');
  });

  it('publish kind normalization', () => {
    expect(normalizeHtmlPublishKind('2. FULL')).toBe('fullLearn');
    expect(normalizeHtmlPublishKind('read_only_v1')).toBe('readOnly');
    expect(normalizeHtmlPublishKind('full_learn_v1')).toBe('fullLearn');
  });
});

describe('slider behavior', () => {
  it('slider enabled only for FULL + AI', () => {
    expect(isSliderEnabled({ publishKind: 'readOnly', mode: 'ai' })).toBe(false);
    expect(isSliderEnabled({ publishKind: 'fullLearn', mode: 'manual' })).toBe(false);
    expect(isSliderEnabled({ publishKind: 'fullLearn', mode: 'ai' })).toBe(true);
  });
});

describe('sentence limits from HTML', () => {
  it('AI + JP + 5-7 mins + N4/A2', () => {
    const lim = sentenceLimit({
      mode: 'ai',
      language: 'jp',
      duration: '5-7 mins',
      level: 'N4/A2',
    });
    expect(lim).not.toBeNull();
    expect(lim!.minSentences).toBe(42);
    expect(lim!.maxSentences).toBe(60);
    expect(lim!.minChars).toBe(750);
    expect(lim!.maxChars).toBe(1100);
  });

  it('Manual + JP + 5-7 mins + N4/A2', () => {
    const lim = sentenceLimit({
      mode: 'manual',
      language: 'jp',
      duration: '5-7 mins',
      level: 'N4/A2',
    });
    expect(lim).not.toBeNull();
    expect(lim!.minSentences).toBe(32);
    expect(lim!.maxSentences).toBe(50);
    expect(lim!.minChars).toBe(550);
    expect(lim!.maxChars).toBe(900);
  });
});

describe('learn limits from HTML', () => {
  it('JP + 5-7 mins + N4/A2 vocabulary', () => {
    const lim = vocabularyLimit({
      language: 'jp',
      duration: '5-7 mins',
      level: 'N4/A2',
    });
    expect(lim).not.toBeNull();
    expect(lim!.manualMin).toBe(12);
    expect(lim!.manualMax).toBe(24);
    expect(lim!.defaultValue).toBe(16);
  });

  it('JP + 5-7 mins + N4/A2 grammar', () => {
    const lim = grammarLimit({
      language: 'jp',
      duration: '5-7 mins',
      level: 'N4/A2',
    });
    expect(lim).not.toBeNull();
    expect(lim!.manualMin).toBe(4);
    expect(lim!.manualMax).toBe(10);
    expect(lim!.defaultValue).toBe(6);
  });
});

describe('quiz limits from HTML', () => {
  it('5-7 mins + N4/A2 quiz defaults', () => {
    const vocab = quizLimit({
      duration: '5-7 mins',
      level: 'N4/A2',
      quizCategory: 'Vocabulary Quiz',
    });
    const grammar = quizLimit({
      duration: '5-7 mins',
      level: 'N4/A2',
      quizCategory: 'Grammar Quiz',
    });
    const sentence = quizLimit({
      duration: '5-7 mins',
      level: 'N4/A2',
      quizCategory: 'Sentence Quiz',
    });
    const total = quizLimit({
      duration: '5-7 mins',
      level: 'N4/A2',
      quizCategory: 'Total Quiz',
    });

    expect(vocab).not.toBeNull();
    expect(grammar).not.toBeNull();
    expect(sentence).not.toBeNull();
    expect(total).not.toBeNull();

    expect(vocab!.defaultValue).toBe(11);
    expect(grammar!.defaultValue).toBe(5);
    expect(sentence!.defaultValue).toBe(4);
    expect(total!.defaultValue).toBe(21);
  });
});

describe('selectedFullLearnLimits', () => {
  it('AI + JP + 5-7 mins + N4/A2 + default', () => {
    const sel = selectedFullLearnLimits({
      mode: 'ai',
      language: 'jp',
      duration: '5-7 mins',
      level: 'N4/A2',
      preset: 'default',
    });
    expect(sel).not.toBeNull();
    expect(sel!.vocabularyCount).toBe(16);
    expect(sel!.grammarCount).toBe(6);
    expect(sel!.vocabularyQuizCount).toBe(11);
    expect(sel!.grammarQuizCount).toBe(5);
    expect(sel!.sentenceQuizCount).toBe(4);
    expect(sel!.totalQuizCount).toBe(21);
  });
});

