import { validateStoryPublishInput } from './publish-validation';
import { ValidationMode } from './validation-mode';
import { hasBlockingIssues } from './validation-result';

function sentences(count: number, charsPerSentence: number) {
  const t = 'あ'.repeat(charsPerSentence);
  return Array.from({ length: count }, () => ({ content: { japaneseText: t } }));
}

function vocabEntries(count: number) {
  return Array.from({ length: count }, (_, i) => ({
    content: {
      termJapanese: `たんご${i}`,
      type: 'vocabulary',
      reading: 'あ',
      glosses: { my: 'm' },
    },
  }));
}

function grammarEntries(count: number) {
  return Array.from({ length: count }, (_, i) => ({
    content: { headline: `ぶんぽう${i}` },
  }));
}

function quizItem(id: string, category: string) {
  return {
    content: {
      category,
      prompt: `Question ${id}`,
      options: ['A', 'B', 'C', 'D'],
      correctIndex: 0,
    },
  };
}

function quizCounts(opts: { vocab: number; grammar: number; sentence: number; kanji: number }) {
  return [
    ...Array.from({ length: opts.vocab }, (_, i) => quizItem(`v${i}`, 'vocabulary')),
    ...Array.from({ length: opts.grammar }, (_, i) => quizItem(`g${i}`, 'grammar')),
    ...Array.from({ length: opts.sentence }, (_, i) => quizItem(`s${i}`, 'sample_sentence')),
    ...Array.from({ length: opts.kanji }, (_, i) => quizItem(`k${i}`, 'kanji')),
  ];
}

