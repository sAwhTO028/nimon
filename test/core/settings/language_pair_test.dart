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
}
