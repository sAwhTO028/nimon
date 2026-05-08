import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/learn/quiz_play_screen.dart';
import 'package:nimon/features/learn/quiz_session.dart';
import 'package:nimon/features/learn/quiz_setup_screen.dart';
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

PublishedMonoDetailDto _detailFullLearnWithQuiz() {
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
        'grammar': {'entries': <Object?>[]},
        'quiz': {
          'entries': [
            {
              'id': 'q1',
              'category': 'vocabulary',
              'prompt': 'PublishedQuizPromptX',
              'options': ['o1', 'o2', 'o3', 'o4'],
              'correctIndex': 0,
            },
          ],
        },
        'audio': {'storyAudio': null},
      },
    },
  );
}

PublishedMonoDetailDto _detailFullLearnNoQuiz() {
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

void main() {
  testWidgets('Quiz setup read-only shows unavailable message', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteMonoFeedRepositoryProvider.overrideWithValue(
            _FakeMonoRepo(_detailReadOnlyNoLearn()),
          ),
        ],
        child: const MaterialApp(
          home: QuizSetupScreen(contentId: _catalogMonoId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('read-only'), findsOneWidget);
    expect(find.text('Start Quiz'), findsNothing);
  });

  testWidgets('Quiz setup full learn + quiz shows interactive setup',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteMonoFeedRepositoryProvider.overrideWithValue(
            _FakeMonoRepo(_detailFullLearnWithQuiz()),
          ),
        ],
        child: const MaterialApp(
          home: QuizSetupScreen(contentId: _catalogMonoId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Choose one quiz type'), findsOneWidget);
    expect(find.text('Start Quiz'), findsOneWidget);
  });

  testWidgets('Quiz setup full learn but empty quiz list shows empty copy',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteMonoFeedRepositoryProvider.overrideWithValue(
            _FakeMonoRepo(_detailFullLearnNoQuiz()),
          ),
        ],
        child: const MaterialApp(
          home: QuizSetupScreen(contentId: _catalogMonoId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No quiz for this story yet'), findsOneWidget);
    expect(find.text('Start Quiz'), findsNothing);
  });

  testWidgets(
      'Quiz play catalog UUID without published pool does not show mock prompt',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: QuizPlayScreen(
            contentId: _catalogMonoId,
            args: QuizSessionStartArgs(
              contentId: _catalogMonoId,
              category: LearnQuizCategory.vocabulary,
              questionCount: 5,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('図書館'), findsNothing);
    expect(find.textContaining('No quiz questions available'), findsOneWidget);
  });
}
