import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/limits/html_generator_limits.dart';

void main() {
  test('resolveHtmlLearningLanguageFromWire maps ja/en and falls back to jp', () {
    expect(resolveHtmlLearningLanguageFromWire('ja'), HtmlLearningLanguage.jp);
    expect(resolveHtmlLearningLanguageFromWire('en'), HtmlLearningLanguage.en);
    expect(resolveHtmlLearningLanguageFromWire(null), HtmlLearningLanguage.jp);
    expect(resolveHtmlLearningLanguageFromWire('ko'), HtmlLearningLanguage.jp);
  });
}
