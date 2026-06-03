import { BadRequestException } from '@nestjs/common';
import {
  assertDistinctLanguagePair,
  resolvePublishLanguageTags,
} from './language-pair-validation';

describe('language-pair-validation', () => {
  it('allows ja + my', () => {
    expect(() => assertDistinctLanguagePair('my', 'ja')).not.toThrow();
  });

  it('allows ja + en', () => {
    expect(() => assertDistinctLanguagePair('en', 'ja')).not.toThrow();
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
