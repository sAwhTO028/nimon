import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/limits/html_generator_limits.dart';
import 'package:nimon/core/validation/publish_validation.dart';
import 'package:nimon/core/validation/validation_mode.dart';
import 'package:nimon/core/validation/validation_result.dart';
import 'package:nimon/features/create/creator_completion_rules.dart';
import 'package:nimon/features/create/creator_prompt_source_note.dart';
import 'package:nimon/features/create/creator_publish_preflight.dart';
import 'package:nimon/features/create/creator_readiness.dart';
import 'package:nimon/features/create/story_creator_models.dart';

const _importAiNote = '''
[nimon-import]
promptDataTab=AI_mode
''';

const _manualNote = 'promptDataTab=Manual_mode';

CreatorStoryV1 _fullLearnDraft({
  required String promptSourceNote,
  int sentenceCount = 30,
  int charsPerSentence = 22,
  int vocabCount = 11,
  int grammarCount = 4,
  int quizVocabulary = 7,
  int quizGrammar = 3,
  int quizSentence = 3,
  bool withAudio = true,
}) {
  final t = 'あ' * charsPerSentence;
  final sentences = List.generate(
    sentenceCount,
    (i) => StorySentenceItem(
      id: 's$i',
      storyId: 'draft-fl',
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
        GrammarExample(
          japanese: 'れいぶん',
          meanings: LocalizedMeanings(en: 'x', my: 'x'),
        ),
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
        prompt: 'Question $id',
        options: const ['A', 'B', 'C', 'D'],
        correctIndex: 0,
        sourceNote: 'subtype=mcq;answer=A;target=T',
        provenance: const ContentProvenance(sourceMode: ContentSourceMode.aiDraft),
      );

  final quiz = <QuizEntry>[
    for (var i = 0; i < quizVocabulary; i++)
      q('qv$i', CreatorQuizCategory.vocabulary),
    for (var i = 0; i < quizGrammar; i++) q('qg$i', CreatorQuizCategory.grammar),
    for (var i = 0; i < quizSentence; i++)
      q('qs$i', CreatorQuizCategory.sampleSentence),
  ];

  final audio = withAudio
      ? AudioLayer(
          storyAudio: StoryAudioAsset(
            id: 'a1',
            sourceUrl: 'https://example.com/a.mp3',
            provenance:
                const ContentProvenance(sourceMode: ContentSourceMode.aiDraft),
          ),
        )
      : const AudioLayer();

  return CreatorStoryV1(
    basics: StoryBasics(
      storyId: 'draft-fl',
      title: 'Imported AI Full Learn',
      category: 'Daily Life',
      level: 'N4',
      description: 'desc',
      promptSourceNote: promptSourceNote,
      targetDurationBandKey: '3_5',
      coverImageUrl: null,
      creatorOwnerId: 'owner-1',
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
      LearnModuleId.vocabularyKanji: LearnModuleTaskStatus.completed,
      LearnModuleId.grammar: LearnModuleTaskStatus.completed,
      LearnModuleId.quiz: LearnModuleTaskStatus.completed,
      LearnModuleId.audio: LearnModuleTaskStatus.completed,
    },
  );
}

void main() {
  group('creator publish preflight prompt mode parity', () {
    test('A imported AI N4 3_5 FullLearn counts pass readiness and publish', () {
      final draft = _fullLearnDraft(promptSourceNote: _importAiNote);
      final flReady = computeFullLearnReady(draft);
      expect(flReady.ready, isTrue, reason: flReady.unmetMessages.join(' | '));

      final data = storyPublishDataFromCreator(draft);
      expect(data.promptSourceNote, contains('AI_mode'));
      expect(
        resolveHtmlPromptModeFromSourceNote(data.promptSourceNote),
        resolveHtmlPromptModeForDraft(draft),
      );
      expect(resolveHtmlPromptModeForDraft(draft), HtmlPromptMode.ai);

      final preflight = validateStoryPublishData(
        data,
        ValidationMode.fullLearnPublish,
      );
      expect(
        hasBlockingIssues(preflight),
        isFalse,
        reason: preflight.issues.map((i) => '${i.code}:${i.messageKey}').join(
          ' | ',
        ),
      );
      expect(
        preflight.issues.map((i) => i.messageKey),
        isNot(contains('learn.count.quiz.range')),
      );
    });

    test(
      'B publish snapshot without promptSourceNote defaults manual and blocks',
      () {
        final draft = _fullLearnDraft(promptSourceNote: _importAiNote);
        expect(computeFullLearnReady(draft).ready, isTrue);

        final data = storyPublishDataFromCreator(draft);
        final broken = StoryPublishData(
          title: data.title,
          description: data.description,
          levelRaw: data.levelRaw,
          targetDurationBandKey: data.targetDurationBandKey,
          durationSeconds: data.durationSeconds,
          promptSourceNote: null,
          sentences: data.sentences,
          vocabEntries: data.vocabEntries,
          grammarEntries: data.grammarEntries,
          quizEntries: data.quizEntries,
          moduleWorkflowStatuses: data.moduleWorkflowStatuses,
        );

        expect(
          resolveHtmlPromptModeFromSourceNote(broken.promptSourceNote),
          HtmlPromptMode.manual,
        );
        expect(
          resolveHtmlPromptModeForDraft(draft),
          isNot(resolveHtmlPromptModeFromSourceNote(broken.promptSourceNote)),
        );

        final preflight = validateStoryPublishData(
          broken,
          ValidationMode.fullLearnPublish,
        );
        expect(hasBlockingIssues(preflight), isTrue);
        expect(
          preflight.issues.map((i) => i.code),
          contains('publish.htmlRules.storyCharsTooMany'),
        );
      },
    );

    test('C manual draft with manual-range counts passes both paths', () {
      final draft = _fullLearnDraft(
        promptSourceNote: _manualNote,
        sentenceCount: 28,
        charsPerSentence: 15,
        vocabCount: 10,
        grammarCount: 4,
        quizVocabulary: 6,
        quizGrammar: 2,
        quizSentence: 2,
      );

      expect(resolveHtmlPromptModeForDraft(draft), HtmlPromptMode.manual);
      expect(computeFullLearnReady(draft).ready, isTrue);

      final data = storyPublishDataFromCreator(draft);
      expect(
        resolveHtmlPromptModeFromSourceNote(data.promptSourceNote),
        HtmlPromptMode.manual,
      );
      final preflight = validateStoryPublishData(
        data,
        ValidationMode.fullLearnPublish,
      );
      expect(hasBlockingIssues(preflight), isFalse);
    });

    test('storyPublishDataFromCreator uses effective promptSourceNote', () {
      final draft = _fullLearnDraft(promptSourceNote: _importAiNote);
      expect(
        storyPublishDataFromCreator(draft).promptSourceNote,
        effectiveCreatorDraftPromptSourceNote(draft),
      );
    });

    test('D imported draft missing promptSourceNote backfills AI for publish', () {
      final draft = _fullLearnDraft(promptSourceNote: '');
      expect(draftQualifiesForImportAiPromptBackfill(draft), isTrue);
      expect(resolveHtmlPromptModeForDraft(draft), HtmlPromptMode.ai);

      final data = storyPublishDataFromCreator(draft);
      expect(data.promptSourceNote, contains('AI_mode'));
      expect(resolveHtmlPromptModeFromSourceNote(data.promptSourceNote), HtmlPromptMode.ai);

      final preflight = validateStoryPublishData(
        data,
        ValidationMode.fullLearnPublish,
      );
      expect(hasBlockingIssues(preflight), isFalse);
      expect(
        preflight.issues.map((i) => i.messageKey),
        isNot(contains('learn.count.quiz.range')),
      );
    });

    test('D manual creator without import signals stays Manual', () {
      final draft = CreatorStoryV1(
        basics: StoryBasics(
          storyId: 'manual-1',
          title: 'Manual',
          category: 'Daily Life',
          level: 'N4',
          description: 'd',
          promptSourceNote: '',
          targetDurationBandKey: '3_5',
          coverImageUrl: null,
          creatorOwnerId: 'o',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
        sentences: [
          StorySentenceItem(
            id: 's0',
            storyId: 'manual-1',
            orderIndex: 0,
            japaneseText: 'あ' * 20,
            meanings: const LocalizedMeanings(en: 'x', my: 'x'),
            furiganaSpans: const [],
            provenance: const ContentProvenance(sourceMode: ContentSourceMode.manual),
          ),
        ],
        vocabularyKanji: const VocabularyKanjiLayer(entries: []),
        grammar: const GrammarLayer(entries: []),
        quiz: const QuizLayer(entries: []),
        audio: const AudioLayer(),
        publishState: StoryPublishState.draft,
        moduleWorkflowStatuses: {},
      );
      expect(draftQualifiesForImportAiPromptBackfill(draft), isFalse);
      expect(resolveHtmlPromptModeForDraft(draft), HtmlPromptMode.manual);
    });

    test('E Full Learn publish does not emit legacy learn.count.quiz.range', () {
      final draft = _fullLearnDraft(promptSourceNote: '');
      final preflight = validateStoryPublishData(
        storyPublishDataFromCreator(draft),
        ValidationMode.fullLearnPublish,
      );
      expect(
        preflight.issues.map((i) => i.messageKey),
        isNot(contains('learn.count.quiz.range')),
      );
    });
  });
}
