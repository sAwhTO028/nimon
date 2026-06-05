import { validateStoryPublishInput, storyPublishInputFromDraftRow } from './publish-validation';
import { ValidationMode } from './validation-mode';
import { hasBlockingIssues } from './validation-result';

describe('publish-validation', () => {
  const sentences = Array.from({ length: 24 }, () => ({
    content: { japaneseText: 'あ'.repeat(15) }, // 360 chars
  }));

  it('read-only: missing title => blocking', () => {
    const r = validateStoryPublishInput(
      {
        title: '',
        description: null,
        levelRaw: 'n5',
        targetDurationBandKey: '3_5',
        promptSourceNote: 'promptDataTab=Manual_mode',
        sentences,
        vocabEntries: [],
        grammarEntries: [],
        quizEntries: [],
        moduleWorkflowStatuses: {},
      },
      ValidationMode.ReadOnlyPublish,
    );
    expect(hasBlockingIssues(r)).toBe(true);
  });

  it('read-only: missing learn layers allowed', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: null,
        levelRaw: 'n5',
        targetDurationBandKey: '3_5',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentences,
        vocabEntries: [],
        grammarEntries: [],
        quizEntries: [],
        moduleWorkflowStatuses: {},
      },
      ValidationMode.ReadOnlyPublish,
    );
    expect(hasBlockingIssues(r)).toBe(false);
  });

  it('read-only: blocks unsafe title', () => {
    const r = validateStoryPublishInput(
      {
        title: '<script>x</script>',
        description: null,
        levelRaw: 'n5',
        targetDurationBandKey: '3_5',
        promptSourceNote: 'promptDataTab=Manual_mode',
        sentences,
        vocabEntries: [],
        grammarEntries: [],
        quizEntries: [],
        moduleWorkflowStatuses: {},
      },
      ValidationMode.ReadOnlyPublish,
    );
    expect(hasBlockingIssues(r)).toBe(true);
  });

  it('read-only: sentence limits when band exists', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'desc',
        levelRaw: 'n5',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentences: [{ content: { japaneseText: '短い' } }],
        vocabEntries: [],
        grammarEntries: [],
        quizEntries: [],
        moduleWorkflowStatuses: {},
      },
      ValidationMode.ReadOnlyPublish,
    );
    expect(hasBlockingIssues(r)).toBe(true);
  });

  it('full learn: missing vocab meaning', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'd',
        levelRaw: 'n5',
        targetDurationBandKey: '3_5',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentences,
        vocabEntries: [
          { content: { termJapanese: '猫', glosses: {}, type: 'vocabulary' } },
        ],
        grammarEntries: [{ content: { headline: 'パターン' } }],
        quizEntries: [
          {
            content: {
              category: 'vocabulary',
              prompt: 'Question text long enough here?',
              options: ['a', 'b', 'c', 'd'],
              correctIndex: 0,
            },
          },
        ],
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
  });

  const enSentences = Array.from({ length: 24 }, () => ({
    content: { japaneseText: 'a'.repeat(50) },
  }));

  const fullLearnModules = {
    vocabulary_kanji: 'completed',
    grammar: 'completed',
    quiz: 'completed',
    audio: 'completed',
  };

  const fullLearnQuiz = [
    {
      content: {
        category: 'vocabulary',
        prompt: 'Question text long enough here?',
        options: ['a', 'b', 'c', 'd'],
        correctIndex: 0,
      },
    },
  ];

  const fullLearnGrammar = [{ content: { headline: 'パターン' } }];

  const enFullLearnVocab = (first: Record<string, unknown>) => [
    { content: first },
    ...Array.from({ length: 7 }, (_, i) => ({
      content: {
        termJapanese: `word${i}`,
        type: 'vocabulary',
        glosses: { my: 'm' },
      },
    })),
  ];

  const enFullLearnGrammar = Array.from({ length: 3 }, (_, i) => ({
    content: { headline: `pattern${i}`.padEnd(3, 'あ') },
  }));

  const enFullLearnQuizzes = [
    ...Array.from({ length: 5 }, (_, i) => ({
      content: {
        category: 'vocabulary',
        prompt: `Vocab question ${i} long enough?`,
        options: ['a', 'b', 'c', 'd'],
        correctIndex: 0,
      },
    })),
    ...Array.from({ length: 3 }, (_, i) => ({
      content: {
        category: 'grammar',
        prompt: `Grammar question ${i} long enough?`,
        options: ['a', 'b', 'c', 'd'],
        correctIndex: 0,
      },
    })),
    ...Array.from({ length: 3 }, (_, i) => ({
      content: {
        category: 'sample_sentence',
        prompt: `Sentence question ${i} long enough?`,
        options: ['a', 'b', 'c', 'd'],
        correctIndex: 0,
      },
    })),
  ];

  it('full learn: invalid furigana for kanji vocab when learningLanguage=ja', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'd',
        levelRaw: 'n5',
        targetDurationBandKey: '3_5',
        learningLanguage: 'ja',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentences,
        vocabEntries: [
          {
            content: {
              termJapanese: '猫',
              type: 'kanji',
              reading: 'invalidlatin',
              glosses: { my: 'cat' },
            },
          },
        ],
        grammarEntries: [{ content: { headline: 'パターン' } }],
        quizEntries: [
          {
            content: {
              category: 'vocabulary',
              prompt: 'Question text long enough here?',
              options: ['a', 'b', 'c', 'd'],
              correctIndex: 0,
            },
          },
        ],
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
  });

  it('full learn: JA kanji vocab without reading blocks', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'd',
        levelRaw: 'n5',
        targetDurationBandKey: '3_5',
        learningLanguage: 'ja',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentences,
        vocabEntries: [
          {
            content: {
              termJapanese: '猫',
              type: 'kanji',
              glosses: { my: 'cat' },
            },
          },
        ],
        grammarEntries: fullLearnGrammar,
        quizEntries: fullLearnQuiz,
        moduleWorkflowStatuses: fullLearnModules,
      },
      ValidationMode.FullLearnPublish,
    );
    expect(hasBlockingIssues(r)).toBe(true);
  });

  it('full learn: legacy null learningLanguage still enforces furigana', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'd',
        levelRaw: 'n5',
        targetDurationBandKey: '3_5',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentences,
        vocabEntries: [
          {
            content: {
              termJapanese: '猫',
              type: 'kanji',
              glosses: { my: 'cat' },
            },
          },
        ],
        grammarEntries: fullLearnGrammar,
        quizEntries: fullLearnQuiz,
        moduleWorkflowStatuses: fullLearnModules,
      },
      ValidationMode.FullLearnPublish,
    );
    expect(hasBlockingIssues(r)).toBe(true);
  });

  it('full learn: EN kanji vocab without reading passes', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'd',
        levelRaw: 'n5',
        targetDurationBandKey: '3_5',
        learningLanguage: 'en',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentences: enSentences,
        vocabEntries: enFullLearnVocab({
          termJapanese: '猫',
          type: 'kanji',
          glosses: { my: 'cat' },
        }),
        grammarEntries: enFullLearnGrammar,
        quizEntries: enFullLearnQuizzes,
        moduleWorkflowStatuses: fullLearnModules,
      },
      ValidationMode.FullLearnPublish,
    );
    expect(hasBlockingIssues(r)).toBe(false);
  });

  it('full learn: EN Latin reading on kanji vocab passes', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'd',
        levelRaw: 'n5',
        targetDurationBandKey: '3_5',
        learningLanguage: 'en',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentences: enSentences,
        vocabEntries: enFullLearnVocab({
          termJapanese: '猫',
          type: 'kanji',
          reading: 'invalidlatin',
          glosses: { my: 'cat' },
        }),
        grammarEntries: enFullLearnGrammar,
        quizEntries: enFullLearnQuizzes,
        moduleWorkflowStatuses: fullLearnModules,
      },
      ValidationMode.FullLearnPublish,
    );
    expect(hasBlockingIssues(r)).toBe(false);
  });

  it('full learn: quiz missing correct answer', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'd',
        levelRaw: 'n5',
        targetDurationBandKey: '3_5',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentences,
        vocabEntries: [
          {
            content: {
              termJapanese: '猫',
              type: 'vocabulary',
              reading: 'ねこ',
              glosses: { my: 'cat' },
            },
          },
        ],
        grammarEntries: [{ content: { headline: 'パターン' } }],
        quizEntries: [
          {
            content: {
              category: 'vocabulary',
              prompt: 'Question text long enough here?',
              options: ['a', 'b', 'c', 'd'],
              correctIndex: 9,
            },
          },
        ],
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
  });

  it('full learn: quiz global max 24 when counts enforced', () => {
    const quizzes = Array.from({ length: 25 }, (_, i) => ({
      content: {
        category: 'vocabulary',
        prompt: `Question number ${i} long enough text here?`,
        options: ['a', 'b', 'c', 'd'],
        correctIndex: 0,
      },
    }));
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'd',
        levelRaw: 'n5',
        targetDurationBandKey: '7_9',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentences: Array.from({ length: 30 }, () => ({
          content: { japaneseText: 'あ' },
        })),
        vocabEntries: Array.from({ length: 40 }, (_, i) => ({
          content: {
            termJapanese: `w${i}`,
            glosses: { my: 'm' },
            reading: 'あ',
            type: 'vocabulary',
          },
        })),
        grammarEntries: Array.from({ length: 10 }, (_, i) => ({
          content: { headline: `g${i}`.padEnd(3, 'あ') },
        })),
        quizEntries: quizzes,
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
  });

  it('missing level/duration blocks under HTML rules', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: null,
        levelRaw: '',
        targetDurationBandKey: null,
        sentences,
        vocabEntries: [],
        grammarEntries: [],
        quizEntries: [],
        moduleWorkflowStatuses: {},
      },
      ValidationMode.ReadOnlyPublish,
    );
    expect(hasBlockingIssues(r)).toBe(true);
  });

  it('storyPublishInputFromDraftRow maps prisma-like draft', () => {
    const input = storyPublishInputFromDraftRow({
      title: 'Hello world title',
      description: '',
      level: 'n4',
      targetDurationBandKey: null,
      promptSourceNote: 'promptDataTab=AI_mode',
      moduleWorkflowStatuses: { vocabulary_kanji: 'completed' },
      sentences: [{ content: { japaneseText: 'テスト' } }],
      vocabEntries: [],
      grammarEntries: [],
      quizEntries: [],
    });
    expect(input.levelRaw).toBe('n4');
    expect(input.sentences).toHaveLength(1);
    expect(input.promptSourceNote).toContain('AI_mode');
  });

  it('storyPublishInputFromDraftRow includes learningLanguage=en', () => {
    const input = storyPublishInputFromDraftRow({
      title: 'Hello',
      learningLanguage: 'en',
      sentences: [{ content: { japaneseText: 'test' } }],
    });
    expect(input.learningLanguage).toBe('en');
  });
});
