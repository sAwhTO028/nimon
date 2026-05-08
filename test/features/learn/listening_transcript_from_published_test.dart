import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/learn/listening_transcript_from_published.dart';

void main() {
  test('empty / invalid content -> no lines', () {
    expect(listeningTranscriptLinesFromPublishedCore(null), isEmpty);
    expect(listeningTranscriptLinesFromPublishedCore(<String, Object?>{}),
        isEmpty);
  });

  test('maps core sentences to lines with ruby and explanations', () {
    const sentence = <String, Object?>{
      'japaneseText': '今日はいい天気です。',
      'furiganaSpans': <Object?>[
        <String, Object>{'start': 5, 'end': 7, 'reading': 'てんき'},
      ],
      'meanings': <String, String>{
        'en': 'Nice weather today.',
        'my': 'source line',
      },
    };
    final content = <String, Object?>{
      'core': {
        'sentences': <Object?>[
          <String, Object?>{'content': sentence},
        ],
      },
    };

    final lines = listeningTranscriptLinesFromPublishedCore(content);
    expect(lines, hasLength(1));
    expect(lines.first.japanese, '今日はいい天気です。');
    expect(lines.first.rubyTokens, isNotNull);
    expect(lines.first.rubyTokens, isNotEmpty);
    expect(
      lines.first.rubyTokens!.where((t) => t.reading == 'てんき'),
      isNotEmpty,
    );
    expect(lines.first.publishedExplanation?.en, 'Nice weather today.');
    expect(lines.first.publishedExplanation?.my, 'source line');
  });

  test('no spans -> plain line, still has text', () {
    final content = <String, Object?>{
      'core': {
        'sentences': <Object?>[
          <String, Object?>{
            'content': <String, Object?>{
              'japaneseText': 'さようなら。',
            },
          },
        ],
      },
    };
    final lines = listeningTranscriptLinesFromPublishedCore(content);
    expect(lines, hasLength(1));
    expect(lines.first.rubyTokens, isNull);
    expect(lines.first.japanese, 'さようなら。');
  });
}
