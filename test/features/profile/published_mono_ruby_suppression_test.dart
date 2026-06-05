import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/learn/listening_transcript_from_published.dart';
import 'package:nimon/features/profile/data/published_mono_detail_parser.dart';

Map<String, Object?> _publishedCore({
  required String learningLanguage,
  required String japaneseText,
  List<Map<String, Object?>>? furiganaSpans,
}) {
  return {
    'learningLanguage': learningLanguage,
    'core': {
      'sentences': [
        {
          'content': {
            'japaneseText': japaneseText,
            if (furiganaSpans != null) 'furiganaSpans': furiganaSpans,
          },
        },
      ],
    },
  };
}

void main() {
  group('published mono ruby suppression', () {
    test('JA keeps ruby tokens when furiganaSpans exist', () {
      final content = _publishedCore(
        learningLanguage: 'ja',
        japaneseText: '天気',
        furiganaSpans: [
          {'start': 0, 'end': 2, 'reading': 'てんき'},
        ],
      );
      final mono = buildMonoContentFromPublishedCore(
        'm1',
        'Title',
        content,
        learningLanguage: 'ja',
      );
      expect(mono, isNotNull);
      final line = mono!.pages.first.lines.first;
      expect(line.plainText, '天気');
      expect(line.tokens, isNotEmpty);
      expect(line.tokens.first.reading, 'てんき');
    });

    test('EN omits ruby tokens even when furiganaSpans exist', () {
      final content = _publishedCore(
        learningLanguage: 'en',
        japaneseText: 'Hello',
        furiganaSpans: [
          {'start': 0, 'end': 5, 'reading': 'invalidlatin'},
        ],
      );
      final mono = buildMonoContentFromPublishedCore(
        'm1',
        'Title',
        content,
        learningLanguage: 'en',
      );
      expect(mono, isNotNull);
      final line = mono!.pages.first.lines.first;
      expect(line.plainText, 'Hello');
      expect(line.tokens, isEmpty);
    });

    test('EN listening transcript uses plain text without ruby', () {
      final content = _publishedCore(
        learningLanguage: 'en',
        japaneseText: '天気',
        furiganaSpans: [
          {'start': 0, 'end': 2, 'reading': 'てんき'},
        ],
      );
      final lines = listeningTranscriptLinesFromPublishedCore(
        content,
        learningLanguage: 'en',
      );
      expect(lines, hasLength(1));
      expect(lines.first.japanese, '天気');
      expect(lines.first.rubyTokens, isNull);
    });

    test('JA listening transcript keeps ruby tokens', () {
      final content = _publishedCore(
        learningLanguage: 'ja',
        japaneseText: '天気',
        furiganaSpans: [
          {'start': 0, 'end': 2, 'reading': 'てんき'},
        ],
      );
      final lines = listeningTranscriptLinesFromPublishedCore(
        content,
        learningLanguage: 'ja',
      );
      expect(lines, hasLength(1));
      expect(lines.first.rubyTokens, isNotNull);
      expect(lines.first.rubyTokens, isNotEmpty);
    });
  });
}
