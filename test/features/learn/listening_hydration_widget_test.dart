import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/learn/listening_pronunciation_screen.dart';
import 'package:nimon/features/learn/listening_transcript_models.dart';
import 'package:nimon/features/mono/data/mono_feed_providers.dart';
import 'package:nimon/features/mono/data/mono_feed_repository.dart';
import 'package:nimon/features/mono/data/mono_feed_summary_dto.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';
import 'package:nimon/ui/reading/nimon_ruby_text.dart';

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

PublishedMonoDetailDto _detailReadOnly() {
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

PublishedMonoDetailDto _detailFullLearnHttpsAudio() {
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
        'quiz': {'entries': <Object?>[]},
        'audio': {
          'storyAudio': {
            'id': 'a1',
            'sourceUrl': 'https://example.com/story-audio.mp3',
            'displayName': 'Published track title',
            'durationSeconds': 90,
          },
        },
      },
      'core': {
        'sentences': <Object?>[
          <String, Object?>{
            'content': <String, Object?>{
              'japaneseText': '今日はいい天気です。',
              'furiganaSpans': <Object?>[
                <String, Object>{'start': 5, 'end': 7, 'reading': 'てんき'},
              ],
            },
          },
        ],
      },
    },
  );
}

PublishedMonoDetailDto _detailFullLearnLocalOnlyAudio() {
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
        'quiz': {'entries': <Object?>[]},
        'audio': {
          'storyAudio': {
            'id': 'a1',
            'localPath': '/device/story.mp3',
            'localFileName': 'story.mp3',
          },
        },
      },
    },
  );
}

void main() {
  testWidgets('Listening read-only shows locked message', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteMonoFeedRepositoryProvider.overrideWithValue(
            _FakeMonoRepo(_detailReadOnly()),
          ),
        ],
        child: const MaterialApp(
          home: ListeningPronunciationScreen(contentId: _catalogMonoId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('read-only'), findsOneWidget);
    expect(
      find.textContaining('SoundHelix'),
      findsNothing,
    );
  });

  testWidgets(
      'Listening full learn HTTPS shows display name, not sample transcript',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteMonoFeedRepositoryProvider.overrideWithValue(
            _FakeMonoRepo(_detailFullLearnHttpsAudio()),
          ),
        ],
        child: const MaterialApp(
          home: ListeningPronunciationScreen(contentId: _catalogMonoId),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Published track title'), findsWidgets);
    expect(
      find.text(ListeningSampleData.mockLines.first.japanese),
      findsNothing,
    );
    expect(
      find.textContaining('SoundHelix'),
      findsNothing,
    );
    expect(
      find.textContaining('No transcript is published for this story yet'),
      findsNothing,
    );
    // NimonRubyText paints base text in a custom render object (not [Text]).
    expect(find.byType(NimonRubyText), findsOneWidget);
  });

  testWidgets('Listening full learn local-only audio shows unavailable body',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteMonoFeedRepositoryProvider.overrideWithValue(
            _FakeMonoRepo(_detailFullLearnLocalOnlyAudio()),
          ),
        ],
        child: const MaterialApp(
          home: ListeningPronunciationScreen(contentId: _catalogMonoId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Audio is not available for this story yet'),
      findsOneWidget,
    );
  });

  testWidgets('Listening demo mono id still shows sample transcript',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ListeningPronunciationScreen(contentId: 'mono'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text(ListeningSampleData.mockLines.first.japanese),
      findsOneWidget,
    );
  });
}
