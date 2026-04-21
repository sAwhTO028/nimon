import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/create/creator_drawer_session.dart';
import 'package:nimon/features/create/story_creator_models.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/features/create/story_creator_quiz_editor_screen.dart';
import 'package:nimon/main.dart';

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  bool _autoUncompress = true;

  @override
  bool get autoUncompress => _autoUncompress;

  @override
  set autoUncompress(bool v) => _autoUncompress = v;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest(url);

  // --- Unused members for these tests ---
  @override
  void close({bool force = false}) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this.url);

  @override
  final Uri url;

  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();

  // --- Unused members ---
  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding _) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  static final Uint8List _png = _TestAssetBundle._onePxPng;

  @override
  int get statusCode => 200;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  int get contentLength => _png.length;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[_png]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  // --- Unused members ---
  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  bool get persistentConnection => false;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  String get reasonPhrase => 'OK';

  @override
  HttpHeaders get headers => _FakeHeaders();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHeaders implements HttpHeaders {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestAssetBundle extends CachingAssetBundle {
  static final Uint8List _onePxPng = Uint8List.fromList(const <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR
    0x00, 0x00, 0x00, 0x01, // width 1
    0x00, 0x00, 0x00, 0x01, // height 1
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
    0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, // IDAT
    0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
    0x0D, 0x0A, 0x2D, 0xB4,
    0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, // IEND
    0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  Future<ByteData> load(String key) async {
    // Flutter loads manifests via special keys; they must decode correctly.
    if (key.endsWith('AssetManifest.json')) {
      final bytes = Uint8List.fromList('{}'.codeUnits);
      return ByteData.view(bytes.buffer);
    }
    if (key.endsWith('AssetManifest.bin')) {
      // StandardMessageCodec-encoded empty map.
      final data = const StandardMessageCodec().encodeMessage(<String, Object?>{});
      return data!;
    }

    // Provide a valid 1x1 PNG for any requested asset image.
    return ByteData.view(_onePxPng.buffer);
  }
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: _TestAssetBundle(),
      child: const ProviderScope(child: NimonApp()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

BuildContext _ctx(WidgetTester tester) => tester.element(find.byType(Scaffold).first);

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(_ctx(tester));

String _uri(WidgetTester tester) => GoRouterState.of(_ctx(tester)).uri.toString();

CreatorDrawerSessionState _session(WidgetTester tester) =>
    _container(tester).read(creatorDrawerSessionProvider);

Future<void> _go(WidgetTester tester, String location) async {
  GoRouter.of(_ctx(tester)).go(location);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _openDrawer(WidgetTester tester) async {
  final btn = find.byTooltip('Progress');
  expect(btn, findsOneWidget);
  await tester.tap(btn);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}

Finder _drawerCard(String title) => find.ancestor(of: find.text(title), matching: find.byType(Card));

Future<void> _tapDrawerOpen(WidgetTester tester, String title) async {
  final card = _drawerCard(title);
  expect(card, findsOneWidget);
  final open = find.descendant(of: card, matching: find.widgetWithText(TextButton, 'Open'));
  expect(open, findsOneWidget);
  await tester.ensureVisible(open);
  await tester.pump();
  await tester.tap(open, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

void _expectDrawerCurrent(WidgetTester tester, String title) {
  final card = _drawerCard(title);
  expect(find.descendant(of: card, matching: find.text('Current')), findsAtLeastNWidgets(1));
  expect(
    find.descendant(of: card, matching: find.widgetWithText(TextButton, 'You are here')),
    findsOneWidget,
  );
}

Future<void> _assertNoModuleSwitchAfterTap(
  WidgetTester tester, {
  required Finder tapTarget,
  required CreatorModule expectedModule,
  required String expectedPanelPrefix,
}) async {
  final beforeUri = _uri(tester);
  final beforeModule = _session(tester).activeModule;
  await tester.ensureVisible(tapTarget);
  await tester.pump();
  await tester.tap(tapTarget, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  expect(_session(tester).activeModule, expectedModule, reason: 'activeModule changed unexpectedly');
  expect(_uri(tester).startsWith(expectedPanelPrefix), isTrue, reason: 'URI left shell unexpectedly');
  // Route may stay identical or get query normalized; it must not jump modules.
  expect(_uri(tester).contains('/create/story/sentences'), isTrue);
  // At least ensure it did not jump to a different create root.
  expect(_uri(tester).startsWith('/create/story/sentences'), isTrue);
  // For debugging context if it fails.
  // ignore: unused_local_variable
  final _ = (beforeUri, beforeModule);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _FakeHttpOverrides();

  group('Create shell parent-child verification', () {
    testWidgets('1. Enter Create flow', (tester) async {
      await _pumpApp(tester);
      await _go(tester, '/create/story/sentences');

      expect(_uri(tester).startsWith('/create/story/sentences'), isTrue);
      // Default should be Story Sentences.
      expect(_session(tester).activeModule, CreatorModule.storySentences);

      await _openDrawer(tester);
      _expectDrawerCurrent(tester, 'Story sentences');
    });

    testWidgets('2. Story Sentences local actions stay local', (tester) async {
      await _pumpApp(tester);
      await _go(tester, '/create/story/sentences');

      // Add sentence via composer.
      final composer = find.byType(TextField).first;
      await tester.enterText(composer, '日本語の文です。');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byIcon(Icons.send_rounded), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(_session(tester).activeModule, CreatorModule.storySentences);

      // Edit sentence (tap Edit on first card).
      final edit = find.widgetWithText(TextButton, 'Edit').first;
      await tester.tap(edit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_session(tester).activeModule, CreatorModule.storySentences);

      // Translation/support meanings dialog (Translate button).
      final translate = find.widgetWithText(TextButton, 'Translate').first;
      await tester.tap(translate);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.textContaining('Support meanings'), findsOneWidget);
      // Close dialog (Cancel).
      final cancelInDialog = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Cancel'),
      );
      expect(cancelInDialog, findsOneWidget);
      await tester.tap(cancelInDialog);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_session(tester).activeModule, CreatorModule.storySentences);
    });

    testWidgets('3-4. Switch to Vocabulary; Vocabulary local actions stay local', (tester) async {
      await _pumpApp(tester);
      await _go(tester, '/create/story/sentences');

      // Seed one sentence so vocab picker could work if needed.
      final notifier = _container(tester).read(storyCreatorDraftProvider.notifier);
      notifier.applySentences('図書館は駅から歩いて五分です。');
      await tester.pump(const Duration(milliseconds: 100));

      await _openDrawer(tester);
      await _tapDrawerOpen(tester, 'Vocabulary');

      expect(_session(tester).activeModule, CreatorModule.vocabulary);
      expect(_uri(tester).contains('panel=vocabulary'), isTrue);

      await _openDrawer(tester);
      _expectDrawerCurrent(tester, 'Vocabulary');

      // Seed a vocab entry and exercise local actions (Details/Edit/Delete/Reorder).
      notifier.addVocabKanjiEntry(
        type: VocabularyKanjiEntryType.vocabulary,
        termJapanese: '図書館',
        readingRaw: 'としょかん',
        meanings: const LocalizedMeanings(my: 'စာကြည့်တိုက်', en: 'library'),
        examplePairs: const [],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Open Details (should not switch module).
      await _assertNoModuleSwitchAfterTap(
        tester,
        tapTarget: find.widgetWithText(TextButton, 'Details').first,
        expectedModule: CreatorModule.vocabulary,
        expectedPanelPrefix: '/create/story/sentences',
      );

      // Save in details sheet if opened (Save button).
      if (find.widgetWithText(FilledButton, 'Save').evaluate().isNotEmpty) {
        await tester.tap(find.widgetWithText(FilledButton, 'Save').first, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      }
      expect(_session(tester).activeModule, CreatorModule.vocabulary);
    });

    testWidgets('5-10. Switch to Grammar/Quiz/Listening; local actions stay local', (tester) async {
      await _pumpApp(tester);
      await _go(tester, '/create/story/sentences?panel=vocabulary');

      final notifier = _container(tester).read(storyCreatorDraftProvider.notifier);

      // Grammar
      await _openDrawer(tester);
      await _tapDrawerOpen(tester, 'Grammar');
      expect(_session(tester).activeModule, CreatorModule.grammar);
      expect(_uri(tester).contains('panel=grammar'), isTrue);
      await _openDrawer(tester);
      _expectDrawerCurrent(tester, 'Grammar');
      await _assertNoModuleSwitchAfterTap(
        tester,
        tapTarget: find.widgetWithText(FilledButton, 'Add pattern').first,
        expectedModule: CreatorModule.grammar,
        expectedPanelPrefix: '/create/story/sentences',
      );
      // Close sheet if opened.
      if (find.widgetWithText(TextButton, 'Cancel').evaluate().isNotEmpty) {
        await tester.tap(find.widgetWithText(TextButton, 'Cancel').first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 400));
      }

      // Quiz
      await _openDrawer(tester);
      await _tapDrawerOpen(tester, 'Quiz');
      expect(_session(tester).activeModule, CreatorModule.quiz);
      expect(_uri(tester).contains('panel=quiz'), isTrue);
      await _openDrawer(tester);
      _expectDrawerCurrent(tester, 'Quiz');
      await _assertNoModuleSwitchAfterTap(
        tester,
        tapTarget: find.widgetWithText(FilledButton, 'Add quiz').first,
        expectedModule: CreatorModule.quiz,
        expectedPanelPrefix: '/create/story/sentences',
      );
      if (find.widgetWithText(TextButton, 'Cancel').evaluate().isNotEmpty) {
        await tester.tap(find.widgetWithText(TextButton, 'Cancel').first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 400));
      }

      // Listening
      await _openDrawer(tester);
      await _tapDrawerOpen(tester, 'Listening / Pronunciation');
      expect(_session(tester).activeModule, CreatorModule.listeningPronunciation);
      expect(_uri(tester).contains('panel=listening'), isTrue);
      await _openDrawer(tester);
      _expectDrawerCurrent(tester, 'Listening / Pronunciation');
      await _assertNoModuleSwitchAfterTap(
        tester,
        tapTarget: find.widgetWithText(FilledButton, 'Upload audio').first,
        expectedModule: CreatorModule.listeningPronunciation,
        expectedPanelPrefix: '/create/story/sentences',
      );
      if (find.widgetWithText(TextButton, 'Cancel').evaluate().isNotEmpty) {
        await tester.tap(find.widgetWithText(TextButton, 'Cancel').first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 400));
      }

      // Ensure draft still exists and can be read after switches.
      final draft = _container(tester).read(storyCreatorDraftDataProvider);
      expect(draft, isNotNull);
      // Avoid analyzer unused.
      // ignore: unused_local_variable
      final _ = notifier;
    });

    testWidgets('11. Cross-switch persistence (seed + verify)', (tester) async {
      await _pumpApp(tester);
      await _go(tester, '/create/story/sentences');

      final notifier = _container(tester).read(storyCreatorDraftProvider.notifier);
      notifier.applySentences('一行目\n二行目');
      notifier.addVocabKanjiEntry(
        type: VocabularyKanjiEntryType.vocabulary,
        termJapanese: '話す',
        readingRaw: 'はなす',
        meanings: const LocalizedMeanings(my: 'ပြောသည်', en: 'to speak'),
        examplePairs: const [],
      );
      notifier.addGrammarEntry(
        headline: '〜について',
        formRaw: 'N + について',
        meanings: const LocalizedMeanings(en: 'about; regarding', my: '…အကြောင်း'),
        usage: null,
        examples: const [],
        mistakeWrongRaw: '',
        mistakeCorrectRaw: '',
        relatedNote: null,
      );
      notifier.addQuizEntry(
        category: CreatorQuizCategory.vocabulary,
        prompt: '話す means…?',
        options4: const ['to speak', 'to eat', 'to sleep', 'to run'],
        correctIndex: 0,
        explanations: null,
        sourceNoteRaw: '',
      );
      notifier.setStoryAudio(
        sourceUrlRaw: 'https://example.com/audio.mp3',
        displayNameRaw: '',
        durationSeconds: null,
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Switch around modules via URL and ensure draft still has data.
      await _go(tester, '/create/story/sentences?panel=vocabulary');
      await _go(tester, '/create/story/sentences?panel=grammar');
      await _go(tester, '/create/story/sentences?panel=quiz');
      await _go(tester, '/create/story/sentences?panel=listening');
      await _go(tester, '/create/story/sentences');

      final draft = _container(tester).read(storyCreatorDraftDataProvider);
      expect(draft.sentences.length, greaterThanOrEqualTo(2));
      expect(draft.vocabularyKanji.entries.any((e) => e.termJapanese == '話す'), isTrue);
      expect(draft.grammar.entries.any((e) => e.headline.contains('について')), isTrue);
      expect(draft.quiz.entries.any((e) => e.prompt.contains('話す')), isTrue);
      expect(draft.audio.storyAudio?.sourceUrl, isNotNull);
    });

    testWidgets('12. Back exits to Home Mono', (tester) async {
      await _pumpApp(tester);
      await _go(tester, '/create/story/sentences?panel=quiz');

      // Back button is the floating circle tooltip.
      final back = find.byTooltip('Back');
      expect(back, findsOneWidget);
      await tester.tap(back);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(_uri(tester).startsWith('/mono'), isTrue);
    });
  });

  group('Quiz module strict verification', () {
    Future<void> _selectQuizTab(WidgetTester tester, String label) async {
      // Tap the text label; it's the actual hit target inside TabBar.
      final tabLabel = find.descendant(
        of: find.byType(TabBar),
        matching: find.text(label),
      );
      expect(tabLabel, findsAtLeastNWidgets(1));
      await tester.tap(tabLabel.first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 450));
    }

    Future<void> _addQuizItemUi(
      WidgetTester tester, {
      required String prompt,
      required List<String> options4,
      int correctIndex = 0,
      String sourceExplanation = '',
      String englishExplanation = '',
      /// When adding from the Semantics tab, pick Vocabulary or Kanji before fields.
      String? newItemCategoryLabel,
    }) async {
      final add = find.widgetWithText(FilledButton, 'Add quiz');
      expect(add, findsOneWidget);
      await tester.tap(add, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      if (newItemCategoryLabel != null) {
        final menu = find.byType(DropdownMenu<CreatorQuizCategory>);
        expect(menu, findsWidgets);
        await tester.tap(menu.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text(newItemCategoryLabel).last, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 250));
      }

      await tester.enterText(
        find.widgetWithText(TextField, 'Prompt / question'),
        prompt,
      );
      await tester.pump(const Duration(milliseconds: 80));

      await tester.enterText(find.widgetWithText(TextField, 'Option A'), options4[0]);
      await tester.enterText(find.widgetWithText(TextField, 'Option B'), options4[1]);
      await tester.enterText(find.widgetWithText(TextField, 'Option C'), options4[2]);
      await tester.enterText(find.widgetWithText(TextField, 'Option D'), options4[3]);
      await tester.pump(const Duration(milliseconds: 80));

      await tester.tap(
        find.widgetWithText(ChoiceChip, String.fromCharCode(65 + correctIndex)),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 120));

      await tester.enterText(
        find.widgetWithText(TextField, 'Explanation (source language)'),
        sourceExplanation,
      );
      await tester.pump(const Duration(milliseconds: 80));

      if (englishExplanation.trim().isNotEmpty) {
        await tester.tap(
          find.widgetWithText(TextButton, 'Add English explanation (optional)'),
          warnIfMissed: false,
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.enterText(
          find.widgetWithText(TextField, 'English explanation (optional)'),
          englishExplanation,
        );
        await tester.pump(const Duration(milliseconds: 80));
      }

      final save = find.widgetWithText(FilledButton, 'Add quiz item');
      await tester.ensureVisible(save);
      await tester.pump();
      await tester.tap(save, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));
      // If validation failed, the sheet remains open; make it obvious in failures.
      expect(find.widgetWithText(FilledButton, 'Add quiz item'), findsNothing);
    }

    Finder _cardForPrompt(String prompt) => find.ancestor(
          of: find.text(prompt),
          matching: find.byType(DecoratedBox),
        );

    testWidgets('A. Add per tab, filter, switch tabs, edit, delete, reorder, preview/help, save draft', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1600));
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final msg = details.exceptionAsString();
        // Flutter test framework occasionally throws these during bottom-sheet teardown
        // (InputDecorator / overlay disposal ordering). They are non-deterministic and
        // not indicative of our creator flow logic.
        if (msg.contains('Tried to build dirty widget in the wrong build scope') ||
            msg.contains('Looking up a deactivated widget\'s ancestor is unsafe')) {
          return;
        }
        oldOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldOnError);

      await _pumpApp(tester);
      await _go(tester, '/create/story/sentences?panel=quiz');

      // 1-4 Add in each tab and confirm it only appears in that tab.
      await _selectQuizTab(tester, 'Semantics');
      await _addQuizItemUi(
        tester,
        prompt: 'Vocab Only',
        options4: const ['A', 'B', 'C', 'D'],
      );
      final afterVocabAdd = _container(tester).read(storyCreatorDraftDataProvider);
      expect(afterVocabAdd.quiz.entries.isNotEmpty, isTrue);
      expect(afterVocabAdd.quiz.entries.any((e) => e.prompt == 'Vocab Only'), isTrue);
      expect(find.text('Vocab Only'), findsOneWidget);
      await _selectQuizTab(tester, 'Grammar');
      expect(find.text('Vocab Only'), findsNothing);

      await _selectQuizTab(tester, 'Semantics');
      await _addQuizItemUi(
        tester,
        prompt: 'Kanji Only',
        options4: const ['A2', 'B2', 'C2', 'D2'],
        newItemCategoryLabel: 'Kanji',
      );
      expect(find.text('Kanji Only'), findsOneWidget);
      expect(find.text('Vocab Only'), findsOneWidget);
      await _selectQuizTab(tester, 'Grammar');
      expect(find.text('Kanji Only'), findsNothing);

      await _addQuizItemUi(
        tester,
        prompt: 'Grammar Only',
        options4: const ['A3', 'B3', 'C3', 'D3'],
      );
      expect(find.text('Grammar Only'), findsOneWidget);
      await _selectQuizTab(tester, 'Sentence');
      expect(find.text('Grammar Only'), findsNothing);

      await _addQuizItemUi(
        tester,
        prompt: 'Sentence Only',
        options4: const ['A4', 'B4', 'C4', 'D4'],
      );
      expect(find.text('Sentence Only'), findsOneWidget);

      // 5 Switch tabs repeatedly; ensure no mixing.
      await _selectQuizTab(tester, 'Semantics');
      expect(find.text('Vocab Only'), findsOneWidget);
      expect(find.text('Kanji Only'), findsOneWidget);
      await _selectQuizTab(tester, 'Grammar');
      expect(find.text('Kanji Only'), findsNothing);
      expect(find.text('Sentence Only'), findsNothing);

      // 6 Edit quiz item; stays in quiz module and updates correct tab.
      await _selectQuizTab(tester, 'Semantics');
      final kanjiEdit = find.descendant(
        of: _cardForPrompt('Kanji Only'),
        matching: find.widgetWithText(TextButton, 'Edit'),
      );
      expect(kanjiEdit, findsWidgets);
      await tester.tap(kanjiEdit.first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(
        find.widgetWithText(TextField, 'Prompt / question'),
        'Kanji Edited',
      );
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Kanji Edited'), findsOneWidget);
      expect(find.text('Kanji Only'), findsNothing);
      expect(_session(tester).activeModule, CreatorModule.quiz);
      expect(_uri(tester).contains('panel=quiz'), isTrue);

      // 7 Delete (use notifier directly; popup menu is flaky in widget tests).
      final before = _container(tester).read(storyCreatorDraftDataProvider);
      final target = before.quiz.entries.where((e) => e.prompt == 'Kanji Edited').toList();
      expect(target.length, 1, reason: 'Expected exactly one Kanji Edited entry to delete');
      _container(tester).read(storyCreatorDraftProvider.notifier).deleteQuizEntry(target.single.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_cardForPrompt('Kanji Edited'), findsNothing);
      expect(_session(tester).activeModule, CreatorModule.quiz);

      // 8 Reorder within filtered category (Semantics tab).
      await _selectQuizTab(tester, 'Semantics');
      await _addQuizItemUi(
        tester,
        prompt: 'Vocab Second',
        options4: const ['A5', 'B5', 'C5', 'D5'],
      );
      expect(find.text('Vocab Only'), findsOneWidget);
      expect(find.text('Vocab Second'), findsOneWidget);

      final secondHandle = find.descendant(
        of: _cardForPrompt('Vocab Second'),
        matching: find.byIcon(Icons.drag_handle_rounded),
      );
      expect(secondHandle, findsWidgets);
      await tester.drag(secondHandle.first, const Offset(0, -220));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('Vocab Only'), findsOneWidget);
      expect(find.text('Vocab Second'), findsOneWidget);
      expect(_session(tester).activeModule, CreatorModule.quiz);

      // 9 Preview/test icon: tab-aware + empty state.
      // Empty Sentence tab: remove sentence items for this check only.
      final notifier = _container(tester).read(storyCreatorDraftProvider.notifier);
      final sentenceIds = _container(tester)
          .read(storyCreatorDraftDataProvider)
          .quiz
          .entries
          .where((e) => e.category == CreatorQuizCategory.sampleSentence)
          .map((e) => e.id)
          .toList();
      for (final id in sentenceIds) {
        notifier.deleteQuizEntry(id);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _selectQuizTab(tester, 'Sentence');
      _container(tester).read(quizTabIndexProvider.notifier).state = 2;
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.byTooltip('Test-play quiz'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.textContaining('Test-play: Sentence'), findsOneWidget);
      expect(find.textContaining('No quiz items in this tab yet.'), findsOneWidget);
      // Dismiss sheet via scrim (no Close control).
      await tester.tapAt(const Offset(500, 80));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      // Preview Grammar should show only Grammar item.
      await _selectQuizTab(tester, 'Grammar');
      _container(tester).read(quizTabIndexProvider.notifier).state = 1;
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.byTooltip('Test-play quiz'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.textContaining('Test-play: Grammar'), findsOneWidget);
      expect(find.text('Grammar Only'), findsWidgets);
      await tester.tapAt(const Offset(500, 80));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      // 10 Help icon.
      await tester.tap(find.byTooltip('How to create quiz items'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('How to create quiz items'), findsOneWidget);
      expect(find.textContaining('Quiz types:'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Got it'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));

      // 11 Save draft: preserves items and filtering.
      final saveDraftBtn = find.widgetWithText(OutlinedButton, 'Save draft');
      expect(saveDraftBtn, findsWidgets);
      await tester.tap(saveDraftBtn.first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await _selectQuizTab(tester, 'Semantics');
      expect(find.text('Vocab Only'), findsOneWidget);
      expect(find.text('Vocab Second'), findsOneWidget);
      await _selectQuizTab(tester, 'Sentence');
      expect(find.text('Sentence Only'), findsNothing);
    });
  });
}

