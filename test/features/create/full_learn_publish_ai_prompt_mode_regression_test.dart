import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/limits/html_generator_limits.dart';
import 'package:nimon/core/validation/publish_validation.dart';
import 'package:nimon/core/validation/validation_result.dart';
import 'package:nimon/features/create/creator_completion_rules.dart';
import 'package:nimon/features/create/creator_prompt_source_note.dart';
import 'package:nimon/features/create/creator_publish_preflight.dart';
import 'package:nimon/features/create/creator_readiness.dart';
import 'package:nimon/features/create/story_creator_models.dart';

/// Legacy-only JLPT manual gate (removed from [validateStoryPublishData]).
const _legacyQuizRangeKey = 'learn.count.quiz.range';

CreatorStoryV1 _aiImportedFullLearnDraft({
  required String promptSourceNote,
  int sentenceCount = 30,
  int charsPerSentence = 22,
}) {
  final t = 'あ' * charsPerSentence;
  final sentences = List.generate(
    sentenceCount,
    (i) => StorySentenceItem(
      id: 's$i',
      storyId: 'fl-reg',
      orderIndex: i,
      japaneseText: t,
      meanings: const LocalizedMeanings(en: 'x', my: 'x'),
      furiganaSpans: const [],
      provenance: const ContentProvenance(sourceMode: ContentSourceMode.aiDraft),
    ),
  );

  final vocab = List.generate(
    11,
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
    4,
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
    for (var i = 0; i < 7; i++) q('qv$i', CreatorQuizCategory.vocabulary),
    for (var i = 0; i < 3; i++) q('qg$i', CreatorQuizCategory.grammar),
    for (var i = 0; i < 3; i++) q('qs$i', CreatorQuizCategory.sampleSentence),
  ];

  return CreatorStoryV1(
    basics: StoryBasics(
      storyId: 'fl-reg',
      title: 'AI import regression',
      category: 'Daily Life',
      level: 'N4',
      description: 'desc',
      promptSourceNote: promptSourceNote,
      targetDurationBandKey: '3_5',
      coverImageUrl: null,
      creatorOwnerId: 'owner',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
    sentences: sentences,
    vocabularyKanji: VocabularyKanjiLayer(entries: vocab),
    grammar: GrammarLayer(entries: grammar),
    quiz: QuizLayer(entries: quiz),
    audio: AudioLayer(
      storyAudio: StoryAudioAsset(
        id: 'a1',
        sourceUrl: 'https://example.com/a.mp3',
        provenance: const ContentProvenance(sourceMode: ContentSourceMode.aiDraft),
      ),
    ),
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
  group('Full Learn publish preflight AI regression', () {
    test('legacy note [nimon-import] only backfills AI and passes with quiz 13', () {
      final raw = _aiImportedFullLearnDraft(promptSourceNote: '[nimon-import]\n');
      expect(computeFullLearnReady(raw).ready, isTrue);
      expect(resolveHtmlPromptModeForDraft(raw), HtmlPromptMode.ai);

      final pre = runFullLearnPublishPreflight(raw);
      expect(pre.resolvedMode, HtmlPromptMode.ai);
      expect(pre.publishData.promptSourceNote, contains('AI_mode'));
      expect(hasBlockingIssues(pre.validation), isFalse);
      expect(
        pre.validation.issues.map((i) => i.messageKey),
        isNot(contains(_legacyQuizRangeKey)),
      );
    });

    test('missing promptSourceNote with AI provenance backfills and passes', () {
      final raw = _aiImportedFullLearnDraft(promptSourceNote: '');
      expect(draftQualifiesForImportAiPromptBackfill(raw), isTrue);

      final pre = runFullLearnPublishPreflight(raw);
      expect(pre.resolvedMode, HtmlPromptMode.ai);
      expect(pre.publishData.promptSourceNote, contains('AI_mode'));
      expect(hasBlockingIssues(pre.validation), isFalse);
      expect(
        pre.validation.issues.map((i) => i.messageKey),
        isNot(contains(_legacyQuizRangeKey)),
      );
    });

    test('manual creator draft with quiz 20 blocks under Manual HTML rules', () {
      final manual = CreatorStoryV1(
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
            provenance:
                const ContentProvenance(sourceMode: ContentSourceMode.manual),
          ),
        ],
        vocabularyKanji: VocabularyKanjiLayer(
          entries: List.generate(
            11,
            (i) => VocabularyKanjiEntry(
              id: 'v$i',
              termJapanese: 'たんご$i',
              glosses: const LocalizedMeanings(en: 'x', my: 'x'),
              examplePairs: const [
                VocabularyExamplePair(
                  sourceExample: 'れいぶん',
                  englishExample: 'x',
                ),
              ],
              exampleSentence: 'れいぶん',
              exampleMeanings: const LocalizedMeanings(en: 'x', my: 'x'),
              provenance:
                  const ContentProvenance(sourceMode: ContentSourceMode.manual),
            ),
          ),
        ),
        grammar: GrammarLayer(
          entries: List.generate(
            4,
            (i) => GrammarEntry(
              id: 'g$i',
              headline: 'ぶんぽう$i',
              form: 'f',
              meanings: const LocalizedMeanings(en: 'x', my: 'x'),
              usage: const LocalizedMeanings(en: 'x', my: 'x'),
              examples: const [
                GrammarExample(
                  japanese: 'れいぶん',
                  meanings: LocalizedMeanings(en: 'x', my: 'x'),
                ),
              ],
              relatedNote: const LocalizedMeanings(en: 'x', my: 'x'),
              mistakeWrong: 'w',
              mistakeCorrect: 'c',
              provenance:
                  const ContentProvenance(sourceMode: ContentSourceMode.manual),
            ),
          ),
        ),
        quiz: QuizLayer(
          entries: List.generate(
            20,
            (i) => QuizEntry(
              id: 'q$i',
              category: CreatorQuizCategory.vocabulary,
              prompt: 'Question $i',
              options: const ['A', 'B', 'C', 'D'],
              correctIndex: 0,
              sourceNote: 'subtype=mcq;answer=A;target=T',
              provenance:
                  const ContentProvenance(sourceMode: ContentSourceMode.manual),
            ),
          ),
        ),
        audio: const AudioLayer(),
        publishState: StoryPublishState.draft,
        moduleWorkflowStatuses: {
          LearnModuleId.quiz: LearnModuleTaskStatus.completed,
        },
      );

      expect(resolveHtmlPromptModeForDraft(manual), HtmlPromptMode.manual);
      final pre = runFullLearnPublishPreflight(manual);
      expect(pre.resolvedMode, HtmlPromptMode.manual);
      expect(hasBlockingIssues(pre.validation), isTrue);
    });

    test('preflight uses validateStoryPublishData not legacy quizLimits tables', () {
      final raw = _aiImportedFullLearnDraft(
        promptSourceNote: 'promptDataTab=AI_mode',
      );
      final pre = runFullLearnPublishPreflight(raw);
      expect(
        pre.validation.issues.map((i) => i.code),
        isNot(contains('learn.quiz.count')),
      );
      expect(
        pre.validation.issues.map((i) => i.messageKey),
        isNot(contains(_legacyQuizRangeKey)),
      );
    });
  });
}
