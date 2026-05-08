import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/learn/learn_published_snapshot_providers.dart';
import 'package:nimon/features/mono/data/mono_feed_providers.dart';
import 'package:nimon/features/mono/data/mono_feed_repository.dart';
import 'package:nimon/features/mono/data/mono_feed_summary_dto.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';

class _FakeMonoRepo implements MonoFeedRepository {
  _FakeMonoRepo(this._detail, {this.onDetail});

  final PublishedMonoDetailDto _detail;
  final void Function()? onDetail;
  int detailCalls = 0;

  @override
  Future<PageResult<MonoFeedSummaryDto>> fetchFeedPage(
    PageRequest request, {
    String? level,
    String? category,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PublishedMonoDetailDto> fetchMonoDetail(String monoId) async {
    detailCalls++;
    onDetail?.call();
    return _detail;
  }
}

PublishedMonoDetailDto _detailWithLearn() {
  return PublishedMonoDetailDto(
    id: 'm1',
    ownerId: 'o1',
    sourceDraftId: 'd1',
    title: 'T',
    category: 'c',
    level: 'n5',
    description: 'd',
    publishKind: 'full_learn_v1',
    displayPublishKind: 'full_learn',
    coverImageUrl: null,
    targetDurationLabel: null,
    createdAt: 'a',
    updatedAt: 'b',
    contentSummary: null,
    content: <String, Object?>{
      'learn': {
        'schemaVersion': 1,
        'vocabularyKanji': {
          'entries': [
            {
              'id': 'v1',
              'termJapanese': '猫',
              'type': 'vocabulary',
            },
          ],
        },
        'grammar': {'entries': <Object?>[]},
        'quiz': {'entries': <Object?>[]},
        'audio': {'storyAudio': null},
      },
    },
  );
}

PublishedMonoDetailDto _detailWithoutLearn() {
  return PublishedMonoDetailDto(
    id: 'm2',
    ownerId: 'o1',
    sourceDraftId: null,
    title: 'T',
    category: 'c',
    level: 'n5',
    description: 'd',
    publishKind: 'read_only_v1',
    displayPublishKind: 'read_only',
    coverImageUrl: null,
    targetDurationLabel: null,
    createdAt: 'a',
    updatedAt: 'b',
    contentSummary: null,
    content: <String, Object?>{
      'core': {'sentences': <Object?>[]},
    },
  );
}

void main() {
  test('provider parses learn after detail fetch', () async {
    final fake = _FakeMonoRepo(_detailWithLearn());
    final container = ProviderContainer(
      overrides: [
        remoteMonoFeedRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    await container.read(catalogPublishedMonoDetailProvider('m1').future);
    final snapAsync = container.read(learnPublishedSnapshotProvider('m1'));

    expect(snapAsync.hasValue, isTrue);
    expect(snapAsync.value, isNotNull);
    expect(snapAsync.value!.vocabularyKanjiEntries, hasLength(1));
    expect(snapAsync.value!.vocabularyKanjiEntries.single.termJapanese, '猫');
    expect(fake.detailCalls, 1);
  });

  test('provider returns null snapshot when learn missing', () async {
    final fake = _FakeMonoRepo(_detailWithoutLearn());
    final container = ProviderContainer(
      overrides: [
        remoteMonoFeedRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    await container.read(catalogPublishedMonoDetailProvider('m2').future);
    final snapAsync = container.read(learnPublishedSnapshotProvider('m2'));

    expect(snapAsync.hasValue, isTrue);
    expect(snapAsync.value, isNull);
  });

  test('second read of catalog detail does not refetch', () async {
    final fake = _FakeMonoRepo(_detailWithLearn());
    final container = ProviderContainer(
      overrides: [
        remoteMonoFeedRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    await container.read(catalogPublishedMonoDetailProvider('m1').future);
    await container.read(catalogPublishedMonoDetailProvider('m1').future);
    expect(fake.detailCalls, 1);
  });

  test('empty monoId yields AsyncData null without fetch', () {
    final fake = _FakeMonoRepo(_detailWithLearn());
    final container = ProviderContainer(
      overrides: [
        remoteMonoFeedRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    final snap = container.read(learnPublishedSnapshotProvider('  '));
    expect(snap.hasValue, isTrue);
    expect(snap.value, isNull);
    expect(fake.detailCalls, 0);
  });

  test('provider surfaces fetch errors', () async {
    final bad = _FakeMonoRepo(
      _detailWithLearn(),
      onDetail: () => throw StateError('network'),
    );
    final container = ProviderContainer(
      overrides: [
        remoteMonoFeedRepositoryProvider.overrideWithValue(bad),
      ],
    );
    addTearDown(container.dispose);

    try {
      await container.read(catalogPublishedMonoDetailProvider('m1').future);
      fail('expected throw');
    } on StateError catch (_) {}
    final snapAsync = container.read(learnPublishedSnapshotProvider('m1'));
    expect(snapAsync.hasError, isTrue);
  });
}
