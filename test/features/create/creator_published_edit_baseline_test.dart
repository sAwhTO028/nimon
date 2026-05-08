import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/creator_published_edit_baseline.dart';
import 'package:nimon/features/create/story_creator_models.dart';

CreatorStoryV1 _publishedRoDraft() {
  final now = DateTime.now();
  final id = CreatorStoryV1.empty(creatorOwnerId: 'u').id;
  final basics = StoryBasics(
    storyId: id,
    title: 'T',
    category: 'cat',
    level: 'N5',
    description: 'D',
    promptSourceNote: '',
    targetDurationBandKey: '3_5',
    coverImageUrl: 'https://ex/cover.jpg',
    creatorOwnerId: 'u',
    createdAt: now,
    updatedAt: now,
  );
  final s = StorySentenceItem(
    id: 's1',
    storyId: id,
    orderIndex: 0,
    japaneseText: '私は行く。',
    reading: '',
    furiganaSpans: const [],
    meanings: LocalizedMeanings(en: 'I go.'),
  );
  final modules = {
    for (final m in LearnModuleId.values) m: LearnModuleTaskStatus.completed,
  };
  return CreatorStoryV1(
    basics: basics,
    sentences: [s],
    vocabularyKanji: const VocabularyKanjiLayer(entries: []),
    grammar: const GrammarLayer(entries: []),
    quiz: QuizLayer(
      entries: [
        QuizEntry(
          id: 'qz',
          category: CreatorQuizCategory.vocabulary,
          prompt: 'Q',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: 0,
        ),
      ],
    ),
    audio: AudioLayer(storyAudio: null),
    publishState: StoryPublishState.fullLearnPublished,
    moduleWorkflowStatuses: modules,
  );
}

