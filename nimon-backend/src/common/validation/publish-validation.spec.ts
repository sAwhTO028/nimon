import { validateStoryPublishInput, storyPublishInputFromDraftRow } from './publish-validation';
import { ValidationMode } from './validation-mode';
import { hasBlockingIssues } from './validation-result';

describe('publish-validation', () => {
  const minimalSentences = [
    { content: { japaneseText: 'あ'.repeat(20) } },
  ];

  it('read-only: missing title => blocking', () => {
    const r = validateStoryPublishInput(
      {
        title: '',
        description: null,
        levelRaw: 'n5',
        targetDurationBandKey: null,
        sentences: minimalSentences,
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
        targetDurationBandKey: null,
        sentences: minimalSentences,
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
        targetDurationBandKey: null,
        sentences: minimalSentences,
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
        targetDurationBandKey: null,
        sentences: minimalSentences,
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

  it('full learn: invalid furigana for kanji vocab', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'd',
        levelRaw: 'n5',
        targetDurationBandKey: null,
        sentences: minimalSentences,
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

  it('full learn: quiz missing correct answer', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: 'd',
        levelRaw: 'n5',
        targetDurationBandKey: null,
        sentences: minimalSentences,
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

  it('warnings only do not set blocking flag', () => {
    const r = validateStoryPublishInput(
      {
        title: 'Valid story title',
        description: null,
        levelRaw: '',
        targetDurationBandKey: null,
        sentences: minimalSentences,
        vocabEntries: [],
        grammarEntries: [],
        quizEntries: [],
        moduleWorkflowStatuses: {},
      },
      ValidationMode.ReadOnlyPublish,
    );
    expect(r.ok).toBe(true);
    expect(r.issues.some((i) => i.severity === 'warning')).toBe(true);
  });

  it('storyPublishInputFromDraftRow maps prisma-like draft', () => {
    const input = storyPublishInputFromDraftRow({
      title: 'Hello world title',
      description: '',
      level: 'n4',
      targetDurationBandKey: null,
      moduleWorkflowStatuses: { vocabulary_kanji: 'completed' },
      sentences: [{ content: { japaneseText: 'テスト' } }],
      vocabEntries: [],
      grammarEntries: [],
      quizEntries: [],
    });
    expect(input.levelRaw).toBe('n4');
    expect(input.sentences).toHaveLength(1);
  });
});
