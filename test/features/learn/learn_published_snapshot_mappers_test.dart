import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/data/dto/story_draft_dto.dart';
import 'package:nimon/features/learn/learn_published_snapshot_mappers.dart';
import 'package:nimon/features/learn/quiz_session.dart';
import 'package:nimon/features/learn/vocab_kanji_item.dart';
import 'package:nimon/features/profile/data/published_mono_learn_snapshot_parser.dart';

void main() {
  group('vocabKanjiItemFromPublishedEntry', () {
    test('maps localized glosses and example meanings', () {
      const dto = VocabularyKanjiEntryDto(
        id: 'v1',
        termJapanese: '図書館',
        type: 'vocabulary',
        reading: 'としょかん',
        glosses: LocalizedMeaningsDto(en: 'library', my: 'စာကြည့်တိုက်'),
        exampleSentence: '行きます。',
        exampleMeanings: LocalizedMeaningsDto(en: 'I go.', my: 'သွားတယ်။'),
      );
      final item = vocabKanjiItemFromPublishedEntry(dto);
      expect(item.term, '図書館');
      expect(item.reading, 'としょかん');
      expect(item.meaningMm, 'စာကြည့်တိုက်');
      expect(item.meaningEn, 'library');
      expect(item.exampleSentence, '行きます。');
      expect(item.exampleMeaningMm, 'သွားတယ်။');
      expect(item.exampleMeaningEn, 'I go.');
      expect(item.type, VocabKanjiType.vocabulary);
    });

    test('kanji storage key maps type', () {
      const dto = VocabularyKanjiEntryDto(
        id: 'k1',
        termJapanese: '環境',
        type: 'kanji',
        reading: 'かんきょう',
      );
      expect(vocabKanjiItemFromPublishedEntry(dto).type, VocabKanjiType.kanji);
    });
  });

  group('grammarPatternFromPublishedEntry', () {
    test('maps meanings, usage, examples, mistakes, related note', () {
      const dto = GrammarEntryDto(
        id: 'g1',
        headline: 'について',
        form: 'N + について',
        meanings: LocalizedMeaningsDto(en: 'about', my: 'အကြောင်း'),
        usage: LocalizedMeaningsDto(en: 'topic', my: 'ခေါင်းစဉ်'),
        examples: [
          GrammarExampleDto(
            japanese: '日本について',
            meanings: LocalizedMeaningsDto(my: 'ဂျပန်', en: 'Japan'),
          ),
        ],
        mistakeWrong: 'bad',
        mistakeCorrect: 'good',
        relatedNote: LocalizedMeaningsDto(my: 'မှတ်ချက်', en: 'note'),
      );
      final p = grammarPatternFromPublishedEntry(dto);
      expect(p.title, 'について');
      expect(p.form, 'N + について');
      expect(p.meaning, 'အကြောင်း');
      expect(p.meaningEn, 'about');
      expect(p.whenToUse, 'ခေါင်းစဉ်');
      expect(p.whenToUseEn, 'topic');
      expect(p.examples, hasLength(1));
      expect(p.examples.single.japanese, '日本について');
      expect(p.examples.single.myanmar, 'ဂျပန်');
      expect(p.examples.single.englishGloss, 'Japan');
      expect(p.commonMistakes, hasLength(1));
      expect(p.commonMistakes.single.incorrect, 'bad');
      expect(p.relatedNote, 'မှတ်ချက်');
      expect(p.relatedNoteEn, 'note');
    });
  });

  group('quizMcqItemFromPublishedEntry', () {
    test('pads options to four and clamps correctIndex', () {
      const dto = QuizEntryDto(
        id: 'q1',
        category: 'grammar',
        prompt: 'Pick one',
        options: ['A', 'B'],
        correctIndex: 9,
      );
      final m = quizMcqItemFromPublishedEntry(dto, sourceStoryId: 'mono-1');
      expect(m.options, hasLength(4));
      expect(m.options[0], 'A');
      expect(m.options[1], 'B');
      expect(m.options[2], '');
      expect(m.options[3], '');
      expect(m.correctIndex, 3);
      expect(m.category, LearnQuizCategory.grammar);
      expect(m.sourceStoryId, 'mono-1');
    });

    test('maps explanations', () {
      const dto = QuizEntryDto(
        id: 'q2',
        category: 'vocabulary',
        prompt: 'Q',
        options: ['a', 'b', 'c', 'd'],
        correctIndex: 0,
        explanations: LocalizedMeaningsDto(en: 'Because', my: 'ဘာကြောင့်'),
      );
      final m = quizMcqItemFromPublishedEntry(dto);
      expect(m.explanation, 'Because');
      expect(m.explanationMy, 'ဘာကြောင့်');
    });
  });

  group('shouldUsePublishedLearnSnapshot', () {
    test('true only for full learn with data', () {
      const snap = LearnPublishedSnapshot(
        schemaVersion: 1,
        vocabularyKanjiEntries: [
          VocabularyKanjiEntryDto(
              id: 'x', termJapanese: 'x', type: 'vocabulary'),
        ],
        grammarEntries: [],
        quizEntries: [],
      );
      expect(shouldUsePublishedLearnSnapshot('full_learn_v1', snap), isTrue);
      expect(shouldUsePublishedLearnSnapshot('read_only_v1', snap), isFalse);
      expect(shouldUsePublishedLearnSnapshot('full_learn_v1', null), isFalse);
      expect(
        shouldUsePublishedLearnSnapshot(
          'full_learn_v1',
          const LearnPublishedSnapshot(
            schemaVersion: 1,
            vocabularyKanjiEntries: [],
            grammarEntries: [],
            quizEntries: [],
          ),
        ),
        isFalse,
      );
    });
  });
}
