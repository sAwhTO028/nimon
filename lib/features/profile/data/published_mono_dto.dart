// DTOs for GET `/v1/published-monos` and GET `/v1/published-monos/:id` (Nimon backend).

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
    this.trashedAt,
    this.writerDisplayName,
    this.writerHandle,
    this.writerAvatarUrl,
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

  /// ISO-8601 when trashed; usually present on `GET ?trashed=true` rows.
  final String? trashedAt;

  /// Live creator profile (M9f); null when absent from payload.
  final String? writerDisplayName;
  final String? writerHandle;
  final String? writerAvatarUrl;
}

/// Result of `POST .../trash` or `POST .../restore`.
class PublishedMonoTrashMutationResult {
  const PublishedMonoTrashMutationResult({
    required this.id,
    required this.trashedAt,
  });

  final String id;

  /// Set after trash; **null** after a successful restore.
  final String? trashedAt;
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
    this.likesCount = 0,
    this.isBookmarkedByMe = false,
    this.myReaction,
    this.shareUrl,
    this.writerDisplayName,
    this.writerHandle,
    this.writerAvatarUrl,
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

  /// Server-derived `COUNT(mono_reactions)` (M7a).
  final int likesCount;

  /// Bookmark state for the current viewer (guest-safe default false) (M7a).
  final bool isBookmarkedByMe;

  /// Viewer reaction kind for the current viewer (V1: `'heart'`), null when absent (M7a).
  final String? myReaction;

  /// Canonical share URL, when present (M7a).
  final String? shareUrl;

  final String? writerDisplayName;
  final String? writerHandle;
  final String? writerAvatarUrl;
}

/// Linked story-draft id from owner Published Mono API JSON.
///
/// The backend stores `sourceDraftId` inside the published `content` JSON blob; the
/// serialized DTO usually also duplicates it at the **root** for list/detail rows.
/// This reader accepts either shape so the Flutter client does not miss the link.
String? readPublishedMonoSourceDraftIdFromJson(Map<String, Object?> json) {
  String? trimId(Object? v) {
    if (v == null) return null;
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    final t = v.toString().trim();
    return t.isEmpty ? null : t;
  }

  final direct = trimId(json['sourceDraftId']);
  if (direct != null) return direct;
  final raw = json['content'];
  if (raw is Map) {
    return trimId(raw['sourceDraftId']);
  }
  return null;
}

/// Parses an API published-mono **list row** (same fields as `GET /v1/published-monos`).
PublishedMonoListItemDto publishedMonoListItemDtoFromBackendJson(
  Map<String, Object?> it,
) {
  String? optStr(Object? v) {
    if (v == null) return null;
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    final t = v.toString().trim();
    return t.isEmpty ? null : t;
  }

  return PublishedMonoListItemDto(
    id: optStr(it['id']) ?? '',
    ownerId: optStr(it['ownerId']) ?? '',
    sourceDraftId: readPublishedMonoSourceDraftIdFromJson(it),
    title: optStr(it['title']) ?? '',
    category: optStr(it['category']) ?? '',
    level: optStr(it['level']) ?? '',
    description: optStr(it['description']) ?? '',
    publishKind: optStr(it['publishKind']),
    displayPublishKind: optStr(it['displayPublishKind']) ?? 'unknown',
    coverImageUrl: optStr(it['coverImageUrl']),
    targetDurationLabel: optStr(it['targetDurationLabel']),
    createdAt: optStr(it['createdAt']) ?? '',
    updatedAt: optStr(it['updatedAt']) ?? '',
    contentSummary: it['contentSummary'],
    trashedAt: optStr(it['trashedAt']),
    writerDisplayName: optStr(it['writerDisplayName']),
    writerHandle: optStr(it['writerHandle']),
    writerAvatarUrl: optStr(it['writerAvatarUrl']),
  );
}
