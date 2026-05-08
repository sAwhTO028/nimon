import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/pagination/paginated_state.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';
import 'package:nimon/features/profile/data/remote_public_creator_profile_repository.dart';
import 'package:nimon/features/profile/presentation/owner_profile_header_stats.dart';

void main() {
  group('publishedCountLabelForOwnerHeader', () {
    test('uses mock length when remote backend off', () {
      expect(
        publishedCountLabelForOwnerHeader(
          useRemoteBackend: false,
          mockFallbackCount: 4,
          publishedState: const PaginatedState<PublishedMonoListItemDto>(),
        ),
        '4',
      );
    });

    test('shows ellipsis while initial loading with empty items', () {
      expect(
        publishedCountLabelForOwnerHeader(
          useRemoteBackend: true,
          mockFallbackCount: 0,
          publishedState: const PaginatedState<PublishedMonoListItemDto>(
            isInitialLoading: true,
          ),
        ),
        '…',
      );
    });

    test('prefers authoritative totalCount when present', () {
      expect(
        publishedCountLabelForOwnerHeader(
          useRemoteBackend: true,
          mockFallbackCount: 0,
          publishedState: const PaginatedState<PublishedMonoListItemDto>(
            items: [],
            totalCount: 1200,
            hasMore: true,
          ),
        ),
        '1.2K',
      );
    });

    test('appends plus when paging without totalCount', () {
      final dto = PublishedMonoListItemDto(
        id: 'p0',
        ownerId: 'o',
        sourceDraftId: null,
        title: 't',
        category: 'c',
        level: 'N5',
        description: 'd',
        publishKind: null,
        displayPublishKind: 'read_only',
        coverImageUrl: null,
        targetDurationLabel: null,
        createdAt: '2026-01-01T00:00:00Z',
        updatedAt: '2026-01-02T00:00:00Z',
        contentSummary: null,
      );
      expect(
        publishedCountLabelForOwnerHeader(
          useRemoteBackend: true,
          mockFallbackCount: 0,
          publishedState: PaginatedState<PublishedMonoListItemDto>(
            items: List<PublishedMonoListItemDto>.generate(15, (_) => dto),
            hasMore: true,
          ),
        ),
        '15+',
      );
    });
  });

  group('socialMetricLabel', () {
    test('formats followers from async data', () {
      final async = AsyncValue<PublicCreatorProfile?>.data(
        PublicCreatorProfile(
          userId: 'u',
          handle: '@h',
          displayName: 'N',
          avatarUrl: null,
          coverImageUrl: null,
          bio: null,
          followersCount: 1200,
          followingCount: 5,
          isFollowingByMe: false,
        ),
      );
      expect(
        socialMetricLabel(async, (p) => p.followersCount),
        '1.2K',
      );
    });

    test('loading shows ellipsis placeholder', () {
      expect(
        socialMetricLabel(
            const AsyncLoading<PublicCreatorProfile?>(), (p) => 1),
        '…',
      );
    });
  });
}
