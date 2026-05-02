/// V1 product contract: Published Mono list + reader behavior (Nimon).

import 'package:nimon/features/profile/data/published_mono_dto.dart';

/// `displayPublishKind` from the API (`read_only` / `full_learn` / `unknown`).
enum PublishedDisplayKind { readOnly, fullLearn, unknown }

PublishedDisplayKind displayKindFromApi(String? raw) {
  switch (raw) {
    case 'read_only':
      return PublishedDisplayKind.readOnly;
    case 'full_learn':
      return PublishedDisplayKind.fullLearn;
    default:
      return PublishedDisplayKind.unknown;
  }
}

String publishBadgeLabel(PublishedDisplayKind k) {
  return switch (k) {
    PublishedDisplayKind.readOnly => 'Read only',
    PublishedDisplayKind.fullLearn => 'Full learn',
    PublishedDisplayKind.unknown => 'Published',
  };
}

/// Drives [MonoFeedItem] Learn gating in [MonoScreen].
class PublishedMonoAccess {
  const PublishedMonoAccess({
    required this.isReadOnlyPublished,
    required this.isFullLearnPublished,
    this.learnModulesInPayload = false,
  });

  final bool isReadOnlyPublished;
  final bool isFullLearnPublished;
  final bool learnModulesInPayload;
}

PublishedMonoAccess publishedAccessFromDetail(
  PublishedMonoDetailDto d, {
  bool learnModulesInPayload = false,
}) {
  final k = displayKindFromApi(d.displayPublishKind);
  return PublishedMonoAccess(
    isReadOnlyPublished: k == PublishedDisplayKind.readOnly,
    isFullLearnPublished: k == PublishedDisplayKind.fullLearn,
    learnModulesInPayload: learnModulesInPayload,
  );
}

/// Whether `content.learn` (object) is present and non-empty (best-effort V1 check).
bool publishedContentHasLearnPayload(Object? content) {
  if (content is! Map) return false;
  final learn = content['learn'];
  if (learn is! Map) return false;
  return learn.isNotEmpty;
}
