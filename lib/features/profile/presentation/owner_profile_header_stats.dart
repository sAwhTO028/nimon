import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/core/format_social_count.dart';
import 'package:nimon/core/pagination/paginated_state.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';
import 'package:nimon/features/profile/data/remote_public_creator_profile_repository.dart';

/// Published tab count label for the signed-in owner profile header.
///
/// When [useRemoteBackend] is false, returns [mockFallbackCount] as decimal digits
/// (legacy local demo).
///
/// When remote: prefers API [PaginatedState.totalCount]; otherwise uses loaded page
/// size and appends "+" when more pages exist (approximate until fully loaded).
String publishedCountLabelForOwnerHeader({
  required bool useRemoteBackend,
  required int mockFallbackCount,
  required PaginatedState<PublishedMonoListItemDto> publishedState,
}) {
  if (!useRemoteBackend) {
    return mockFallbackCount.toString();
  }
  if (publishedState.isInitialLoading && publishedState.items.isEmpty) {
    return '…';
  }
  final tc = publishedState.totalCount;
  if (tc != null) {
    return formatSocialCount(tc);
  }
  final n = publishedState.items.length;
  if (publishedState.hasMore) {
    if (n <= 0) {
      return '0+';
    }
    return '${formatSocialCount(n)}+';
  }
  return formatSocialCount(n);
}

/// Followers / following compact labels from optional-auth public profile fetch.
String socialMetricLabel(
  AsyncValue<PublicCreatorProfile?> profileAsync,
  int Function(PublicCreatorProfile p) pick,
) {
  return profileAsync.when(
    data: (p) {
      if (p == null) {
        return formatSocialCount(0);
      }
      return formatSocialCount(pick(p));
    },
    loading: () => '…',
    error: (_, __) => '—',
  );
}
