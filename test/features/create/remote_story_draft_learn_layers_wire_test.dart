import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/data/dto/story_draft_dto.dart';
import 'package:nimon/features/create/data/remote_story_draft_learn_layers_wire.dart';

void main() {
  group('vocabularyKanjiEntryDto wire', () {
    test('round-trip glosses, example meanings, pairs, provenance', () {
      const original = VocabularyKanjiEntryDto(
        id: 'v1',
        termJapanese: '図書館',
        type: 'vocabulary',
        reading: 'としょかん',
        glosses: LocalizedMeaningsDto(en: 'library', my: 'စာကြည့်တိုက်'),
        exampleSentence: '図書館へ行きます。',
        exampleMeanings: LocalizedMeaningsDto(en: 'I go to the library.'),
        examplePairs: [
          VocabularyExamplePairDto(source: '駅', english: 'station'),
        ],
        provenance: ContentProvenanceDto(
          sourceMode: 'manual',
          lastReviewedByCreator: true,
        ),
      );
      final wire = vocabularyKanjiEntryDtoToWireJson(original);
      final back = vocabularyKanjiEntryDtoFromWireJson(wire);
      expect(back.id, original.id);
      expect(back.termJapanese, original.termJapanese);
      expect(back.glosses?.en, 'library');
      expect(back.glosses?.my, 'စာကြည့်တိုက်');
      expect(back.exampleMeanings?.en, 'I go to the library.');
      expect(back.examplePairs, hasLength(1));
      expect(back.examplePairs.single.source, '駅');
      expect(back.examplePairs.single.english, 'station');
      expect(back.provenance?.sourceMode, 'manual');
      expect(back.provenance?.lastReviewedByCreator, isTrue);
    });

    test('tolerates malformed examplePairs', () {
      final m = <String, Object?>{
        'id': 'x',
        'termJapanese': '雨',
        'type': 'vocabulary',
        'examplePairs': [
          {'source': 'あ', 'english': 'b'},
          'bad',
          null,
          {'source': 1, 'english': 2},
        ],
      };
      final back = vocabularyKanjiEntryDtoFromWireJson(m);
      expect(back.examplePairs.length, 2);
      expect(back.examplePairs[0].source, 'あ');
      expect(back.examplePairs[1].source, '1');
      expect(back.examplePairs[1].english, '2');
    });

    test('JSON encode/decode preserves keys', () {
      const e = VocabularyKanjiEntryDto(
        id: 'k1',
        termJapanese: '環境',
        type: 'kanji',
        glosses: LocalizedMeaningsDto(en: 'environment'),
      );
      final wire = vocabularyKanjiEntryDtoToWireJson(e);
      final encoded = jsonEncode(wire);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final round = vocabularyKanjiEntryDtoFromWireJson(
        Map<String, Object?>.from(decoded),
      );
      expect(round.glosses?.en, 'environment');
    });
  });

  group('grammarEntryDto wire', () {
    test('round-trip meanings, usage, examples, relatedNote, provenance', () {
      const original = GrammarEntryDto(
        id: 'g1',
        headline: 'について',
        form: 'N + について',
        meanings: LocalizedMeaningsDto(en: 'about', my: 'အကြောင်း'),
        usage: LocalizedMeaningsDto(en: 'topic marker'),
        examples: [
          GrammarExampleDto(
            japanese: '日本について',
            meanings: LocalizedMeaningsDto(en: 'About Japan'),
          ),
        ],
        mistakeWrong: '食べるについて',
        mistakeCorrect: '食べることについて',
        relatedNote: LocalizedMeaningsDto(en: 'Use after nouns.'),
        provenance: ContentProvenanceDto(
          sourceMode: 'ai_suggested',
          lastReviewedByCreator: false,
        ),
      );
      final wire = grammarEntryDtoToWireJson(original);
      final back = grammarEntryDtoFromWireJson(wire);
      expect(back.headline, original.headline);
      expect(back.meanings?.my, 'အကြောင်း');
      expect(back.usage?.en, 'topic marker');
      expect(back.examples, hasLength(1));
      expect(back.examples.single.japanese, '日本について');
      expect(back.examples.single.meanings?.en, 'About Japan');
      expect(back.mistakeWrong, original.mistakeWrong);
      expect(back.relatedNote?.en, 'Use after nouns.');
      expect(back.provenance?.sourceMode, 'ai_suggested');
    });

    test('tolerates malformed examples list', () {
      final m = <String, Object?>{
        'id': 'g',
        'headline': 'h',
        'examples': [
          {'japanese': 'ok', 'meanings': null},
          42,
        ],
      };
      final back = grammarEntryDtoFromWireJson(m);
      expect(back.examples, hasLength(1));
      expect(back.examples.single.japanese, 'ok');
    });
  });

  group('quizEntryDto wire', () {
    test('round-trip explanations and provenance', () {
      const original = QuizEntryDto(
        id: 'q1',
        category: 'vocabulary',
        prompt: 'What does 図書館 mean?',
        options: ['library', 'school', 'park', 'hospital'],
        correctIndex: 0,
        explanations: LocalizedMeaningsDto(
          en: '図書館 is library.',
          my: 'စာကြည့်တိုက်',
        ),
        sourceNote: 'Ch1',
        provenance: ContentProvenanceDto(
          sourceMode: 'manual',
          lastReviewedByCreator: true,
        ),
      );
      final wire = quizEntryDtoToWireJson(original);
      final back = quizEntryDtoFromWireJson(wire);
      expect(back.explanations?.en, '図書館 is library.');
      expect(back.explanations?.my, 'စာကြည့်တိုက်');
      expect(back.provenance?.lastReviewedByCreator, isTrue);
      expect(back.options, original.options);
      expect(back.correctIndex, 0);
    });

    test('correctIndex accepts double', () {
      final m = <String, Object?>{
        'id': 'q',
        'category': 'grammar',
        'prompt': 'p',
        'options': <String>['a', 'b', 'c', 'd'],
        'correctIndex': 2.0,
      };
      expect(quizEntryDtoFromWireJson(m).correctIndex, 2);
    });
  });

  group('storyAudioDto wire', () {
    test('round-trip provenance and scalar fields', () {
      const original = StoryAudioDto(
        id: 'a1',
        sourceUrl: 'https://cdn.example.com/story.mp3',
        localFileName: null,
        localPath: null,
        localSizeBytes: 12000,
        localExtension: 'mp3',
        displayName: 'Lesson audio',
        durationSeconds: 90,
        provenance: ContentProvenanceDto(
          sourceMode: 'manual',
          lastReviewedByCreator: false,
        ),
      );
      final wire = storyAudioDtoToWireJson(original);
      final back = storyAudioDtoFromWireJson(wire);
      expect(back.sourceUrl, original.sourceUrl);
      expect(back.localSizeBytes, 12000);
      expect(back.durationSeconds, 90);
      expect(back.provenance?.sourceMode, 'manual');
    });

    test('localFilePath / localUri aliases when localPath absent', () {
      final m = <String, Object?>{
        'id': 'a2',
        'localFilePath': '/device/audio.m4a',
        'durationSeconds': 3.7,
      };
      final back = storyAudioDtoFromWireJson(m);
      expect(back.localPath, '/device/audio.m4a');
      expect(back.durationSeconds, 4);
    });

    test('tolerates null provenance and missing numerics', () {
      final m = <String, Object?>{
        'id': 'a3',
        'provenance': null,
      };
      final back = storyAudioDtoFromWireJson(m);
      expect(back.provenance, isNull);
      expect(back.durationSeconds, isNull);
    });
  });
}
