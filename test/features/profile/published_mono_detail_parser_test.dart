import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/mono/mono_content_model.dart';
import 'package:nimon/features/mono/mono_line_explanation_display.dart';
import 'package:nimon/features/profile/data/published_mono_detail_parser.dart';

Map<String, Object?> _contentRoot({
  required List<Map<String, Object?>> sentenceContents,
}) {
  return {
    'core': {
      'sentences': [
        for (var i = 0; i < sentenceContents.length; i++)
          {
            'order': i,
            'content': sentenceContents[i],
          },
      ],
    },
  };
}

void main() {
  group('rubyTokensFromPublishedSentenceContent', () {
    test('maps furiganaSpans to MonoRubyToken with gaps', () {
      const jp = '図書館は近い。';
      final toks = rubyTokensFromPublishedSentenceContent(
        jp,
        {
          'japaneseText': jp,
          'furiganaSpans': [
            {'start': 0, 'end': 3, 'reading': 'としょかん'},
          ],
        },
      );
      expect(toks, isNotEmpty);
      expect(
        toks.first,
        isA<MonoRubyToken>().having((t) => t.text, 'text', '図書館'),
      );
      expect(
        toks.first.reading,
        'としょかん',
      );
    });

    test('returns empty when no furiganaSpans', () {
      const jp = 'abc';
      final toks = rubyTokensFromPublishedSentenceContent(
        jp,
        {'japaneseText': jp, 'furiganaSpans': <Object?>[]},
      );
      expect(toks, isEmpty);
    });
  });

  group('explanationFromPublishedSentenceContent', () {
    test('maps meanings.en and meanings.my', () {
      final e = explanationFromPublishedSentenceContent({
        'japaneseText': 'x',
        'meanings': {
          'en': '  English  ',
          'my': '  Source  ',
        },
      });
      expect(e, isNotNull);
      expect(e!.en, 'English');
      expect(e.my, 'Source');
    });

    test('accepts sourceMeaning / englishMeaning fallbacks', () {
      final e = explanationFromPublishedSentenceContent({
        'japaneseText': 'x',
        'sourceMeaning': 'S',
        'englishMeaning': 'E',
      });
      expect(e, isNotNull);
      expect(e!.my, 'S');
      expect(e.en, 'E');
    });

    test('returns null when no meaning fields', () {
      final e = explanationFromPublishedSentenceContent({
        'japaneseText': 'x',
      });
      expect(e, isNull);
    });
  });

  group('buildMonoContentFromPublishedCore', () {
    test('preserves plainText and adds tokens from spans', () {
      final root = _contentRoot(
        sentenceContents: [
          {
            'japaneseText': '図書館へ行く。',
            'furiganaSpans': [
              {'start': 0, 'end': 3, 'reading': 'としょかん'},
            ],
          },
        ],
      );
      final mc = buildMonoContentFromPublishedCore('id1', 'T', root);
      expect(mc, isNotNull);
      final line = mc!.pages.single.lines.single;
      expect(line.plainText, '図書館へ行く。');
      expect(line.tokens, isNotEmpty);
      expect(line.explanation, isNull);
    });

    test('plainText fallback when furiganaSpans missing', () {
      final root = _contentRoot(
        sentenceContents: [
          {'japaneseText': 'のみかん'},
        ],
      );
      final mc = buildMonoContentFromPublishedCore('id1', null, root);
      final line = mc!.pages.single.lines.single;
      expect(line.plainText, 'のみかん');
      expect(line.tokens, isEmpty);
    });

    test('maps meanings into explanation', () {
      final root = _contentRoot(
        sentenceContents: [
          {
            'japaneseText': '雨',
            'meanings': {'en': 'rain', 'my': 'မိုး'},
          },
        ],
      );
      final mc = buildMonoContentFromPublishedCore('id1', null, root);
      final line = mc!.pages.single.lines.single;
      expect(line.explanation?.en, 'rain');
      expect(line.explanation?.my, 'မိုး');
    });

    test('skips invalid furigana span ranges', () {
      final root = _contentRoot(
        sentenceContents: [
          {
            'japaneseText': 'ab',
            'furiganaSpans': [
              {'start': 99, 'end': 100, 'reading': 'x'},
            ],
          },
        ],
      );
      final mc = buildMonoContentFromPublishedCore('id1', null, root);
      final line = mc!.pages.single.lines.single;
      expect(line.tokens, isEmpty);
      expect(line.plainText, 'ab');
    });
  });

  group('monoLineExplanationDisplay', () {
    test('prefers source as primary when both present', () {
      final d = monoLineExplanationDisplay(
        const MonoExplanationLine(en: 'en', my: 'my'),
      );
      expect(d, isNotNull);
      expect(d!.primary, 'my');
      expect(d.secondary, 'en');
    });

    test('english alone becomes primary', () {
      final d = monoLineExplanationDisplay(
        const MonoExplanationLine(en: 'onlyEn', my: null),
      );
      expect(d!.primary, 'onlyEn');
      expect(d.secondary, isNull);
    });
  });
}
