import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/data/dto/story_draft_dto.dart';
import 'package:nimon/features/create/data/remote_story_draft_sentence_wire.dart';
import 'package:nimon/features/create/data/story_draft_mapper.dart';
import 'package:nimon/features/create/story_creator_models.dart';

void main() {
  group('storySentenceDto wire round-trip', () {
    test('japaneseText only', () {
      const original = StorySentenceDto(
        id: 'sid',
        storyId: 'draft',
        orderIndex: 0,
        japaneseText: 'のみかん',
      );
      final json = storySentenceDtoToWireJson(original);
      final back = storySentenceDtoFromWireJson(json);
      expect(back.id, original.id);
      expect(back.japaneseText, original.japaneseText);
      expect(back.furiganaSpans, isEmpty);
      expect(back.meanings, isNull);
    });

    test('furiganaSpans', () {
      const original = StorySentenceDto(
        id: 'sid',
        storyId: 'draft',
        orderIndex: 1,
        japaneseText: '図書館へ',
        furiganaSpans: [
          FuriganaSpanDto(start: 0, end: 3, reading: 'としょかん'),
        ],
      );
      final json = storySentenceDtoToWireJson(original);
      final back = storySentenceDtoFromWireJson(json);
      expect(back.furiganaSpans, hasLength(1));
      expect(back.furiganaSpans.single.start, 0);
      expect(back.furiganaSpans.single.end, 3);
      expect(back.furiganaSpans.single.reading, 'としょかん');
    });

    test('meanings en + my', () {
      const original = StorySentenceDto(
        id: 'sid',
        storyId: 'draft',
        orderIndex: 0,
        japaneseText: '雨',
        meanings: LocalizedMeaningsDto(
          en: 'rain',
          my: 'မိုး',
          byLanguage: {},
        ),
      );
      final json = storySentenceDtoToWireJson(original);
      final back = storySentenceDtoFromWireJson(json);
      expect(back.meanings?.en, 'rain');
      expect(back.meanings?.my, 'မိုး');
    });

    test('furiganaSpans and meanings together', () {
      const original = StorySentenceDto(
        id: 'sid',
        storyId: 'draft',
        orderIndex: 2,
        japaneseText: '駅',
        furiganaSpans: [
          FuriganaSpanDto(start: 0, end: 1, reading: 'えき'),
        ],
        meanings: LocalizedMeaningsDto(
          en: 'station',
          my: 'ဘူတာ',
        ),
      );
      final json = storySentenceDtoToWireJson(original);
      final back = storySentenceDtoFromWireJson(json);
      expect(back.furiganaSpans.single.reading, 'えき');
      expect(back.meanings?.en, 'station');
      expect(back.meanings?.my, 'ဘူတာ');
    });

    test('tolerates malformed furiganaSpans entries', () {
      final m = <String, Object?>{
        'id': 'a',
        'storyId': 'b',
        'orderIndex': 0,
        'japaneseText': 'x',
        'furiganaSpans': [
          {'start': 0, 'end': 1, 'reading': 'ok'},
          'garbage',
          {'start': 'bad', 'end': 1, 'reading': 'x'},
          null,
        ],
      };
      final back = storySentenceDtoFromWireJson(m);
      expect(back.furiganaSpans, hasLength(1));
      expect(back.furiganaSpans.single.reading, 'ok');
    });

    test('tolerates missing meanings / null', () {
      final m = <String, Object?>{
        'id': 'a',
        'storyId': 'b',
        'orderIndex': 0,
        'japaneseText': 'x',
        'meanings': null,
      };
      expect(storySentenceDtoFromWireJson(m).meanings, isNull);
    });

    test('orderIndex accepts double from JSON', () {
      final m = <String, Object?>{
        'id': 'a',
        'storyId': 'b',
        'orderIndex': 3.0,
        'japaneseText': 'x',
      };
      expect(storySentenceDtoFromWireJson(m).orderIndex, 3);
    });

    test('wire JSON includes stable keys for PUT order and overlays', () {
      const original = StorySentenceDto(
        id: 'sid',
        storyId: 'draft1',
        orderIndex: 4,
        japaneseText: '並び',
        reading: 'よみ',
      );
      final wire = storySentenceDtoToWireJson(original);
      expect(wire.containsKey('id'), true);
      expect(wire['orderIndex'], 4);
      expect(wire['japaneseText'], '並び');
      expect(wire['reading'], 'よみ');
      expect(wire['furiganaSpans'], isA<List>());
    });

    test('JSON encode/decode preserves keys expected by P1 parser', () {
      const s = StorySentenceDto(
        id: 'u1',
        storyId: 'd1',
        orderIndex: 0,
        japaneseText: '本',
        furiganaSpans: [
          FuriganaSpanDto(start: 0, end: 1, reading: 'ほん'),
        ],
        meanings: LocalizedMeaningsDto(en: 'book', my: 'စာအုပ်'),
      );
      final wire = storySentenceDtoToWireJson(s);
      final encoded = jsonEncode(wire);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final round = storySentenceDtoFromWireJson(
        Map<String, Object?>.from(decoded),
      );
      expect(round.japaneseText, '本');
      expect(round.furiganaSpans, isNotEmpty);
      expect(round.meanings?.en, 'book');
      expect(round.meanings?.my, 'စာအုပ်');
    });
  });

  group('StoryDraftMapper remote sentence list', () {
    test('fromDomain preserves each sentence orderIndex in iteration order',
        () {
      final base = CreatorStoryV1.empty();
      final sid = base.id;
      final draft = base.copyWith(
        sentences: [
          StorySentenceItem(
            id: 's1',
            storyId: sid,
            orderIndex: 2,
            japaneseText: '三',
          ),
          StorySentenceItem(
            id: 's0',
            storyId: sid,
            orderIndex: 0,
            japaneseText: '一',
          ),
        ],
      );
      final dto = StoryDraftMapper.fromDomainRemoteSafe(draft);
      expect(dto.sentences.first.orderIndex, 2);
      expect(dto.sentences.last.orderIndex, 0);
      final wired = [
        storySentenceDtoToWireJson(dto.sentences[0]),
        storySentenceDtoToWireJson(dto.sentences[1]),
      ];
      expect(wired[0]['orderIndex'], 2);
      expect(wired[1]['orderIndex'], 0);
    });
  });
}
