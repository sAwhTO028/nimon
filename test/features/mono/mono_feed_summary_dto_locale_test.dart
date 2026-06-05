import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/mono/data/mono_feed_summary_dto.dart';

void main() {
  test('MonoFeedSummaryDto.fromJson parses locale pair', () {
    final dto = MonoFeedSummaryDto.fromJson({
      'monoId': 'm1',
      'title': 'T',
      'level': 'N5',
      'contentLocale': 'my',
      'learningLanguage': 'ja',
      'writerId': 'u',
      'likesCount': 0,
      'hasAudio': false,
      'isBookmarkedByMe': false,
    });
    expect(dto.contentLocale, 'my');
    expect(dto.learningLanguage, 'ja');
  });

  test('MonoFeedSummaryDto.fromJson null locale fields are null', () {
    final dto = MonoFeedSummaryDto.fromJson({
      'monoId': 'm1',
      'title': 'T',
      'level': 'N5',
      'contentLocale': null,
      'learningLanguage': null,
      'writerId': 'u',
      'likesCount': 0,
      'hasAudio': false,
      'isBookmarkedByMe': false,
    });
    expect(dto.contentLocale, isNull);
    expect(dto.learningLanguage, isNull);
  });
}
