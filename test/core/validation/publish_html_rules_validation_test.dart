import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/validation/publish_validation.dart';
import 'package:nimon/core/validation/validation_mode.dart';
import 'package:nimon/core/validation/validation_result.dart';

List<Map<String, Object?>> _sentences({
  required int count,
  required int charsPerSentence,
}) {
  final t = 'あ' * charsPerSentence;
  return List.generate(
    count,
    (i) => {
      'content': {'japaneseText': t},
    },
  );
}

List<Map<String, Object?>> _vocab(int count) => List.generate(
      count,
      (i) => {
        'content': {
          'termJapanese': 'たんご$i',
          'type': 'vocabulary',
          'glosses': {'en': 'x', 'my': 'x'},
        },
      },
    );

List<Map<String, Object?>> _grammar(int count) => List.generate(
      count,
      (i) => {
        'content': {'headline': 'ぶんぽう$i'},
      },
    );

Map<String, Object?> _quizItem(String id, String category) => {
      'content': {
        'category': category,
        'prompt': 'Question $id',
        'options': ['A', 'B', 'C', 'D'],
        'correctIndex': 0,
      },
    };

List<Map<String, Object?>> _quiz({
  required int vocab,
  required int grammar,
  required int sentence,
  required int kanji,
}) {
  return [
    for (var i = 0; i < vocab; i++) _quizItem('v$i', 'vocabulary'),
    for (var i = 0; i < grammar; i++) _quizItem('g$i', 'grammar'),
    for (var i = 0; i < sentence; i++) _quizItem('s$i', 'sample_sentence'),
    for (var i = 0; i < kanji; i++) _quizItem('k$i', 'kanji'),
  ];
}

StoryPublishData _base({
  required ValidationMode mode,
  String levelRaw = 'N4',
  String targetBand = '5_7',
  String promptSourceNote = 'promptDataTab=AI_mode',
  int sentenceCount = 42,
  int charsPerSentence = 18,
  int vocabCount = 0,
  int grammarCount = 0,
  List<Map<String, Object?>> quiz = const [],
  Map<String, String> moduleStatuses = const {},
}) {
  return StoryPublishData(
    title: 'Hello title ok long enough',
    description: 'desc',
    levelRaw: levelRaw,
    targetDurationBandKey: targetBand,
    durationSeconds: null,
    promptSourceNote: promptSourceNote,
    sentences: _sentences(count: sentenceCount, charsPerSentence: charsPerSentence),
    vocabEntries: _vocab(vocabCount),
    grammarEntries: _grammar(grammarCount),
    quizEntries: quiz,
    moduleWorkflowStatuses: moduleStatuses,
  );
}

