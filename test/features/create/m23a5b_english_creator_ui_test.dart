import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/creator_learning_language.dart';
import 'package:nimon/features/create/data/story_draft_repository.dart';
import 'package:nimon/features/create/data/story_draft_repository_provider.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/features/create/story_creator_vocab_kanji_editor_screen.dart';
import 'package:nimon/features/create/story_v1_model.dart';

class _NoPersistRepo implements StoryDraftRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _SeededStoryCreatorDraftNotifier extends StoryCreatorDraftNotifier {
  _SeededStoryCreatorDraftNotifier(CreatorStoryV1 seed)
      : super(
          _NoPersistRepo(),
          seed.basics.creatorOwnerId.trim().isEmpty
              ? 'm23a5b_owner'
              : seed.basics.creatorOwnerId,
          defaultContentLocale: 'my',
          defaultLearningLanguage: 'ja',
          onProfileCatalogSurfacesChanged: () {},
        ) {
    state = state.copyWith(draft: seed);
  }
}

List<Override> _overrides(CreatorStoryV1 draft) => [
      storyDraftRepositoryProvider.overrideWithValue(_NoPersistRepo()),
      storyCreatorDraftProvider.overrideWith(
        (ref) => _SeededStoryCreatorDraftNotifier(draft),
      ),
    ];

CreatorStoryV1 _draftWithSentence({
  required String learningLanguage,
}) {
  final base = CreatorStoryV1.empty(
    creatorOwnerId: 'm23a5b_owner',
    learningLanguage: learningLanguage,
  );
  return base.copyWith(
    sentences: [
      StorySentenceItem(
        id: 's1',
        storyId: base.basics.storyId,
        orderIndex: 0,
        japaneseText: '猫は好きです。',
        furiganaSpans: [
          FuriganaSpan(start: 0, end: 1, reading: 'ねこ'),
        ],
      ),
    ],
  );
}

void main() {
  group('LearnModuleIdLabels', () {
    test('JA shows Vocabulary / Kanji', () {
      expect(
        LearnModuleId.vocabularyKanji.displayTitleForLearning('ja'),
        'Vocabulary / Kanji',
      );
    });

    test('EN shows Vocabulary only', () {
      expect(
        LearnModuleId.vocabularyKanji.displayTitleForLearning('en'),
        'Vocabulary',
      );
    });
  });

  group('sentence editor furigana affordance', () {
    test('JA learning enables furigana manage gate', () {
      final draft = _draftWithSentence(learningLanguage: 'ja');
      expect(isJapaneseLearningDraft(draft), isTrue);
    });

    test('EN learning disables furigana manage gate', () {
      final draft = _draftWithSentence(learningLanguage: 'en');
      expect(isJapaneseLearningDraft(draft), isFalse);
    });
  });

  group('vocabulary editor', () {
    testWidgets('JA module header shows Vocabulary / Kanji', (tester) async {
      final draft = _draftWithSentence(learningLanguage: 'ja');
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(draft),
          child: MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: StoryCreatorVocabKanjiModuleBody(
                padding: const EdgeInsets.all(12),
                showBottomActions: false,
                useCompactModuleHeader: true,
                hideWorkspaceModuleTitle: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vocabulary / Kanji'), findsOneWidget);
    });

    testWidgets('EN module header shows Vocabulary only', (tester) async {
      final draft = _draftWithSentence(learningLanguage: 'en');
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(draft),
          child: MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: StoryCreatorVocabKanjiModuleBody(
                padding: const EdgeInsets.all(12),
                showBottomActions: false,
                useCompactModuleHeader: true,
                hideWorkspaceModuleTitle: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vocabulary / Kanji'), findsNothing);
      expect(find.text('Vocabulary'), findsWidgets);
    });

    testWidgets('EN edit sheet hides Kanji type and reading fields',
        (tester) async {
      final base = CreatorStoryV1.empty(creatorOwnerId: 'm23a5b_owner');
      final draft = base.copyWith(
        basics: base.basics.copyWith(learningLanguage: 'en'),
        vocabularyKanji: VocabularyKanjiLayer(
          entries: [
            VocabularyKanjiEntry(
              id: 'v1',
              termJapanese: 'library',
              type: VocabularyKanjiEntryType.kanji,
              reading: 'legacy',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(draft),
          child: MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: StoryCreatorVocabKanjiModuleBody(
                padding: const EdgeInsets.all(12),
                showBottomActions: false,
                useCompactModuleHeader: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit').first);
      await tester.pumpAndSettle();

      expect(find.text('Kanji'), findsNothing);
      expect(find.text('Reading / furigana (optional)'), findsNothing);
    });

    testWidgets('JA edit sheet still shows Kanji type control', (tester) async {
      final base = CreatorStoryV1.empty(creatorOwnerId: 'm23a5b_owner');
      final draft = base.copyWith(
        basics: base.basics.copyWith(learningLanguage: 'ja'),
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
            theme: ThemeData.light(),
            home: Scaffold(
              body: StoryCreatorVocabKanjiModuleBody(
                padding: const EdgeInsets.all(12),
                showBottomActions: false,
                useCompactModuleHeader: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit').first);
      await tester.pumpAndSettle();

      expect(find.text('Kanji'), findsOneWidget);
      expect(find.text('Reading / furigana (optional)'), findsOneWidget);
    });
  });

  test('draft helpers match wire codes', () {
    final en = _draftWithSentence(learningLanguage: 'en');
    final ja = _draftWithSentence(learningLanguage: 'ja');
    expect(isEnglishLearningDraft(en), isTrue);
    expect(isJapaneseLearningDraft(en), isFalse);
    expect(isEnglishLearningDraft(ja), isFalse);
    expect(isJapaneseLearningDraft(ja), isTrue);
  });
}
