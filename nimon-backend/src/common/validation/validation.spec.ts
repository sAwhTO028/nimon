import {
  normalizeEmailInput,
  validateEmailFormat,
  validatePasswordRegister,
} from './auth-validation';
import { validateCollectionName } from './collection-validation';
import {
  GRAMMAR_PATTERN_LIMITS,
  QUIZ_GLOBAL_HARD_MAX,
  QUIZ_LIMITS,
  VOCABULARY_LIMITS,
  validateGrammarPatternTitle,
  validateQuizItem,
} from './learn-validation';
import {
  STORY_SENTENCE_LIMITS,
  validateStoryDescription,
  validateStoryTitle,
} from './story-validation';
import { ValidationMode } from './validation-mode';
import { hasBlockingIssues } from './validation-result';
import {
  validateProfileBio,
  validateProfileDisplayName,
  validateProfileHandle,
} from './profile-validation';
import { isReservedHandle } from './reserved-words';
describe('profile-validation', () => {
  it('display name min/max', () => {
    const empty = validateProfileDisplayName('');
    expect(hasBlockingIssues(empty)).toBe(true);
    const okLen = validateProfileDisplayName('あ'.repeat(30));
    expect(hasBlockingIssues(okLen)).toBe(false);
    const tooLong = validateProfileDisplayName('x'.repeat(31));
    expect(hasBlockingIssues(tooLong)).toBe(true);
  });

  it('handle allowed / disallowed characters', () => {
    expect(hasBlockingIssues(validateProfileHandle('ab'))).toBe(true);
    expect(hasBlockingIssues(validateProfileHandle('abc'))).toBe(false);
    expect(hasBlockingIssues(validateProfileHandle('Bad Upper'))).toBe(true);
    expect(hasBlockingIssues(validateProfileHandle('has space'))).toBe(true);
    expect(hasBlockingIssues(validateProfileHandle('a..b'))).toBe(true);
    expect(hasBlockingIssues(validateProfileHandle('.abc'))).toBe(true);
    expect(hasBlockingIssues(validateProfileHandle('abc.'))).toBe(true);
  });

  it('reserved handle blocked', () => {
    expect(hasBlockingIssues(validateProfileHandle('nimon'))).toBe(true);
    expect(isReservedHandle('nimon')).toBe(true);
  });

  it('bio max lines', () => {
    const okBio = validateProfileBio('one\ntwo\nthree');
    expect(hasBlockingIssues(okBio)).toBe(false);
    const bad = validateProfileBio('a\nb\nc\nd');
    expect(hasBlockingIssues(bad)).toBe(true);
  });
});

describe('story-validation', () => {
  it('title required for publish', () => {
    const r = validateStoryTitle('', ValidationMode.ReadOnlyPublish);
    expect(hasBlockingIssues(r)).toBe(true);
  });

  it('draft title blocks unsafe markup / line breaks only', () => {
    expect(
      hasBlockingIssues(validateStoryTitle('<b>x</b>', ValidationMode.Draft)),
    ).toBe(true);
    expect(
      hasBlockingIssues(validateStoryTitle('hi\nyo', ValidationMode.Draft)),
    ).toBe(true);
    expect(
      hasBlockingIssues(validateStoryTitle('.....', ValidationMode.Draft)),
    ).toBe(false);
    expect(
      hasBlockingIssues(validateStoryTitle('abcde', ValidationMode.Draft)),
    ).toBe(false);
  });

  it('description URL limit applies to publish modes, not draft', () => {
    const twoUrlsDraft = validateStoryDescription(
      'see https://a.com and https://b.com',
      ValidationMode.Draft,
    );
    expect(hasBlockingIssues(twoUrlsDraft)).toBe(false);
    const twoUrlsPublish = validateStoryDescription(
      'see https://a.com and https://b.com',
      ValidationMode.ReadOnlyPublish,
    );
    expect(hasBlockingIssues(twoUrlsPublish)).toBe(true);
  });

  it('sentence limit constants', () => {
    expect(STORY_SENTENCE_LIMITS.N5['3_5'].minSentences).toBe(10);
    expect(STORY_SENTENCE_LIMITS.N5['3_5'].maxChars).toBe(900);
    expect(STORY_SENTENCE_LIMITS.N1['7_9'].maxChars).toBe(2700);
  });
});

describe('learn limits constants', () => {
  it('vocab limits', () => {
    expect(VOCABULARY_LIMITS.N5['3_5']).toEqual({ min: 8, max: 18 });
    expect(VOCABULARY_LIMITS.N3['7_9']).toEqual({ min: 25, max: 55 });
  });

  it('grammar limits', () => {
    expect(GRAMMAR_PATTERN_LIMITS.N4['5_7']).toEqual({ min: 5, max: 8 });
  });

  it('quiz limits + global max', () => {
    expect(QUIZ_LIMITS.N5['7_9'].absoluteMax).toBe(18);
    expect(QUIZ_LIMITS.N3['7_9'].absoluteMax).toBe(24);
    expect(QUIZ_GLOBAL_HARD_MAX).toBe(24);
    expect(
      Math.max(
        ...Object.values(QUIZ_LIMITS).flatMap((row) =>
          Object.values(row).map((x) => x.absoluteMax),
        ),
      ),
    ).toBeLessThanOrEqual(QUIZ_GLOBAL_HARD_MAX);
  });

  it('grammar title validator', () => {
    expect(hasBlockingIssues(validateGrammarPatternTitle('x'))).toBe(true);
    expect(hasBlockingIssues(validateGrammarPatternTitle('だめ'))).toBe(false);
  });

  it('quiz item basics', () => {
    const bad = validateQuizItem({
      category: 'Other',
      question: 'x',
      options: ['a'],
      correctAnswer: 'a',
    });
    expect(hasBlockingIssues(bad)).toBe(true);
    const good = validateQuizItem({
      category: 'Vocabulary',
      question: 'What means hello?',
      options: ['a', 'b', 'c', 'd'],
      correctAnswer: 'a',
    });
    expect(hasBlockingIssues(good)).toBe(false);
  });
});

describe('collection-validation', () => {
  it('rejects script / only symbols', () => {
    expect(hasBlockingIssues(validateCollectionName('<script>x</script>'))).toBe(
      true,
    );
    expect(hasBlockingIssues(validateCollectionName('@@@@'))).toBe(true);
    expect(hasBlockingIssues(validateCollectionName('My picks'))).toBe(false);
  });
});

describe('auth-validation', () => {
  it('email normalization', () => {
    expect(normalizeEmailInput('  Test@Mail.COM ')).toBe('test@mail.com');
  });

  it('password min/max', () => {
    expect(hasBlockingIssues(validatePasswordRegister('short'))).toBe(true);
    expect(hasBlockingIssues(validatePasswordRegister('x'.repeat(65)))).toBe(
      true,
    );
    expect(hasBlockingIssues(validatePasswordRegister('goodPass12'))).toBe(
      false,
    );
  });

  it('email format', () => {
    expect(hasBlockingIssues(validateEmailFormat('not-an-email'))).toBe(true);
    expect(hasBlockingIssues(validateEmailFormat('ok@example.com'))).toBe(
      false,
    );
  });
});
