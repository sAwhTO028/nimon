import 'package:nimon/core/format_social_count.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';

/// Likes / react count for mono story options sheet (M17J).
String monoDetailSheetLikesValue(MonoFeedItem item) =>
    formatSocialCount(item.likesCount);

/// Read-duration label from server; [MonoFeedItem.readDurationLabel].
String monoDetailSheetReadTimeValue(MonoFeedItem item) {
  final t = item.readDurationLabel?.trim();
  if (t != null && t.isNotEmpty) return t;
  return '—';
}

/// Story Basics category from server; [MonoFeedItem.catalogCategory].
String monoDetailSheetCategoryValue(MonoFeedItem item) {
  final c = item.catalogCategory?.trim();
  if (c != null && c.isNotEmpty) return c;
  return '—';
}
