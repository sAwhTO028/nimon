import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/data/dto/draft_list_summary_dto.dart';

void main() {
  test('DraftListSummaryDto.fromJson parses contentLocale', () {
    final dto = DraftListSummaryDto.fromJson({
      'draftId': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'title': 'Draft',
      'level': 'n5',
      'category': 'drama',
      'status': 'draft',
      'publishState': 'draft',
      'sentenceCount': 1,
      'publishType': 'draft',
      'contentLocale': 'en',
      'learningLanguage': 'ja',
    });

    expect(dto.contentLocale, 'en');
    expect(dto.learningLanguage, 'ja');
  });

  test('DraftListSummaryDto.fromJson handles null legacy locale', () {
    final dto = DraftListSummaryDto.fromJson({
      'draftId': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'title': 'Old',
      'level': '',
      'category': '',
      'status': 'draft',
      'publishState': 'draft',
      'sentenceCount': 0,
      'publishType': 'draft',
    });

    expect(dto.contentLocale, isNull);
    expect(dto.learningLanguage, isNull);
  });
}
