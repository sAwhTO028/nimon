import { BadRequestException } from '@nestjs/common';
import {
  assertDistinctLanguagePair,
  isJapaneseLearningWireCode,
  normalizeV1LearningLanguage,
  resolvePublishLanguageTags,
  safeV1LearningLanguage,
} from './language-pair-validation';

describe('language-pair-validation', () => {
  it('isJapaneseLearningWireCode gates furigana by explicit en only', () => {
    expect(isJapaneseLearningWireCode('ja')).toBe(true);
    expect(isJapaneseLearningWireCode('en')).toBe(false);
    expect(isJapaneseLearningWireCode(null)).toBe(true);
    expect(isJapaneseLearningWireCode('')).toBe(true);
    expect(isJapaneseLearningWireCode('ko')).toBe(true);
  });

  it('allows ja + my', () => {
    expect(() => assertDistinctLanguagePair('my', 'ja')).not.toThrow();
  });

  it('allows ja + en', () => {
    expect(() => assertDistinctLanguagePair('en', 'ja')).not.toThrow();
  });

  it('allows en + my', () => {
    expect(() => assertDistinctLanguagePair('my', 'en')).not.toThrow();
  });

  it('allows en + ja', () => {
    expect(() => assertDistinctLanguagePair('ja', 'en')).not.toThrow();
  });

  it('rejects en + en', () => {
    expect(() => assertDistinctLanguagePair('en', 'en')).toThrow(
      BadRequestException,
    );
  });

  it('normalizeV1LearningLanguage accepts en', () => {
    expect(normalizeV1LearningLanguage('en')).toBe('en');
    expect(safeV1LearningLanguage('xx')).toBe('ja');
    expect(safeV1LearningLanguage('en')).toBe('en');
  });

  it('rejects ja + ja', () => {
    expect(() => assertDistinctLanguagePair('ja', 'ja')).toThrow(
      BadRequestException,
    );
  });

  it('resolvePublishLanguageTags uses draft over prefs', () => {
    const t = resolvePublishLanguageTags({
      draftContentLocale: 'my',
      draftLearningLanguage: 'ja',
      prefContentLocale: 'en',
      prefLearningLanguage: 'ja',
    });
    expect(t).toEqual({ contentLocale: 'my', learningLanguage: 'ja' });
  });

  it('resolvePublishLanguageTags falls back to prefs then defaults', () => {
    const t = resolvePublishLanguageTags({
      draftContentLocale: null,
      draftLearningLanguage: null,
      prefContentLocale: 'my',
      prefLearningLanguage: 'ja',
    });
    expect(t).toEqual({ contentLocale: 'my', learningLanguage: 'ja' });
  });

  it('resolvePublishLanguageTags preserves en learning from draft', () => {
    const t = resolvePublishLanguageTags({
      draftContentLocale: 'my',
      draftLearningLanguage: 'en',
      prefContentLocale: 'en',
      prefLearningLanguage: 'ja',
    });
    expect(t).toEqual({ contentLocale: 'my', learningLanguage: 'en' });
  });

  it('resolvePublishLanguageTags rejects ja+ja from draft', () => {
    expect(() =>
      resolvePublishLanguageTags({
        draftContentLocale: 'ja',
        draftLearningLanguage: 'ja',
        prefContentLocale: 'en',
        prefLearningLanguage: 'ja',
      }),
    ).toThrow(BadRequestException);
  });
});
