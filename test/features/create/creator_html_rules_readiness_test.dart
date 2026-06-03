import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/limits/html_generator_limits.dart';
import 'package:nimon/features/create/creator_completion_rules.dart';
import 'package:nimon/features/create/creator_readiness.dart';
import 'package:nimon/features/create/story_creator_models.dart';

CreatorStoryV1 _baseDraft({
  required String ownerId,
  required String level,
  required String targetDurationBandKey,
  required String promptSourceNote,
  required int sentenceCount,
  required int charsPerSentence,
  int vocabCount = 0,
  int grammarCount = 0,
  int quizVocabulary = 0,
  int quizGrammar = 0,
  int quizSentence = 0,
  int quizKanji = 0,
  bool withAudio = false,
}) {
  final t = 'あ' * charsPerSentence;
  final sentences = List.generate(
    sentenceCount,
    (i) => StorySentenceItem(
      id: 's$i',
      storyId: 'draft-1',
      orderIndex: i,
      japaneseText: t,
      meanings: const LocalizedMeanings(en: 'x', my: 'x'),
      furiganaSpans: const [],
      provenance: const ContentProvenance(sourceMode: ContentSourceMode.aiDraft),
    ),
  );

  final vocab = List.generate(
    vocabCount,
    (i) => VocabularyKanjiEntry(
      id: 'v$i',
      termJapanese: 'たんご$i',
      reading: 'たんご$i',
      glosses: const LocalizedMeanings(en: 'x', my: 'x'),
      examplePairs: const [
        VocabularyExamplePair(sourceExample: 'れいぶん', englishExample: 'x'),
      ],
      exampleSentence: 'れいぶん',
      exampleMeanings: const LocalizedMeanings(en: 'x', my: 'x'),
      provenance: const ContentProvenance(sourceMode: ContentSourceMode.aiDraft),
    ),
  );

  final grammar = List.generate(
    grammarCount,
    (i) => GrammarEntry(
      id: 'g$i',
      headline: 'ぶんぽう$i',
      form: 'form$i',
      meanings: const LocalizedMeanings(en: 'x', my: 'x'),
      usage: const LocalizedMeanings(en: 'x', my: 'x'),
      examples: const [
        GrammarExample(japanese: 'れいぶん', meanings: LocalizedMeanings(en: 'x', my: 'x')),
      ],
      relatedNote: const LocalizedMeanings(en: 'x', my: 'x'),
      mistakeWrong: 'wrong$i',
      mistakeCorrect: 'correct$i',
      provenance: const ContentProvenance(sourceMode: ContentSourceMode.aiDraft),
    ),
  );

  QuizEntry q(String id, CreatorQuizCategory cat) => QuizEntry(
        id: id,
        category: cat,
        prompt: 'Q$id',
        options: const ['A', 'B', 'C', 'D'],
        correctIndex: 0,
        sourceNote: 'subtype=mcq;answer=A;target=T',
        provenance: const ContentProvenance(sourceMode: ContentSourceMode.aiDraft),
      );

  final quiz = <QuizEntry>[
    for (var i = 0; i < quizVocabulary; i++) q('qv$i', CreatorQuizCategory.vocabulary),
    for (var i = 0; i < quizGrammar; i++) q('qg$i', CreatorQuizCategory.grammar),
    for (var i = 0; i < quizSentence; i++) q('qs$i', CreatorQuizCategory.sampleSentence),
    for (var i = 0; i < quizKanji; i++) q('qk$i', CreatorQuizCategory.kanji),
  ];

  final audio = withAudio
      ? AudioLayer(
          storyAudio: StoryAudioAsset(
            id: 'a1',
            sourceUrl: 'https://example.com/a.mp3',
            provenance: const ContentProvenance(sourceMode: ContentSourceMode.aiDraft),
          ),
        )
      : const AudioLayer();

  return CreatorStoryV1(
    basics: StoryBasics(
      storyId: 'draft-1',
      title: 't',
      category: 'Daily Life',
      level: level,
      description: 'd',
      promptSourceNote: promptSourceNote,
      targetDurationBandKey: targetDurationBandKey,
      coverImageUrl: null,
      creatorOwnerId: ownerId,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
    sentences: sentences,
    vocabularyKanji: VocabularyKanjiLayer(entries: vocab),
    grammar: GrammarLayer(entries: grammar),
    quiz: QuizLayer(entries: quiz),
    audio: audio,
    publishState: StoryPublishState.draft,
    moduleWorkflowStatuses: {
      LearnModuleId.vocabularyKanji: LearnModuleTaskStatus.notStarted,
      LearnModuleId.grammar: LearnModuleTaskStatus.notStarted,
      LearnModuleId.quiz: LearnModuleTaskStatus.notStarted,
      LearnModuleId.audio: LearnModuleTaskStatus.notStarted,
    },
  );
}

void main() {
  const ownerId = 'test-owner';

  group('creator readiness uses HTML generator rules', () {
    test('A. ReadOnly AI JP N4 5_7 valid story is ready', () {
      final d = _baseDraft(
        ownerId: ownerId,
        level: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentenceCount: 42,
        charsPerSentence: 18, // 756 chars (min 750)
      );

      final ro = computeReadOnlyReady(d);
      expect(ro.ready, isTrue, reason: ro.unmetMessages.join(' | '));
    });

    test('B. ReadOnly too few sentences is not ready', () {
      final d = _baseDraft(
        ownerId: ownerId,
        level: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentenceCount: 41,
        charsPerSentence: 18,
      );
      final ro = computeReadOnlyReady(d);
      expect(ro.ready, isFalse);
      expect(ro.unmetMessages.join(' | '), contains('Need at least 42 sentences'));
    });

    test('C. ReadOnly too few chars is not ready', () {
      final d = _baseDraft(
        ownerId: ownerId,
        level: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentenceCount: 42,
        charsPerSentence: 17, // 714 chars (min 750)
      );
      final ro = computeReadOnlyReady(d);
      expect(ro.ready, isFalse);
      expect(ro.unmetMessages.join(' | '), contains('Need at least 750 Japanese chars'));
    });

    test('D. FullLearn AI valid counts but no audio => not ready', () {
      final d = _baseDraft(
        ownerId: ownerId,
        level: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentenceCount: 42,
        charsPerSentence: 18,
        vocabCount: 16,
        grammarCount: 6,
        quizVocabulary: 11,
        quizGrammar: 5,
        quizSentence: 4,
        quizKanji: 1, // total 21
        withAudio: false,
      );
      final ro = computeReadOnlyReady(d);
      expect(ro.ready, isTrue);
      final fl = computeFullLearnReady(d);
      expect(fl.ready, isFalse);
      expect(fl.unmetMessages.join(' | '), contains('Need audio for Full Learn'));
    });

    test('E. FullLearn AI valid counts + audio => ready', () {
      final d = _baseDraft(
        ownerId: ownerId,
        level: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentenceCount: 42,
        charsPerSentence: 18,
        vocabCount: 16,
        grammarCount: 6,
        quizVocabulary: 11,
        quizGrammar: 5,
        quizSentence: 4,
        quizKanji: 1,
        withAudio: true,
      );
      final fl = computeFullLearnReady(d);
      expect(fl.ready, isTrue, reason: fl.unmetMessages.join(' | '));
    });

    test('F. FullLearn AI vocab mismatch => not ready', () {
      final d = _baseDraft(
        ownerId: ownerId,
        level: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentenceCount: 42,
        charsPerSentence: 18,
        vocabCount: 15,
        grammarCount: 6,
        quizVocabulary: 11,
        quizGrammar: 5,
        quizSentence: 4,
        quizKanji: 1,
        withAudio: true,
      );
      final fl = computeFullLearnReady(d);
      expect(fl.ready, isFalse);
      expect(fl.unmetMessages.join(' | '), contains('Need exactly 16 vocab items'));
    });

    test('G. FullLearn AI quiz distribution mismatch => not ready', () {
      final d = _baseDraft(
        ownerId: ownerId,
        level: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentenceCount: 42,
        charsPerSentence: 18,
        vocabCount: 16,
        grammarCount: 6,
        quizVocabulary: 10, // wrong
        quizGrammar: 5,
        quizSentence: 4,
        quizKanji: 2, // keep total 21
        withAudio: true,
      );
      final fl = computeFullLearnReady(d);
      expect(fl.ready, isFalse);
      expect(fl.unmetMessages.join(' | '), contains('Need quiz distribution'));
    });

    test('H. Manual mode uses manual ranges (JP N4 5_7 vocab 12–24)', () {
      final pass = _baseDraft(
        ownerId: ownerId,
        level: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=Manual_mode',
        sentenceCount: 32, // manual min for this combo
        charsPerSentence: 18,
        vocabCount: 12,
        grammarCount: 4,
        quizVocabulary: 8,
        quizGrammar: 3,
        quizSentence: 3,
        quizKanji: 0,
        withAudio: true,
      );
      expect(computeFullLearnReady(pass).ready, isTrue);

      final low = pass.copyWith(
        vocabularyKanji: VocabularyKanjiLayer(entries: pass.vocabularyKanji.entries.take(11).toList()),
      );
      expect(computeFullLearnReady(low).ready, isFalse);

      final high = _baseDraft(
        ownerId: ownerId,
        level: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=Manual_mode',
        sentenceCount: 32,
        charsPerSentence: 18,
        vocabCount: 25,
        grammarCount: 4,
        quizVocabulary: 8,
        quizGrammar: 3,
        quizSentence: 3,
        quizKanji: 0,
        withAudio: true,
      );
      expect(computeFullLearnReady(high).ready, isFalse);
    });

    test('I. Missing level/duration => not ready (no crash)', () {
      final d = _baseDraft(
        ownerId: ownerId,
        level: '',
        targetDurationBandKey: '',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentenceCount: 42,
        charsPerSentence: 18,
      );
      final ro = computeReadOnlyReady(d);
      expect(ro.ready, isFalse);
      expect(ro.unmetMessages, isNotEmpty);
    });
  });

  group('prompt mode resolution', () {
    test('AI_mode in promptSourceNote => HtmlPromptMode.ai', () {
      final d = _baseDraft(
        ownerId: ownerId,
        level: 'N4',
        targetDurationBandKey: '5_7',
        promptSourceNote: 'promptDataTab=AI_mode',
        sentenceCount: 42,
        charsPerSentence: 18,
      );
      expect(resolveHtmlPromptModeForDraft(d), HtmlPromptMode.ai);
    });
  });
}

