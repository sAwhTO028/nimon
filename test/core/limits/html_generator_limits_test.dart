import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/limits/html_generator_limits.dart';

void main() {
  group('html_generator_limits normalization', () {
    test('level normalization', () {
      expect(normalizeHtmlLevel('1.N4/A2'), 'N4/A2');
      expect(normalizeHtmlLevel('N4'), 'N4/A2');
    });

    test('duration normalization', () {
      expect(normalizeHtmlDuration('2. 5-7 mins'), '5-7 mins');
      expect(normalizeHtmlDuration('5_7'), '5-7 mins');
    });

    test('language normalization (config lookup only)', () {
      expect(normalizeHtmlLanguage('1. Jp (Japanese)'), HtmlLearningLanguage.jp);
      expect(normalizeHtmlLanguage('Japanese'), HtmlLearningLanguage.jp);

      // English values are supported for config lookup only.
      // This does NOT enable English learning in app behavior.
      expect(normalizeHtmlLanguage('English'), HtmlLearningLanguage.en);
      expect(normalizeHtmlLanguage('en'), HtmlLearningLanguage.en);
    });

    test('prompt mode normalization', () {
      expect(normalizeHtmlPromptMode('AI_mode'), HtmlPromptMode.ai);
      expect(normalizeHtmlPromptMode('Manual_mode'), HtmlPromptMode.manual);
    });

    test('publish kind normalization', () {
      expect(normalizeHtmlPublishKind('2. FULL'), HtmlPublishKind.fullLearn);
      expect(normalizeHtmlPublishKind('read_only_v1'), HtmlPublishKind.readOnly);
      expect(normalizeHtmlPublishKind('full_learn_v1'), HtmlPublishKind.fullLearn);
    });
  });

  group('slider behavior', () {
    test('slider enabled only for FULL + AI', () {
      expect(
        HtmlGeneratorLimits.isSliderEnabled(
          publishKind: HtmlPublishKind.readOnly,
          mode: HtmlPromptMode.ai,
        ),
        isFalse,
      );
      expect(
        HtmlGeneratorLimits.isSliderEnabled(
          publishKind: HtmlPublishKind.fullLearn,
          mode: HtmlPromptMode.manual,
        ),
        isFalse,
      );
      expect(
        HtmlGeneratorLimits.isSliderEnabled(
          publishKind: HtmlPublishKind.fullLearn,
          mode: HtmlPromptMode.ai,
        ),
        isTrue,
      );
    });
  });

  group('sentence limits from HTML', () {
    test('AI + JP + 5-7 mins + N4/A2', () {
      final lim = HtmlGeneratorLimits.sentenceLimit(
        mode: HtmlPromptMode.ai,
        language: HtmlLearningLanguage.jp,
        duration: '5-7 mins',
        level: 'N4/A2',
      );
      expect(lim, isNotNull);
      expect(lim!.minSentences, 42);
      expect(lim.maxSentences, 60);
      expect(lim.minChars, 750);
      expect(lim.maxChars, 1100);
    });

    test('Manual + JP + 5-7 mins + N4/A2', () {
      final lim = HtmlGeneratorLimits.sentenceLimit(
        mode: HtmlPromptMode.manual,
        language: HtmlLearningLanguage.jp,
        duration: '5-7 mins',
        level: 'N4/A2',
      );
      expect(lim, isNotNull);
      expect(lim!.minSentences, 32);
      expect(lim.maxSentences, 50);
      expect(lim.minChars, 550);
      expect(lim.maxChars, 900);
    });
  });

  group('learn limits from HTML', () {
    test('JP + 5-7 mins + N4/A2 vocabulary', () {
      final lim = HtmlGeneratorLimits.vocabularyLimit(
        language: HtmlLearningLanguage.jp,
        duration: '5-7 mins',
        level: 'N4/A2',
      );
      expect(lim, isNotNull);
      expect(lim!.manualMin, 12);
      expect(lim.manualMax, 24);
      expect(lim.defaultValue, 16);
    });

    test('JP + 5-7 mins + N4/A2 grammar', () {
      final lim = HtmlGeneratorLimits.grammarLimit(
        language: HtmlLearningLanguage.jp,
        duration: '5-7 mins',
        level: 'N4/A2',
      );
      expect(lim, isNotNull);
      expect(lim!.manualMin, 4);
      expect(lim.manualMax, 10);
      expect(lim.defaultValue, 6);
    });
  });

  group('quiz limits from HTML', () {
    test('5-7 mins + N4/A2 quiz defaults', () {
      final vocab = HtmlGeneratorLimits.quizLimit(
        duration: '5-7 mins',
        level: 'N4/A2',
        quizCategory: 'Vocabulary Quiz',
      );
      final grammar = HtmlGeneratorLimits.quizLimit(
        duration: '5-7 mins',
        level: 'N4/A2',
        quizCategory: 'Grammar Quiz',
      );
      final sentence = HtmlGeneratorLimits.quizLimit(
        duration: '5-7 mins',
        level: 'N4/A2',
        quizCategory: 'Sentence Quiz',
      );
      final total = HtmlGeneratorLimits.quizLimit(
        duration: '5-7 mins',
        level: 'N4/A2',
        quizCategory: 'Total Quiz',
      );

      expect(vocab, isNotNull);
      expect(grammar, isNotNull);
      expect(sentence, isNotNull);
      expect(total, isNotNull);

      expect(vocab!.defaultValue, 11);
      expect(grammar!.defaultValue, 5);
      expect(sentence!.defaultValue, 4);
      expect(total!.defaultValue, 21);
    });
  });

  group('selectedFullLearnLimits', () {
    test('AI + JP + 5-7 mins + N4/A2 + default', () {
      final sel = HtmlGeneratorLimits.selectedFullLearnLimits(
        mode: HtmlPromptMode.ai,
        language: HtmlLearningLanguage.jp,
        duration: '5-7 mins',
        level: 'N4/A2',
        preset: HtmlLimitPreset.defaultValue,
      );
      expect(sel, isNotNull);
      expect(sel!.vocabularyCount, 16);
      expect(sel.grammarCount, 6);
      expect(sel.vocabularyQuizCount, 11);
      expect(sel.grammarQuizCount, 5);
      expect(sel.sentenceQuizCount, 4);
      expect(sel.totalQuizCount, 21);
    });
  });
}

