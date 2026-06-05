import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/mono/data/mono_feed_item_mapper.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';
import 'package:nimon/features/mono/data/mono_feed_summary_dto.dart';
import 'package:nimon/features/search/data/mono_search_result.dart';

void main() {
  test('monoFeedItemFromMonoFeedSummary carries locale pair', () {
    final dto = MonoFeedSummaryDto.fromJson({
      'monoId': 'm1',
      'title': 'T',
      'level': 'N5',
      'contentLocale': 'en',
      'learningLanguage': 'ja',
      'writerId': 'u',
      'likesCount': 0,
      'hasAudio': false,
      'isBookmarkedByMe': false,
    });
    final feed = monoFeedItemFromMonoFeedSummary(dto);
    expect(feed.contentLocale, 'en');
    expect(feed.learningLanguage, 'ja');
  });

  test('monoFeedItemFromMonoSearchResult carries locale pair', () {
    final result = MonoSearchResult(
      listItem: publishedMonoListItemDtoFromBackendJson({
        'id': 'm1',
        'ownerId': 'o1',
        'title': 'T',
        'category': 'c',
        'level': 'N5',
        'description': 'd',
        'displayPublishKind': 'read_only',
        'createdAt': '2020-01-01T00:00:00.000Z',
        'updatedAt': '2020-01-01T00:00:00.000Z',
        'contentLocale': 'my',
        'learningLanguage': 'ja',
      }),
    );
    final feed = monoFeedItemFromMonoSearchResult(result);
    expect(feed.contentLocale, 'my');
    expect(feed.learningLanguage, 'ja');
  });
}
