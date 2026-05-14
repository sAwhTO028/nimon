import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';
import 'package:nimon/features/create/data/story_draft_repository_provider.dart';
import 'package:nimon/features/create/story_creator_add_tab_screen.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart';
import 'package:nimon/features/create/story_creator_models.dart';

/// Minimal test double: only [fetchWorkspaceDraftPage] is used by the Add tab.
class _EmptyDraftsRepo implements StoryDraftRepository {
  @override
  Future<PageResult<DraftListSummaryDto>> fetchWorkspaceDraftPage(
    PageRequest request,
  ) async =>
      PageResult.empty();

  @override
  Future<void> clearActiveDraft() => throw UnimplementedError();

  @override
  Future<void> clearResumeMeta(String draftId) => throw UnimplementedError();

  @override
  Future<CreatorStoryV1> createNewDraft({String? ownerId}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteDraft(String draftId) => throw UnimplementedError();

  @override
  Future<bool> discardPublishedEditStaging(String draftId) =>
      throw UnimplementedError();

  @override
  Future<void> ensureResumeMetaInitialized(String draftId) =>
      throw UnimplementedError();

  @override
  Future<CreatorStoryV1> flushDraftToProcessing(
    CreatorStoryV1 draft, {
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    DateTime? touchEditedAtUtc,
  }) =>
      throw UnimplementedError();

  @override
  Future<bool> hasAnyIndexedDraft() => throw UnimplementedError();

  @override
  Future<bool> hasDraft(String draftId) => throw UnimplementedError();

  @override
  Future<List<CreatorStoryV1>> loadAllDrafts() => throw UnimplementedError();

  @override
  Future<CreatorStoryV1?> loadDraft(String draftId) =>
      throw UnimplementedError();

  @override
  Future<CreatorDraftResumeMeta?> loadResumeMeta(String draftId) =>
      throw UnimplementedError();

  @override
  Future<List<String>> listDraftIds() => throw UnimplementedError();

  @override
  Future<void> recordResumeNavigation({
    required String draftId,
    required CreatorLastActiveModule module,
    String? subPage,
  }) =>
      throw UnimplementedError();

  @override
  Future<CreatorStoryV1> saveDraft(
    CreatorStoryV1 draft, {
    StoryDraftRemotePublishIntent remotePublishAfterPut =
        StoryDraftRemotePublishIntent.none,
  }) =>
      throw UnimplementedError();

  @override
  Future<CreatorStoryV1> saveDraftNow(CreatorStoryV1 draft) =>
      throw UnimplementedError();

  @override
  Future<void> saveResumeMeta(CreatorDraftResumeMeta meta) =>
      throw UnimplementedError();

  @override
  Future<DateTime?> savedAt(String draftId) => throw UnimplementedError();

  @override
  Future<DateTime?> savedAtActiveDraft() => throw UnimplementedError();

  @override
  Future<void> updateResumeMeta(
    String draftId, {
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    DateTime? touchEditedAtUtc,
  }) =>
      throw UnimplementedError();
}

void main() {
  testWidgets('Create Add tab: empty state readable in dark mode', (
    tester,
  ) async {
    final dark = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: Brightness.dark,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storyDraftRepositoryProvider.overrideWithValue(_EmptyDraftsRepo()),
        ],
        child: MaterialApp(
          theme: dark,
          home: const StoryCreatorAddTabScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Start your next story'), findsOneWidget);
    expect(find.text('Create new story'), findsOneWidget);

    final exc = tester.takeException();
    if (exc != null) {
      expect(exc.toString(), isNot(contains('overflowed')));
    }
  });
}
