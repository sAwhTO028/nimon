import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/learn/grammar_pattern_detail_screen.dart';
import 'package:nimon/features/learn/grammar_pattern_list_screen.dart';
import 'package:nimon/features/learn/vocab_kanji_list_screen.dart';
import 'package:nimon/features/mono/data/mono_feed_providers.dart';
import 'package:nimon/features/mono/data/mono_feed_repository.dart';
import 'package:nimon/features/mono/data/mono_feed_summary_dto.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';

class _FakeMonoRepo implements MonoFeedRepository {
  _FakeMonoRepo(this._detail);

  final PublishedMonoDetailDto _detail;

  @override
  Future<PageResult<MonoFeedSummaryDto>> fetchFeedPage(
    PageRequest request, {
    String? level,
    String? category,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PublishedMonoDetailDto> fetchMonoDetail(String monoId) async =>
      _detail;
}

const _catalogMonoId = '550e8400-e29b-41d4-a716-446655440000';

PublishedMonoDetailDto _detailReadOnlyNoLearn() {
  return PublishedMonoDetailDto(
    id: _catalogMonoId,
    ownerId: 'o1',
    sourceDraftId: 'd1',
    title: 'Story',
    category: 'c',
    level: 'n5',
    description: 'd',
    publishKind: 'read_only_v1',
    displayPublishKind: 'read_only',
    coverImageUrl: null,
    targetDurationLabel: null,
    createdAt: 'a',
    updatedAt: 'b',
    contentSummary: null,
    content: <String, Object?>{
      'core': {'sentences': <Object?>[]},
    },
  );
}

PublishedMonoDetailDto _detailFullLearnOneVocab() {
  return PublishedMonoDetailDto(
    id: _catalogMonoId,
    ownerId: 'o1',
    sourceDraftId: 'd1',
    title: 'Story',
    category: 'c',
    level: 'n5',
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
        'vocabularyKanji': {
          'entries': [
            {
              'id': 'v1',
              'termJapanese': '猫',
              'type': 'vocabulary',
              'reading': 'ねこ',
              'glosses': {'my': 'ကြောင်', 'en': 'cat'},
            },
          ],
        },
        'grammar': {'entries': <Object?>[]},
        'quiz': {'entries': <Object?>[]},
        'audio': {'storyAudio': null},
      },
    },
  );
}

PublishedMonoDetailDto _detailFullLearnOneGrammar() {
  return PublishedMonoDetailDto(
    id: _catalogMonoId,
    ownerId: 'o1',
    sourceDraftId: 'd1',
    title: 'Story',
    category: 'c',
    level: 'n5',
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
        'vocabularyKanji': {'entries': <Object?>[]},
        'grammar': {
          'entries': [
            {
              'id': 'g1',
              'headline': 'について',
              'form': 'N + について',
              'meanings': {'my': 'အကြောင်း', 'en': 'about'},
            },
          ],
        },
        'quiz': {'entries': <Object?>[]},
        'audio': {'storyAudio': null},
      },
    },
  );
}

void main() {
  testWidgets('Vocab list shows empty message when read-only / no learn',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteMonoFeedRepositoryProvider.overrideWithValue(
            _FakeMonoRepo(_detailReadOnlyNoLearn()),
          ),
        ],
        child: const MaterialApp(
          home: VocabKanjiListScreen(contentId: _catalogMonoId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Published vocabulary'), findsOneWidget);
  });

  testWidgets(
      'Vocab list shows published term when full learn snapshot present',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteMonoFeedRepositoryProvider.overrideWithValue(
            _FakeMonoRepo(_detailFullLearnOneVocab()),
          ),
        ],
        child: const MaterialApp(
          home: VocabKanjiListScreen(contentId: _catalogMonoId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('猫'), findsOneWidget);
  });

  testWidgets('Grammar list shows pattern headline from snapshot',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteMonoFeedRepositoryProvider.overrideWithValue(
            _FakeMonoRepo(_detailFullLearnOneGrammar()),
          ),
        ],
        child: const MaterialApp(
          home: GrammarPatternListScreen(contentId: _catalogMonoId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('について'), findsOneWidget);
  });

  testWidgets(
      'Grammar detail shows catalog missing message without pattern extra',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GrammarPatternDetailScreen(
            contentId: _catalogMonoId,
            pattern: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No grammar pattern was opened'),
      findsOneWidget,
    );
  });
}
