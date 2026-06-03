import {
  feedSummaryFromContent,
  feedSummaryFromDraft,
} from './published-mono-feed-summary';

describe('published-mono-feed-summary', () => {
  it('feedSummaryFromContent extracts cover, publishKind, audio, and counts', () => {
    const content = {
      publishKind: 'full_learn_v1',
      core: {
        coverImageUrl: ' https://cdn/cover.jpg ',
        sentences: [{}, {}, {}],
      },
      learn: {
        vocabularyKanji: { entries: [{}, {}] },
        grammar: { entries: [{}] },
        quiz: { entries: [{}, {}, {}, {}] },
        audio: { storyAudio: { sourceUrl: 'https://cdn/audio.mp3' } },
      },
    };
    const s = feedSummaryFromContent(content);
    expect(s.coverImageUrl).toBe('https://cdn/cover.jpg');
    expect(s.publishKind).toBe('full_learn_v1');
    expect(s.hasAudio).toBe(true);
    expect(s.sentenceCount).toBe(3);
    expect(s.vocabCount).toBe(2);
    expect(s.grammarCount).toBe(1);
    expect(s.quizCount).toBe(4);
  });

  it('feedSummaryFromDraft matches draft row counts', () => {
    const draft = {
      coverImageUrl: 'cover.png',
      sentences: [{ order: 0 }, { order: 1 }],
      vocabEntries: [{ order: 0 }],
      grammarEntries: [],
      quizEntries: [{ order: 0 }, { order: 1 }],
      audios: [],
    };
    const s = feedSummaryFromDraft(draft, 'read_only_v1');
    expect(s.coverImageUrl).toBe('cover.png');
    expect(s.publishKind).toBe('read_only_v1');
    expect(s.hasAudio).toBe(false);
    expect(s.sentenceCount).toBe(2);
    expect(s.vocabCount).toBe(1);
    expect(s.grammarCount).toBe(0);
    expect(s.quizCount).toBe(2);
  });
});
