import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/validation/publish_validation.dart';
import 'package:nimon/core/validation/validation_mode.dart';
import 'package:nimon/core/validation/validation_result.dart';

StoryPublishData _base({
  String? title,
  String? levelRaw,
  String? targetBand,
  List<Map<String, Object?>>? sentences,
  List<Map<String, Object?>>? vocab,
}) {
  return StoryPublishData(
    title: title ?? 'Hello title ok long enough',
    description: '',
    levelRaw: levelRaw,
    targetDurationBandKey: targetBand,
    promptSourceNote: 'promptDataTab=Manual_mode',
    sentences: sentences ??
        [
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
          {
            'content': {'japaneseText': 'あああああああああああああああ'},
          },
        ],
    vocabEntries: vocab ?? const [],
    grammarEntries: const [],
    quizEntries: const [],
    moduleWorkflowStatuses: const {},
  );
}

void main() {
  group('publish gate', () {
    test('ReadOnlyPublish missing title blocks', () {
      final r = validateStoryPublishData(
        _base(title: ''),
        ValidationMode.readOnlyPublish,
      );
      expect(hasBlockingIssues(r), true);
    });

    test('ReadOnlyPublish missing learn layers is OK', () {
      final r = validateStoryPublishData(
        _base(levelRaw: 'N5', targetBand: '3_5'),
        ValidationMode.readOnlyPublish,
      );
      expect(hasBlockingIssues(r), false);
    });

    test('ReadOnlyPublish HTML in title blocks', () {
      final r = validateStoryPublishData(
        _base(title: '<script>x</script>aaaaaaaa'),
        ValidationMode.readOnlyPublish,
      );
      expect(hasBlockingIssues(r), true);
    });

    test('FullLearnPublish missing vocab meaning blocks', () {
      final modules = {
        'vocabulary_kanji': 'completed',
        'grammar': 'completed',
        'quiz': 'completed',
        'audio': 'completed',
      };
      final r = validateStoryPublishData(
        StoryPublishData(
          title: 'Hello title ok long enough',
          description: '',
          levelRaw: null,
          targetDurationBandKey: null,
          sentences: [
            {
              'content': {'japaneseText': 'ねこ。'}
            },
          ],
          vocabEntries: [
            {
              'content': {
                'termJapanese': '猫',
                'type': 'vocabulary',
                'reading': 'ねこ',
                'glosses': {'en': '', 'my': ''},
              },
            },
          ],
          grammarEntries: [
            {
              'content': {'headline': 'は particle'}
            },
          ],
          quizEntries: [
            {
              'content': {
                'category': 'vocabulary',
                'prompt': 'What means hello in Japanese?',
                'options': ['a', 'b', 'c', 'd'],
                'correctIndex': 0,
              },
            },
          ],
          moduleWorkflowStatuses: modules,
        ),
        ValidationMode.fullLearnPublish,
      );
      expect(hasBlockingIssues(r), true);
    });

    test('warning-only description empty does not block', () {
      final r = validateStoryPublishData(
        _base(title: 'Hello title ok', levelRaw: 'N5', targetBand: '3_5'),
        ValidationMode.readOnlyPublish,
      );
      expect(hasBlockingIssues(r), false);
      expect(hasWarningIssues(r), true);
    });
  });
}