void main() {
  group('publish preflight uses HTML generator rules', () {
    test('A. ReadOnly AI JP N4 5_7 valid story passes', () {
      final r = validateStoryPublishData(
        _base(mode: ValidationMode.readOnlyPublish),
        ValidationMode.readOnlyPublish,
      );
      expect(hasBlockingIssues(r), isFalse, reason: r.toString());
    });

    test('B. ReadOnly too few sentences blocks', () {
      final r = validateStoryPublishData(
        _base(mode: ValidationMode.readOnlyPublish, sentenceCount: 41),
        ValidationMode.readOnlyPublish,
      );
      expect(hasBlockingIssues(r), isTrue);
      expect(r.issues.map((i) => i.code), contains('publish.htmlRules.storySentenceTooFew'));
    });

    test('C. ReadOnly too many sentences blocks', () {
      final r = validateStoryPublishData(
        _base(mode: ValidationMode.readOnlyPublish, sentenceCount: 61),
        ValidationMode.readOnlyPublish,
      );
      expect(hasBlockingIssues(r), isTrue);
      expect(r.issues.map((i) => i.code), contains('publish.htmlRules.storySentenceTooMany'));
    });

    test('D. ReadOnly too few chars blocks', () {
      final r = validateStoryPublishData(
        _base(mode: ValidationMode.readOnlyPublish, charsPerSentence: 17),
        ValidationMode.readOnlyPublish,
      );
      expect(hasBlockingIssues(r), isTrue);
      expect(r.issues.map((i) => i.code), contains('publish.htmlRules.storyCharsTooFew'));
    });

    test('E. ReadOnly too many chars blocks', () {
      final r = validateStoryPublishData(
        _base(mode: ValidationMode.readOnlyPublish, charsPerSentence: 27),
        ValidationMode.readOnlyPublish,
      );
      expect(hasBlockingIssues(r), isTrue);
      expect(r.issues.map((i) => i.code), contains('publish.htmlRules.storyCharsTooMany'));
    });

    test('F. FullLearn AI JP N4 5_7 default valid passes', () {
      final modules = {
        'vocabulary_kanji': 'completed',
        'grammar': 'completed',
        'quiz': 'completed',
        'audio': 'completed',
      };
      final r = validateStoryPublishData(
        _base(
          mode: ValidationMode.fullLearnPublish,
          vocabCount: 16,
          grammarCount: 6,
          quiz: _quiz(vocab: 11, grammar: 5, sentence: 4, kanji: 1),
          moduleStatuses: modules,
        ),
        ValidationMode.fullLearnPublish,
      );
      expect(
        hasBlockingIssues(r),
        isFalse,
        reason: '${r.toString()} issues=${r.issues.map((i) => i.code).toList()}',
      );
    });

    test('G. FullLearn AI audio module not completed blocks', () {
      final modules = {
        'vocabulary_kanji': 'completed',
        'grammar': 'completed',
        'quiz': 'completed',
        'audio': 'not_started',
      };
      final r = validateStoryPublishData(
        _base(
          mode: ValidationMode.fullLearnPublish,
          vocabCount: 16,
          grammarCount: 6,
          quiz: _quiz(vocab: 11, grammar: 5, sentence: 4, kanji: 1),
          moduleStatuses: modules,
        ),
        ValidationMode.fullLearnPublish,
      );
      expect(hasBlockingIssues(r), isTrue);
      expect(r.issues.map((i) => i.code), contains('learn.module.audio.notCompleted'));
    });

    test('H. FullLearn AI vocab mismatch blocks', () {
      final modules = {
        'vocabulary_kanji': 'completed',
        'grammar': 'completed',
        'quiz': 'completed',
        'audio': 'completed',
      };
      final r = validateStoryPublishData(
        _base(
          mode: ValidationMode.fullLearnPublish,
          vocabCount: 15,
          grammarCount: 6,
          quiz: _quiz(vocab: 11, grammar: 5, sentence: 4, kanji: 1),
          moduleStatuses: modules,
        ),
        ValidationMode.fullLearnPublish,
      );
      expect(hasBlockingIssues(r), isTrue);
      expect(r.issues.map((i) => i.code), contains('publish.htmlRules.vocabularyCountMismatch'));
    });

    test('I. FullLearn AI quiz distribution mismatch blocks', () {
      final modules = {
        'vocabulary_kanji': 'completed',
        'grammar': 'completed',
        'quiz': 'completed',
        'audio': 'completed',
      };
      final r = validateStoryPublishData(
        _base(
          mode: ValidationMode.fullLearnPublish,
          vocabCount: 16,
          grammarCount: 6,
          quiz: _quiz(vocab: 10, grammar: 5, sentence: 4, kanji: 2), // keep total 21
          moduleStatuses: modules,
        ),
        ValidationMode.fullLearnPublish,
      );
      expect(hasBlockingIssues(r), isTrue);
      expect(r.issues.map((i) => i.code), contains('publish.htmlRules.quizVocabularyMismatch'));
    });

    test('J. Manual mode uses manual ranges (JP N4 5_7 vocab 12–24)', () {
      final modules = {
        'vocabulary_kanji': 'completed',
        'grammar': 'completed',
        'quiz': 'completed',
        'audio': 'completed',
      };

      final pass = validateStoryPublishData(
        _base(
          mode: ValidationMode.fullLearnPublish,
          promptSourceNote: 'promptDataTab=Manual_mode',
          sentenceCount: 32,
          charsPerSentence: 18,
          vocabCount: 12,
          grammarCount: 4,
          quiz: _quiz(vocab: 8, grammar: 3, sentence: 3, kanji: 0),
          moduleStatuses: modules,
        ),
        ValidationMode.fullLearnPublish,
      );
      expect(
        hasBlockingIssues(pass),
        isFalse,
        reason:
            '${pass.toString()} issues=${pass.issues.map((i) => i.code).toList()}',
      );

      final low = validateStoryPublishData(
        _base(
          mode: ValidationMode.fullLearnPublish,
          promptSourceNote: 'promptDataTab=Manual_mode',
          sentenceCount: 32,
          charsPerSentence: 18,
          vocabCount: 11,
          grammarCount: 4,
          quiz: _quiz(vocab: 8, grammar: 3, sentence: 3, kanji: 0),
          moduleStatuses: modules,
        ),
        ValidationMode.fullLearnPublish,
      );
      expect(hasBlockingIssues(low), isTrue);
      expect(low.issues.map((i) => i.code), contains('publish.htmlRules.vocabularyCountMismatch'));

      final high = validateStoryPublishData(
        _base(
          mode: ValidationMode.fullLearnPublish,
          promptSourceNote: 'promptDataTab=Manual_mode',
          sentenceCount: 32,
          charsPerSentence: 18,
          vocabCount: 25,
          grammarCount: 4,
          quiz: _quiz(vocab: 8, grammar: 3, sentence: 3, kanji: 0),
          moduleStatuses: modules,
        ),
        ValidationMode.fullLearnPublish,
      );
      expect(hasBlockingIssues(high), isTrue);
      expect(high.issues.map((i) => i.code), contains('publish.htmlRules.vocabularyCountMismatch'));
    });

    test('M. English still not enabled (no EN mode added)', () {
      // There is no language field on StoryPublishData in V1; publish preflight always uses JP.
      final r = validateStoryPublishData(
        _base(mode: ValidationMode.readOnlyPublish),
        ValidationMode.readOnlyPublish,
      );
      expect(hasBlockingIssues(r), isFalse);
    });
  });
}

