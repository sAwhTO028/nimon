import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/auth/current_user_id_provider.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';
import 'package:nimon/features/create/data/story_draft_repository_provider.dart';
import 'package:nimon/features/create/story_creator_draft_storage.dart';
import 'package:nimon/features/create/story_creator_grammar_editor_screen.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/features/create/story_creator_vocab_kanji_editor_screen.dart';
import 'package:nimon/features/create/story_v1_model.dart';
import 'package:nimon/ui/widgets/nimon_scrollable_help_bottom_sheet.dart';

class _NoPersistRepo implements StoryDraftRepository {
  @override
  Future<PageResult<DraftListSummaryDto>> fetchWorkspaceDraftPage(
    PageRequest request,
  ) async =>
      PageResult.empty();

  @override
  Future<void> clearActiveDraft() async {}

  @override
  Future<void> clearResumeMeta(String draftId) async {}

  @override
  Future<CreatorStoryV1> createNewDraft({String? ownerId}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteDraft(String draftId) async {}

  @override
  Future<bool> discardPublishedEditStaging(String draftId) async => false;

  @override
  Future<void> ensureResumeMetaInitialized(String draftId) async {}

  @override
  Future<CreatorStoryV1> flushDraftToProcessing(
    CreatorStoryV1 draft, {
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    DateTime? touchEditedAtUtc,
  }) async =>
      draft;

  @override
  Future<bool> hasAnyIndexedDraft() async => false;

  @override
  Future<bool> hasDraft(String draftId) async => false;

  @override
  Future<List<CreatorStoryV1>> loadAllDrafts() async => const [];

  @override
  Future<CreatorStoryV1?> loadDraft(String draftId) async => null;

  @override
  Future<CreatorDraftResumeMeta?> loadResumeMeta(String draftId) async => null;

  @override
  Future<List<String>> listDraftIds() async => const [];

  @override
  Future<void> recordResumeNavigation({
    required String draftId,
    required CreatorLastActiveModule module,
    String? subPage,
  }) async {}

  @override
  Future<CreatorStoryV1> saveDraft(
    CreatorStoryV1 draft, {
    StoryDraftRemotePublishIntent remotePublishAfterPut =
        StoryDraftRemotePublishIntent.none,
  }) async =>
      draft;

  @override
  Future<CreatorStoryV1> saveDraftNow(CreatorStoryV1 draft) async => draft;

  @override
  Future<void> saveResumeMeta(CreatorDraftResumeMeta meta) async {}

  @override
  Future<DateTime?> savedAt(String draftId) async => null;

  @override
  Future<DateTime?> savedAtActiveDraft() async => null;

  @override
  Future<void> updateResumeMeta(
    String draftId, {
    CreatorLastActiveModule? lastActiveModule,
    String? lastActiveSubPage,
    DateTime? touchEditedAtUtc,
  }) async {}
}

class _SeededStoryCreatorDraftNotifier extends StoryCreatorDraftNotifier {
  _SeededStoryCreatorDraftNotifier(CreatorStoryV1 seed)
      : super(
          _NoPersistRepo(),
          seed.basics.creatorOwnerId.trim().isEmpty
              ? 'm14c_owner'
              : seed.basics.creatorOwnerId,
          onProfileCatalogSurfacesChanged: () {},
        ) {
    state = state.copyWith(draft: seed);
  }
}

ThemeData _darkTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: Brightness.dark,
      ),
    );

List<Override> _overrides(CreatorStoryV1 draft) => [
      storyDraftRepositoryProvider.overrideWithValue(_NoPersistRepo()),
      currentUserIdProvider.overrideWithValue('m14c_owner'),
      storyCreatorDraftProvider.overrideWith(
        (ref) => _SeededStoryCreatorDraftNotifier(draft),
      ),
    ];

void main() {
  testWidgets('Vocabulary module: card + details sheet readable in dark mode',
      (tester) async {
    final base = CreatorStoryV1.empty(creatorOwnerId: 'm14c_owner');
    final draft = base.copyWith(
      vocabularyKanji: VocabularyKanjiLayer(
        entries: [
          VocabularyKanjiEntry(
            id: 'v1',
            termJapanese: '猫',
            reading: 'ねこ',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(draft),
        child: MaterialApp(
          theme: _darkTheme(),
          home: Scaffold(
            body: SizedBox(
              height: 720,
              width: 360,
              child: StoryCreatorVocabKanjiModuleBody(
                padding: const EdgeInsets.all(12),
                showBottomActions: false,
                showLearnExitButton: false,
                useCompactModuleHeader: true,
                hideWorkspaceModuleTitle: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('猫'), findsWidgets);
    expect(find.text('No meanings yet'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);

    final term = tester.widget<Text>(find.text('猫').first);
    expect(term.style?.color, isNot(equals(const Color(0xFF000000))));

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(find.text('Entry details'), findsOneWidget);
    expect(find.text('Meanings'), findsOneWidget);
    expect(find.text('Add example'), findsWidgets);
    expect(find.text('Save'), findsWidgets);
    expect(find.text('Cancel'), findsWidgets);

    var exc = tester.takeException();
    if (exc != null) {
      expect(exc.toString(), isNot(contains('overflowed')));
    }

    Navigator.of(
      tester.element(find.text('Entry details')),
      rootNavigator: true,
    ).pop();
    await tester.pumpAndSettle();
    exc = tester.takeException();
    if (exc != null) {
      expect(exc.toString(), isNot(contains('overflowed')));
    }
  });

  testWidgets('Grammar module: card + Add pattern sheet in dark mode',
      (tester) async {
    final base = CreatorStoryV1.empty(creatorOwnerId: 'm14c_owner');
    final draft = base.copyWith(
      grammar: GrammarLayer(
        entries: [
          GrammarEntry(id: 'g1', headline: 'について'),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(draft),
        child: MaterialApp(
          theme: _darkTheme(),
          home: Scaffold(
            body: SizedBox(
              height: 720,
              width: 360,
              child: StoryCreatorGrammarModuleBody(
                padding: const EdgeInsets.all(12),
                showBottomActions: false,
                showLearnExitButton: false,
                useCompactModuleHeader: true,
                hideWorkspaceModuleTitle: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('について'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);

    await tester.tap(find.text('Add pattern'));
    await tester.pumpAndSettle();

    expect(find.text('Add pattern'), findsWidgets);
    expect(find.text('Pattern title'), findsOneWidget);

    final materialSheets = tester.widgetList<Material>(find.byType(Material));
    expect(
      materialSheets.map((m) => m.color).whereType<Color>().any((c) => c.a > 0),
      isTrue,
    );

    var exc = tester.takeException();
    if (exc != null) {
      expect(exc.toString(), isNot(contains('overflowed')));
    }

    Navigator.of(
      tester.element(find.text('Pattern title')),
      rootNavigator: true,
    ).pop();
    await tester.pumpAndSettle();
    exc = tester.takeException();
    if (exc != null) {
      expect(exc.toString(), isNot(contains('overflowed')));
    }
  });

  testWidgets('Quiz-style scrollable help uses shared shell (small phone)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: _darkTheme(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showNimonScrollableHelpBottomSheet(
                      context: context,
                      title: 'How to create quiz items',
                      body: List.filled(24, 'Line.').join('\n'),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('How to create quiz items'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);

    final exc = tester.takeException();
    if (exc != null) {
      expect(exc.toString(), isNot(contains('overflowed')));
    }
  });
}