describe('publish validation (HTML generator rules)', () => {
  it('A. ReadOnly AI JP N4 5_7 valid story passes', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'desc',
        levelRaw: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentences: sentences(42, 18), // 756 chars (min 750)
        vocabEntries: [],
        grammarEntries: [],
        quizEntries: [],
        moduleWorkflowStatuses: {},
      },
      ValidationMode.ReadOnlyPublish,
    );
    expect(hasBlockingIssues(r)).toBe(false);
  });

  it('B. ReadOnly too few sentences blocks', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'desc',
        levelRaw: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentences: sentences(41, 18),
        vocabEntries: [],
        grammarEntries: [],
        quizEntries: [],
        moduleWorkflowStatuses: {},
      },
      ValidationMode.ReadOnlyPublish,
    );
    expect(hasBlockingIssues(r)).toBe(true);
    expect(r.issues.map((i) => i.code)).toContain('publish.htmlRules.storySentenceTooFew');
  });

  it('C. ReadOnly too many sentences blocks', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'desc',
        levelRaw: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentences: sentences(61, 18),
        vocabEntries: [],
        grammarEntries: [],
        quizEntries: [],
        moduleWorkflowStatuses: {},
      },
      ValidationMode.ReadOnlyPublish,
    );
    expect(hasBlockingIssues(r)).toBe(true);
    expect(r.issues.map((i) => i.code)).toContain('publish.htmlRules.storySentenceTooMany');
  });

  it('D. ReadOnly too few chars blocks', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'desc',
        levelRaw: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentences: sentences(42, 17), // 714 chars (min 750)
        vocabEntries: [],
        grammarEntries: [],
        quizEntries: [],
        moduleWorkflowStatuses: {},
      },
      ValidationMode.ReadOnlyPublish,
    );
    expect(hasBlockingIssues(r)).toBe(true);
    expect(r.issues.map((i) => i.code)).toContain('publish.htmlRules.storyCharsTooFew');
  });

  it('E. ReadOnly too many chars blocks', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'desc',
        levelRaw: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentences: sentences(42, 27), // 1134 chars (max 1100)
        vocabEntries: [],
        grammarEntries: [],
        quizEntries: [],
        moduleWorkflowStatuses: {},
      },
      ValidationMode.ReadOnlyPublish,
    );
    expect(hasBlockingIssues(r)).toBe(true);
    expect(r.issues.map((i) => i.code)).toContain('publish.htmlRules.storyCharsTooMany');
  });

  it('F. FullLearn AI JP N4 5_7 default valid passes', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'desc',
        levelRaw: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentences: sentences(42, 18),
        vocabEntries: vocabEntries(16),
        grammarEntries: grammarEntries(6),
        quizEntries: quizCounts({ vocab: 11, grammar: 5, sentence: 4, kanji: 1 }),
        moduleWorkflowStatuses: {
          vocabulary_kanji: 'completed',
          grammar: 'completed',
          quiz: 'completed',
          audio: 'completed',
        },
      },
      ValidationMode.FullLearnPublish,
    );
    expect(hasBlockingIssues(r)).toBe(false);
  });

  it('G. FullLearn AI valid counts but audio incomplete blocks', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'desc',
        levelRaw: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentences: sentences(42, 18),
        vocabEntries: vocabEntries(16),
        grammarEntries: grammarEntries(6),
        quizEntries: quizCounts({ vocab: 11, grammar: 5, sentence: 4, kanji: 1 }),
        moduleWorkflowStatuses: {
          vocabulary_kanji: 'completed',
          grammar: 'completed',
          quiz: 'completed',
          audio: 'not_started',
        },
      },
      ValidationMode.FullLearnPublish,
    );
    expect(hasBlockingIssues(r)).toBe(true);
    expect(r.issues.map((i) => i.code)).toContain('learn.module.audio.notCompleted');
  });

  it('H. FullLearn AI vocab mismatch blocks', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'desc',
        levelRaw: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentences: sentences(42, 18),
        vocabEntries: vocabEntries(15),
        grammarEntries: grammarEntries(6),
        quizEntries: quizCounts({ vocab: 11, grammar: 5, sentence: 4, kanji: 1 }),
        moduleWorkflowStatuses: {
          vocabulary_kanji: 'completed',
          grammar: 'completed',
          quiz: 'completed',
          audio: 'completed',
        },
      },
      ValidationMode.FullLearnPublish,
    );
    expect(hasBlockingIssues(r)).toBe(true);
    expect(r.issues.map((i) => i.code)).toContain('publish.htmlRules.vocabularyCountMismatch');
  });

  it('I. FullLearn AI quiz distribution mismatch blocks', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'desc',
        levelRaw: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentences: sentences(42, 18),
        vocabEntries: vocabEntries(16),
        grammarEntries: grammarEntries(6),
        quizEntries: quizCounts({ vocab: 10, grammar: 5, sentence: 4, kanji: 2 }),
        moduleWorkflowStatuses: {
          vocabulary_kanji: 'completed',
          grammar: 'completed',
          quiz: 'completed',
          audio: 'completed',
        },
      },
      ValidationMode.FullLearnPublish,
    );
    expect(hasBlockingIssues(r)).toBe(true);
    expect(r.issues.map((i) => i.code)).toContain('publish.htmlRules.quizVocabularyMismatch');
  });

  it('J. Manual mode uses manual ranges (JP N4 5_7 vocab 12–24)', () => {
    const ok = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'desc',
        levelRaw: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=Manual_mode',
        sentences: sentences(32, 18),
        vocabEntries: vocabEntries(12),
        grammarEntries: grammarEntries(4),
        quizEntries: quizCounts({ vocab: 8, grammar: 3, sentence: 3, kanji: 0 }),
        moduleWorkflowStatuses: {
          vocabulary_kanji: 'completed',
          grammar: 'completed',
          quiz: 'completed',
          audio: 'completed',
        },
      },
      ValidationMode.FullLearnPublish,
    );
    expect(hasBlockingIssues(ok)).toBe(false);

    const low = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'desc',
        levelRaw: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=Manual_mode',
        sentences: sentences(32, 18),
        vocabEntries: vocabEntries(11),
        grammarEntries: grammarEntries(4),
        quizEntries: quizCounts({ vocab: 8, grammar: 3, sentence: 3, kanji: 0 }),
        moduleWorkflowStatuses: {
          vocabulary_kanji: 'completed',
          grammar: 'completed',
          quiz: 'completed',
          audio: 'completed',
        },
      },
      ValidationMode.FullLearnPublish,
    );
    expect(hasBlockingIssues(low)).toBe(true);
    expect(low.issues.map((i) => i.code)).toContain('publish.htmlRules.vocabularyCountMismatch');

    const high = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'desc',
        levelRaw: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=Manual_mode',
        sentences: sentences(32, 18),
        vocabEntries: vocabEntries(25),
        grammarEntries: grammarEntries(4),
        quizEntries: quizCounts({ vocab: 8, grammar: 3, sentence: 3, kanji: 0 }),
        moduleWorkflowStatuses: {
          vocabulary_kanji: 'completed',
          grammar: 'completed',
          quiz: 'completed',
          audio: 'completed',
        },
      },
      ValidationMode.FullLearnPublish,
    );
    expect(hasBlockingIssues(high)).toBe(true);
    expect(high.issues.map((i) => i.code)).toContain('publish.htmlRules.vocabularyCountMismatch');
  });

  it('K. Missing level/duration blocks', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'desc',
        levelRaw: '',
        targetDurationBandKey: null,
        sentences: sentences(24, 15),
        vocabEntries: [],
        grammarEntries: [],
        quizEntries: [],
        moduleWorkflowStatuses: {},
      },
      ValidationMode.ReadOnlyPublish,
    );
    expect(hasBlockingIssues(r)).toBe(true);
    expect(r.issues.map((i) => i.code)).toContain('publish.htmlRules.levelInvalid');
    expect(r.issues.map((i) => i.code)).toContain('publish.htmlRules.durationInvalid');
  });

  it('L. Missing promptSourceNote defaults to manual (no crash)', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'desc',
        levelRaw: 'N4',
        targetDurationBandKey: '5_7',
        sentences: sentences(32, 18),
        vocabEntries: vocabEntries(12),
        grammarEntries: grammarEntries(4),
        quizEntries: quizCounts({ vocab: 8, grammar: 3, sentence: 3, kanji: 0 }),
        moduleWorkflowStatuses: {
          vocabulary_kanji: 'completed',
          grammar: 'completed',
          quiz: 'completed',
          audio: 'completed',
        },
      },
      ValidationMode.FullLearnPublish,
    );
    expect(hasBlockingIssues(r)).toBe(false);
  });
});

