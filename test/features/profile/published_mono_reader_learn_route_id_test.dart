import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';
import 'package:nimon/features/profile/data/published_mono_reader_mapper.dart';

void main() {
  const rawId = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';

  PublishedMonoDetailDto minimalDetail() {
    return PublishedMonoDetailDto(
      id: rawId,
      ownerId: '00000000-0000-4000-8000-000000000002',
      sourceDraftId: null,
      title: 'T',
      category: 'fiction',
      level: 'N4',
      description: 'D',
      publishKind: 'full_learn_v1',
      displayPublishKind: 'full_learn',
      coverImageUrl: null,
      targetDurationLabel: null,
      createdAt: '2020-01-01T00:00:00.000Z',
      updatedAt: '2020-01-01T00:00:00.000Z',
      contentSummary: null,
      content: const <String, Object?>{
        'learn': <String, Object?>{'schemaVersion': 1},
      },
    );
  }

  test('monoFeedItemFromPublishedMonoDetail keeps profile id and learn uuid',
      () {
    final item = monoFeedItemFromPublishedMonoDetail(minimalDetail());
    expect(item.id, '$kProfilePublishedMonoIdPrefix$rawId');
    expect(item.catalogMonoId, rawId);
    expect(item.monoIdForLearnRoutes, rawId);
  });
}
