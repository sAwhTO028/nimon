import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/validation/publish_validation.dart';
import 'package:nimon/core/validation/validation_mode.dart';
import 'package:nimon/core/validation/validation_result.dart';

List<Map<String, Object?>> _enSentences({int count = 24, int charsPerSentence = 50}) {
  final t = 'a' * charsPerSentence;
  return List.generate(
    count,
    (_) => {
      'content': {'japaneseText': t},
    },
  );
}

List<Map<String, Object?>> _jpSentences({int count = 24, int charsPerSentence = 15}) {
  final t = 'あ' * charsPerSentence;
  return List.generate(
    count,
    (_) => {
      'content': {'japaneseText': t},
    },
  );
}

const _modules = {
  'vocabulary_kanji': 'completed',
  'grammar': 'completed',
  'quiz': 'completed',
  'audio': 'completed',
};

Map<String, Object?> _kanjiVocab({
  String? reading,
  String type = 'kanji',
  String term = '猫',
}) =>
    {
      'content': {
        'termJapanese': term,
        'type': type,
        if (reading != null) 'reading': reading,
        'glosses': {'my': 'cat'},
      },
    };

Map<String, Object?> _quizItem(String id, String category) => {
      'content': {
        'category': category,
        'prompt': 'Question $id long enough?',
        'options': ['a', 'b', 'c', 'd'],
        'correctIndex': 0,
      },
    };

/// EN AI N5 3_5 full-learn body (8 vocab, 3 grammar, 11 quizzes, 24×50 chars).
StoryPublishData _enFullLearnValid({
  required String? learningLanguage,
  List<Map<String, Object?>>? vocabEntries,
}) {
  final vocab = vocabEntries ??
      [
        _kanjiVocab(),
        for (var i = 1; i < 8; i++)
          _kanjiVocab(term: 'word$i', type: 'vocabulary'),
      ];
  return StoryPublishData(
    title: 'Valid story title long enough',
    description: 'd',
    levelRaw: 'N5',
    targetDurationBandKey: '3_5',
    learningLanguage: learningLanguage,
    promptSourceNote: 'promptDataTab=AI_mode',
    sentences: _enSentences(),
    vocabEntries: vocab,
    grammarEntries: List.generate(
      3,
      (i) => {'content': {'headline': 'Pattern $i ok'}},
    ),
    quizEntries: [
      for (var i = 0; i < 5; i++) _quizItem('v$i', 'vocabulary'),
      for (var i = 0; i < 3; i++) _quizItem('g$i', 'grammar'),
      for (var i = 0; i < 3; i++) _quizItem('s$i', 'sample_sentence'),
    ],
    moduleWorkflowStatuses: _modules,
  );
}

StoryPublishData _jaFullLearnFuriganaProbe({
  required String? learningLanguage,
  required List<Map<String, Object?>> vocabEntries,
}) {
  return StoryPublishData(
    title: 'Valid story title long enough',
    description: 'd',
    levelRaw: 'N5',
    targetDurationBandKey: '3_5',
    learningLanguage: learningLanguage,
    promptSourceNote: 'promptDataTab=AI_mode',
    sentences: _jpSentences(),
    vocabEntries: vocabEntries,
    grammarEntries: [
      {'content': {'headline': 'Pattern headline ok'}},
    ],
    quizEntries: [
      _quizItem('q0', 'vocabulary'),
    ],
    moduleWorkflowStatuses: _modules,
  );
}

void main() {
  group('conditional furigana (M23A-5A)', () {
    test('JA+MY kanji vocab without reading blocks', () {
      final r = validateStoryPublishData(
        _jaFullLearnFuriganaProbe(
          learningLanguage: 'ja',
          vocabEntries: [_kanjiVocab()],
        ),
        ValidationMode.fullLearnPublish,
      );
      expect(hasBlockingIssues(r), isTrue);
      expect(
        r.issues.map((i) => i.code),
        contains('learn.vocab.reading.required'),
      );
    });

    test('JA+MY invalid kana reading blocks', () {
      final r = validateStoryPublishData(
        _jaFullLearnFuriganaProbe(
          learningLanguage: 'ja',
          vocabEntries: [_kanjiVocab(reading: 'invalidlatin')],
        ),
        ValidationMode.fullLearnPublish,
      );
      expect(hasBlockingIssues(r), isTrue);
      expect(
        r.issues.map((i) => i.code),
        contains('learn.vocab.reading.invalidChars'),
      );
    });

    test('legacy null learningLanguage still enforces furigana', () {
      final r = validateStoryPublishData(
        _jaFullLearnFuriganaProbe(
          learningLanguage: null,
          vocabEntries: [_kanjiVocab()],
        ),
        ValidationMode.fullLearnPublish,
      );
      expect(hasBlockingIssues(r), isTrue);
      expect(
        r.issues.map((i) => i.code),
        contains('learn.vocab.reading.required'),
      );
    });

    test('EN+MY kanji vocab without reading passes', () {
      final r = validateStoryPublishData(
        _enFullLearnValid(
          learningLanguage: 'en',
          vocabEntries: [
            _kanjiVocab(),
            for (var i = 1; i < 8; i++)
              _kanjiVocab(term: 'word$i', type: 'vocabulary'),
          ],
        ),
        ValidationMode.fullLearnPublish,
      );
      expect(hasBlockingIssues(r), isFalse, reason: r.toString());
      final codes = r.issues.map((i) => i.code).toList();
      expect(codes, isNot(contains('learn.vocab.reading.required')));
      expect(codes, isNot(contains('learn.vocab.reading.invalidChars')));
    });

    test('EN+JA kanji vocab without reading passes', () {
      final r = validateStoryPublishData(
        _enFullLearnValid(
          learningLanguage: 'en',
          vocabEntries: [
            _kanjiVocab(),
            for (var i = 1; i < 8; i++)
              _kanjiVocab(term: 'word$i', type: 'vocabulary'),
          ],
        ),
        ValidationMode.fullLearnPublish,
      );
      expect(hasBlockingIssues(r), isFalse, reason: r.toString());
    });

    test('EN draft with reading omitted passes', () {
      final r = validateStoryPublishData(
        _enFullLearnValid(
          learningLanguage: 'en',
          vocabEntries: [
            for (var i = 0; i < 8; i++)
              {
                'content': {
                  'termJapanese': 'word$i',
                  'type': 'vocabulary',
                  'glosses': {'my': 'm$i'},
                },
              },
          ],
        ),
        ValidationMode.fullLearnPublish,
      );
      expect(hasBlockingIssues(r), isFalse, reason: r.toString());
    });

    test('EN draft with Latin reading text passes', () {
      final r = validateStoryPublishData(
        _enFullLearnValid(
          learningLanguage: 'en',
          vocabEntries: [
            _kanjiVocab(reading: 'invalidlatin'),
            for (var i = 1; i < 8; i++)
              _kanjiVocab(term: 'word$i', type: 'vocabulary'),
          ],
        ),
        ValidationMode.fullLearnPublish,
      );
      expect(hasBlockingIssues(r), isFalse, reason: r.toString());
    });
  });
}
