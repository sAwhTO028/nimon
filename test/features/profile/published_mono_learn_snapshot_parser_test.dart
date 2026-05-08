import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';
import 'package:nimon/features/profile/data/published_mono_learn_snapshot_parser.dart';

void main() {
  group('learnPublishedSnapshotFromContent', () {
    test('returns null when content is not a map', () {
      expect(learnPublishedSnapshotFromContent(null), isNull);
      expect(learnPublishedSnapshotFromContent('x'), isNull);
      expect(learnPublishedSnapshotFromContent(42), isNull);
    });

    test('returns null when learn is missing', () {
      expect(
        learnPublishedSnapshotFromContent(<String, Object?>{
          'core': {'sentences': <Object?>[]},
        }),
        isNull,
      );
    });

    test('schemaVersion 1 with vocab/grammar/quiz/audio parses', () {
      final snap = learnPublishedSnapshotFromContent(<String, Object?>{
        'learn': {
          'schemaVersion': 1,
          'vocabularyKanji': {
            'entries': [
              {
                'id': 'v1',
                'termJapanese': '本',
                'type': 'vocabulary',
                'glosses': {'en': 'book', 'my': 'စာအုပ်'},
              },
            ],
          },
          'grammar': {
            'entries': [
              {
                'id': 'g1',
                'headline': 'について',
                'meanings': {'en': 'about'},
              },
            ],
          },
          'quiz': {
            'entries': [
              {
                'id': 'q1',
                'category': 'vocabulary',
                'prompt': 'Q?',
                'options': <String>['a', 'b', 'c', 'd'],
                'correctIndex': 0,
              },
            ],
          },
          'audio': {
            'storyAudio': {
              'id': 'a1',
              'sourceUrl': 'https://cdn.example.com/a.mp3',
              'durationSeconds': 42,
            },
          },
        },
      });

      expect(snap, isNotNull);
      expect(snap!.schemaVersion, 1);
      expect(snap.vocabularyKanjiEntries, hasLength(1));
      expect(snap.vocabularyKanjiEntries.single.termJapanese, '本');
      expect(snap.grammarEntries, hasLength(1));
      expect(snap.quizEntries, hasLength(1));
      expect(snap.quizEntries.single.prompt, 'Q?');
      expect(snap.storyAudio?.sourceUrl, 'https://cdn.example.com/a.mp3');
      expect(snap.storyAudio?.durationSeconds, 42);
      expect(snap.hasAnyLearnData, isTrue);
    });

    test('missing sections yield empty lists', () {
      final snap = learnPublishedSnapshotFromContent(<String, Object?>{
        'learn': {
          'schemaVersion': 1,
        },
      });
      expect(snap, isNotNull);
      expect(snap!.vocabularyKanjiEntries, isEmpty);
      expect(snap.grammarEntries, isEmpty);
      expect(snap.quizEntries, isEmpty);
      expect(snap.storyAudio, isNull);
      expect(snap.hasAnyLearnData, isFalse);
    });

    test('non-list entries → empty lists', () {
      final snap = learnPublishedSnapshotFromContent(<String, Object?>{
        'learn': {
          'schemaVersion': 1,
          'vocabularyKanji': {'entries': 'bad'},
          'grammar': 'oops',
        },
      });
      expect(snap, isNotNull);
      final nonNullSnap = snap!;
      expect(nonNullSnap.vocabularyKanjiEntries, isEmpty);
      expect(nonNullSnap.grammarEntries, isEmpty);
    });

    test('malformed entry rows are skipped', () {
      final snap = learnPublishedSnapshotFromContent(<String, Object?>{
        'learn': {
          'schemaVersion': 1,
          'vocabularyKanji': {
            'entries': [
              'garbage',
              {
                'id': 'ok',
                'termJapanese': '雨',
                'type': 'vocabulary',
              },
            ],
          },
        },
      });
      expect(snap!.vocabularyKanjiEntries, hasLength(1));
      expect(snap.vocabularyKanjiEntries.single.id, 'ok');
    });

    test('unknown schemaVersion returns null', () {
      expect(
        learnPublishedSnapshotFromContent(<String, Object?>{
          'learn': {'schemaVersion': 2},
        }),
        isNull,
      );
    });

    test('omitted schemaVersion is treated as v1', () {
      final snap = learnPublishedSnapshotFromContent(<String, Object?>{
        'learn': {
          'vocabularyKanji': {
            'entries': [
              {'id': 'x', 'termJapanese': '猫', 'type': 'vocabulary'},
            ],
          },
        },
      });
      expect(snap, isNotNull);
      expect(snap!.schemaVersion, 1);
      expect(snap.vocabularyKanjiEntries.single.termJapanese, '猫');
    });

    test('storyAudio null in JSON → storyAudio null', () {
      final snap = learnPublishedSnapshotFromContent(<String, Object?>{
        'learn': {
          'schemaVersion': 1,
          'audio': {'storyAudio': null},
        },
      });
      expect(snap!.storyAudio, isNull);
    });

    test('learnPublishedSnapshotFromPublishedMonoDetail delegates', () {
      const dto = PublishedMonoDetailDto(
        id: 'm',
        ownerId: 'o',
        sourceDraftId: 'd',
        title: 't',
        category: 'c',
        level: 'l',
        description: 'd',
        publishKind: 'full_learn_v1',
        displayPublishKind: 'full_learn',
        coverImageUrl: null,
        targetDurationLabel: null,
        createdAt: 'a',
        updatedAt: 'b',
        contentSummary: null,
        content: <String, Object?>{
          'learn': {
            'schemaVersion': 1,
            'quiz': {
              'entries': [
                {
                  'id': 'q',
                  'category': 'grammar',
                  'prompt': 'p',
                  'options': <String>['1', '2', '3', '4'],
                  'correctIndex': 2,
                },
              ],
            },
          },
        },
      );
      final s = learnPublishedSnapshotFromPublishedMonoDetail(dto);
      expect(s?.quizEntries, hasLength(1));
      expect(s?.quizEntries.single.correctIndex, 2);
    });
  });
}
