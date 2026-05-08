import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/data/bulk_add_creator_collection_result.dart';
import 'package:nimon/features/profile/data/creator_mono_collection.dart';

void main() {
  test('CreatorMonoCollection.fromJson maps backend DTO', () {
    final c = CreatorMonoCollection.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'ownerId': '22222222-2222-2222-2222-222222222222',
      'title': 'Daily',
      'description': 'Note',
      'coverImageUrl': 'https://x/c.jpg',
      'visibility': 'private',
      'itemCount': 3,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-02T00:00:00.000Z',
    });

    expect(c.id, '11111111-1111-1111-1111-111111111111');
    expect(c.ownerId, '22222222-2222-2222-2222-222222222222');
    expect(c.title, 'Daily');
    expect(c.description, 'Note');
    expect(c.coverImageUrl, 'https://x/c.jpg');
    expect(c.visibility, 'private');
    expect(c.itemCount, 3);
    expect(c.createdAt, '2026-01-01T00:00:00.000Z');
    expect(c.updatedAt, '2026-01-02T00:00:00.000Z');
  });

  test('BulkAddCreatorCollectionResult.fromJson maps counters', () {
    final r = BulkAddCreatorCollectionResult.fromJson({
      'inserted': 2,
      'skippedDuplicates': 1,
      'skippedNotOwnedOrMissing': 4,
    });
    expect(r.inserted, 2);
    expect(r.skippedDuplicates, 1);
    expect(r.skippedNotOwnedOrMissing, 4);
  });
}