void main() {
  group('computeReadOnlyEditBaselineSignature', () {
    test('title change changes signature', () {
      final d = _publishedRoDraft();
      final base = computeReadOnlyEditBaselineSignature(d);
      final changed = d.copyWith(basics: d.basics.copyWith(title: 'T2'));
      expect(computeReadOnlyEditBaselineSignature(changed), isNot(base));
    });

    test('description change changes signature', () {
      final d = _publishedRoDraft();
      final base = computeReadOnlyEditBaselineSignature(d);
      final changed =
          d.copyWith(basics: d.basics.copyWith(description: 'New desc'));
      expect(computeReadOnlyEditBaselineSignature(changed), isNot(base));
    });

    test('sentence text change changes signature', () {
      final d = _publishedRoDraft();
      final base = computeReadOnlyEditBaselineSignature(d);
      final list = [...d.sentences];
      list[0] = list[0].copyWith(japaneseText: '変更');
      expect(computeReadOnlyEditBaselineSignature(d.copyWith(sentences: list)),
          isNot(base));
    });

    test('furigana change changes signature', () {
      final d = _publishedRoDraft();
      final base = computeReadOnlyEditBaselineSignature(d);
      final list = [...d.sentences];
      list[0] = list[0].copyWith(
        furiganaSpans: [
          FuriganaSpan(start: 0, end: 1, reading: 'わ'),
        ],
      );
      expect(computeReadOnlyEditBaselineSignature(d.copyWith(sentences: list)),
          isNot(base));
    });

    test('meaning change changes signature', () {
      final d = _publishedRoDraft();
      final base = computeReadOnlyEditBaselineSignature(d);
      final list = [...d.sentences];
      list[0] = list[0].copyWith(
        meanings: LocalizedMeanings(en: 'different'),
      );
      expect(computeReadOnlyEditBaselineSignature(d.copyWith(sentences: list)),
          isNot(base));
    });

    test('baseline diff detects without dirty flag', () {
      final d0 = _publishedRoDraft();
      final b = computeReadOnlyEditBaselineSignature(d0);
      final d1 = d0.copyWith(
        basics: d0.basics.copyWith(level: 'N4'),
        hasUnpublishedCoreChanges: false,
      );
      expect(
        computeReadOnlyHasUnpublishedChangesWithBaseline(
          draft: d1,
          readOnlyPublishedCoreSig: null,
          dirty: false,
          publishedEditReadOnlyBaselineSig: b,
        ),
        true,
      );
    });

    test('server false but baseline v2 differs still dirty', () {
      final d0 = _publishedRoDraft().copyWith(hasUnpublishedCoreChanges: false);
      final baseline = computeReadOnlyEditBaselineSignature(d0);
      final d1 = d0.copyWith(
        basics: d0.basics.copyWith(category: 'other'),
        hasUnpublishedCoreChanges: false,
      );
      expect(
        computeReadOnlyHasUnpublishedChangesWithBaseline(
          draft: d1,
          readOnlyPublishedCoreSig: null,
          dirty: false,
          publishedEditReadOnlyBaselineSig: baseline,
        ),
        true,
      );
    });

    test('matched baseline and server false is up to date', () {
      final d = _publishedRoDraft().copyWith(hasUnpublishedCoreChanges: false);
      final b = computeReadOnlyEditBaselineSignature(d);
      expect(
        computeReadOnlyHasUnpublishedChangesWithBaseline(
          draft: d,
          readOnlyPublishedCoreSig: null,
          dirty: false,
          publishedEditReadOnlyBaselineSig: b,
        ),
        false,
      );
    });
  });

  group('computeFullLearnEditBaselineSignature', () {
    test('vocab entry change is dirty vs full-learn baseline', () {
      final d = _publishedRoDraft();
      final flBase = computeFullLearnEditBaselineSignature(d);
      final e = VocabularyKanjiEntry(
        id: 'v1',
        termJapanese: '猫',
        type: VocabularyKanjiEntryType.vocabulary,
      );
      final d2 = d.copyWith(
        vocabularyKanji: VocabularyKanjiLayer(entries: [e]),
        hasUnpublishedCoreChanges: false,
      );
      expect(
        computeFullLearnHasUnpublishedChangesWithBaseline(
          draft: d2,
          readOnlyPublishedCoreSig: null,
          dirty: false,
          publishedEditReadOnlyBaselineSig:
              computeReadOnlyEditBaselineSignature(d),
          publishedEditFullLearnBaselineSig: flBase,
        ),
        true,
      );
    });

    test('quiz prompt change is dirty vs full-learn baseline', () {
      final d = _publishedRoDraft();
      final flBase = computeFullLearnEditBaselineSignature(d);
      final q = [
        QuizEntry(
          id: 'qz',
          category: CreatorQuizCategory.vocabulary,
          prompt: 'Q2',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: 0,
        ),
      ];
      final d2 = d.copyWith(
        quiz: QuizLayer(entries: q),
        hasUnpublishedCoreChanges: false,
      );
      expect(
        computeFullLearnHasUnpublishedChangesWithBaseline(
          draft: d2,
          readOnlyPublishedCoreSig: null,
          dirty: false,
          publishedEditReadOnlyBaselineSig:
              computeReadOnlyEditBaselineSignature(d),
          publishedEditFullLearnBaselineSig: flBase,
        ),
        true,
      );
    });

    test('listening sourceUrl change is dirty vs full-learn baseline', () {
      final d = _publishedRoDraft();
      final flBase = computeFullLearnEditBaselineSignature(d);
      final d2 = d.copyWith(
        audio: AudioLayer(
          storyAudio: StoryAudioAsset(
            id: 'aud',
            sourceUrl: 'https://cdn/track.mp3',
          ),
        ),
        hasUnpublishedCoreChanges: false,
      );
      expect(
        computeFullLearnHasUnpublishedChangesWithBaseline(
          draft: d2,
          readOnlyPublishedCoreSig: null,
          dirty: false,
          publishedEditReadOnlyBaselineSig:
              computeReadOnlyEditBaselineSignature(d),
          publishedEditFullLearnBaselineSig: flBase,
        ),
        true,
      );
    });

    test('grammar headline change is dirty vs full-learn baseline', () {
      final d = _publishedRoDraft();
      final flBase = computeFullLearnEditBaselineSignature(d);
      final g = GrammarEntry(
        id: 'g1',
        headline: 'Head',
      );
      final d2 = d.copyWith(
        grammar: GrammarLayer(entries: [g]),
        hasUnpublishedCoreChanges: false,
      );
      expect(
        computeFullLearnHasUnpublishedChangesWithBaseline(
          draft: d2,
          readOnlyPublishedCoreSig: null,
          dirty: false,
          publishedEditReadOnlyBaselineSig:
              computeReadOnlyEditBaselineSignature(d),
          publishedEditFullLearnBaselineSig: flBase,
        ),
        true,
      );
    });

    test('matched full-learn baseline is up to date', () {
      final d = _publishedRoDraft().copyWith(hasUnpublishedCoreChanges: false);
      final roB = computeReadOnlyEditBaselineSignature(d);
      final flB = computeFullLearnEditBaselineSignature(d);
      expect(
        computeFullLearnHasUnpublishedChangesWithBaseline(
          draft: d,
          readOnlyPublishedCoreSig: null,
          dirty: false,
          publishedEditReadOnlyBaselineSig: roB,
          publishedEditFullLearnBaselineSig: flB,
        ),
        false,
      );
    });
  });
}
