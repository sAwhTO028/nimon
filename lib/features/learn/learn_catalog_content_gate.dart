import 'package:flutter/foundation.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';

/// Strips [kProfilePublishedMonoFeedItemIdPrefix] so Learn route ids match Postgres UUIDs.
String normalizeCatalogMonoIdForUuidCheck(String contentId) {
  var t = contentId.trim();
  if (t.startsWith(kProfilePublishedMonoFeedItemIdPrefix)) {
    t = t.substring(kProfilePublishedMonoFeedItemIdPrefix.length).trim();
  }
  return t;
}

/// Public Mono catalog rows use UUID ids from Postgres.
bool catalogMonoIdLooksLikeUuid(String contentId) {
  final t = normalizeCatalogMonoIdForUuidCheck(contentId);
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(t);
}

/// **Dev-only:** allow legacy mock vocabulary/grammar when [contentId] is not a catalog UUID
/// (e.g. route default `mono`). Never enabled in release builds.
bool learnDemoMocksAllowed(String contentId) {
  if (!kDebugMode) return false;
  final t = contentId.trim();
  if (t.isEmpty || t == 'mono') return true;
  return !catalogMonoIdLooksLikeUuid(t);
}
