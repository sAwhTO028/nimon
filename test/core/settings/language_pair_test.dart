import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/settings/language_pair.dart';

void main() {
  test('detects ja+ja as same pair', () {
    expect(
      isSameLanguagePair(contentLocale: 'ja', learningLanguage: 'ja'),
      isTrue,
    );
  });

  test('allows ja+my', () {
    expect(
      isSameLanguagePair(contentLocale: 'my', learningLanguage: 'ja'),
      isFalse,
    );
  });

  test('allows ja+en', () {
    expect(
      isSameLanguagePair(contentLocale: 'en', learningLanguage: 'ja'),
      isFalse,
    );
  });

  test('detects en+en as same pair', () {
    expect(
      isSameLanguagePair(contentLocale: 'en', learningLanguage: 'en'),
      isTrue,
    );
  });

  test('allows en+my', () {
    expect(
      isSameLanguagePair(contentLocale: 'my', learningLanguage: 'en'),
      isFalse,
    );
  });

  test('allows en+ja', () {
    expect(
      isSameLanguagePair(contentLocale: 'ja', learningLanguage: 'en'),
      isFalse,
    );
  });

  test('safeLearningLanguageWireCode normalizes en and falls back unknown', () {
    expect(safeLearningLanguageWireCode('en'), 'en');
    expect(safeLearningLanguageWireCode('JA'), 'ja');
    expect(safeLearningLanguageWireCode('ko'), 'ja');
  });

  test('isJapaneseLearningWireCode gates furigana by explicit en only', () {
    expect(isJapaneseLearningWireCode('ja'), isTrue);
    expect(isJapaneseLearningWireCode('en'), isFalse);
    expect(isJapaneseLearningWireCode(null), isTrue);
    expect(isJapaneseLearningWireCode(''), isTrue);
    expect(isJapaneseLearningWireCode('ko'), isTrue);
  });
}
