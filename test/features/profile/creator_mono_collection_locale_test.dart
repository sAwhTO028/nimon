import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/data/creator_mono_collection.dart';

void main() {
  test('CreatorMonoCollection.fromJson parses contentLocale', () {
    final c = CreatorMonoCollection.fromJson({
      'id': 'cccccccc-cccc-cccc-cccc-cccccccccccc',
      'ownerId': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'title': 'My coll',
      'visibility': 'public',
      'itemCount': 2,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-02T00:00:00.000Z',
      'contentLocale': 'my',
    });
    expect(c.contentLocale, 'my');
  });

  test('CreatorMonoCollection.fromJson null legacy locale', () {
    final c = CreatorMonoCollection.fromJson({
      'id': 'cccccccc-cccc-cccc-cccc-cccccccccccc',
      'ownerId': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'title': 'Old',
      'visibility': 'public',
      'itemCount': 0,
      'createdAt': '',
      'updatedAt': '',
    });
    expect(c.contentLocale, isNull);
  });
}
