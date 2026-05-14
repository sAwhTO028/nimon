/// Shared defaults for cursor-based pagination (see docs/NIMON_REPOSITORY_PAGINATION_PATTERN.md).
abstract final class PaginationDefaults {
  static const int defaultPageLimit = 20;
  static const int minPageLimit = 1;
  static const int maxPageLimit = 50;
  static const int searchDebounceMs = 250;
  static const int feedFirstPageLimit = 20;

  /// Mono Home public catalog (`GET /v1/mono/feed`) — backend default 15, max 30.
  static const int monoFeedPageLimit = 15;

  static const int profilePageLimit = 20;

  /// Owner Profile → Published → Monos (`GET /v1/published-monos` paging only).
  static const int profilePublishedMonoPageLimit = 10;

  static const int workspacePageLimit = 20;
}
