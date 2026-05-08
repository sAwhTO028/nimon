import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/mono/data/mono_feed_summary_dto.dart';

void main() {
  test('fromJson parses full item', () {
    final d = MonoFeedSummaryDto.fromJson({
      'monoId': 'm1',
      'title': 'T',
      'coverUrl': 'https://x/cover.png',
      'level': 'N5',
      'category': 'Love',
      'categories': <String>['Love', 'Short'],
      'description': 'D',
      'writerId': 'w1',
      'writerHandle': '@a',
      'writerDisplayName': 'A',
      'publishedAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-02T00:00:00.000Z',
      'likesCount': 3,
      'hasAudio': true,
      'isBookmarkedByMe': true,
      'myReaction': 'heart',
      'shareUrl': 'http://localhost:3000/mono/m1',
      'publishKind': 'read_only_v1',
      'accessType': 'public',
    });
    expect(d.monoId, 'm1');
    expect(d.title, 'T');
    expect(d.coverUrl, 'https://x/cover.png');
    expect(d.level, 'N5');
    expect(d.category, 'Love');
    expect(d.categories, ['Love', 'Short']);
    expect(d.description, 'D');
    expect(d.writerId, 'w1');
    expect(d.writerHandle, '@a');
    expect(d.writerDisplayName, 'A');
    expect(d.likesCount, 3);
    expect(d.hasAudio, true);
    expect(d.isBookmarkedByMe, true);
    expect(d.myReaction, 'heart');
    expect(d.shareUrl, 'http://localhost:3000/mono/m1');
    expect(d.publishKind, 'read_only_v1');
    expect(d.accessType, 'public');
  });

  test('fromJson applies safe defaults', () {
    final d = MonoFeedSummaryDto.fromJson({});
    expect(d.monoId, '');
    expect(d.title, '');
    expect(d.coverUrl, isNull);
    expect(d.categories, isEmpty);
    expect(d.likesCount, 0);
    expect(d.hasAudio, false);
    expect(d.isBookmarkedByMe, false);
    expect(d.myReaction, isNull);
    expect(d.shareUrl, isNull);
    expect(d.accessType, 'public');
  });

  test('categories fallback from category when categories missing', () {
    final d = MonoFeedSummaryDto.fromJson({
      'category': 'X',
    });
    expect(d.category, 'X');
    expect(d.categories, ['X']);
  });
}
