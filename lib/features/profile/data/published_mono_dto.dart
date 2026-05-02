/// DTOs for GET `/v1/published-monos` and GET `/v1/published-monos/:id` (Nimon backend).

class PublishedMonoListItemDto {
  const PublishedMonoListItemDto({
    required this.id,
    required this.ownerId,
    required this.sourceDraftId,
    required this.title,
    required this.category,
    required this.level,
    required this.description,
    required this.publishKind,
    required this.displayPublishKind,
    required this.coverImageUrl,
    required this.targetDurationLabel,
    required this.createdAt,
    required this.updatedAt,
    required this.contentSummary,
  });

  final String id;
  final String ownerId;
  final String? sourceDraftId;
  final String title;
  final String category;
  final String level;
  final String description;
  final String? publishKind;

  /// `read_only` | `full_learn` | `unknown`
  final String displayPublishKind;
  final String? coverImageUrl;
  final String? targetDurationLabel;
  final String createdAt;
  final String updatedAt;
  final Object? contentSummary;
}

class PublishedMonoListResponseDto {
  const PublishedMonoListResponseDto({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
    this.totalCount,
  });

  final List<PublishedMonoListItemDto> items;

  /// Opaque cursor for the next page; absent in legacy responses → null.
  final String? nextCursor;

  /// Whether more pages exist; absent in legacy responses → false.
  final bool hasMore;

  /// Optional total; absent in legacy responses → null.
  final int? totalCount;
}

class PublishedMonoDetailDto {
  const PublishedMonoDetailDto({
    required this.id,
    required this.ownerId,
    required this.sourceDraftId,
    required this.title,
    required this.category,
    required this.level,
    required this.description,
    required this.publishKind,
    required this.displayPublishKind,
    required this.coverImageUrl,
    required this.targetDurationLabel,
    required this.createdAt,
    required this.updatedAt,
    required this.contentSummary,
    required this.content,
  });

  final String id;
  final String ownerId;
  final String? sourceDraftId;
  final String title;
  final String category;
  final String level;
  final String description;
  final String? publishKind;
  final String displayPublishKind;
  final String? coverImageUrl;
  final String? targetDurationLabel;
  final String createdAt;
  final String updatedAt;
  final Object? contentSummary;
  final Object? content;
}
