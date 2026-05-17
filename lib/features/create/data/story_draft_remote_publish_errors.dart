import 'dart:convert';

import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/features/create/story_v1_model.dart';

/// Shown when publish hits a stale `If-Match` / version conflict (HTTP 409).
const String kStoryDraftPublishConflictMessage =
    'Draft changed. Please review and publish again.';

/// Nest `409` `conflict` on draft publish/save with [currentEtag] in details.
class StoryDraftPublishConflictException implements Exception {
  StoryDraftPublishConflictException({
    required this.draftId,
    this.currentEtag,
    this.refreshedDraft,
  });

  final String draftId;
  final String? currentEtag;

  /// Latest server draft after conflict (when reload succeeded).
  final CreatorStoryV1? refreshedDraft;

  String get message => kStoryDraftPublishConflictMessage;

  @override
  String toString() => message;
}

/// True for Nest draft version conflicts (`error.code == conflict`, optional etag).
bool isDraftVersionConflictResponse({
  required int statusCode,
  required String body,
}) {
  if (statusCode != 409) return false;
  final trimmed = body.trim();
  if (trimmed.isEmpty) return false;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) return false;
    final err = decoded['error'];
    if (err is! Map) return false;
    if (err['code'] != 'conflict') return false;
    final msg = (err['message'] as String?) ?? '';
    if (!msg.toLowerCase().contains('draft was modified')) {
      // Still treat conflict + currentEtag as version mismatch.
      final details = err['details'];
      if (details is! Map) return false;
      final tag = details['currentEtag'];
      return tag is String && tag.trim().isNotEmpty;
    }
    final details = err['details'];
    if (details is Map) {
      final tag = details['currentEtag'];
      return tag is String && tag.trim().isNotEmpty;
    }
    return true;
  } catch (_) {
    return false;
  }
}

String? draftVersionConflictCurrentEtagFromBody(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return null;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) return null;
    final err = decoded['error'];
    if (err is! Map || err['code'] != 'conflict') return null;
    final details = err['details'];
    if (details is! Map) return null;
    final tag = details['currentEtag'];
    if (tag is String && tag.trim().isNotEmpty) return tag.trim();
  } catch (_) {
    return null;
  }
  return null;
}

/// Thrown on non-2xx draft HTTP responses so [Exception.toString] is UI-safe
/// (avoids `Bad state:` prefixes from [StateError]).
class StoryDraftHttpResponseException implements Exception {
  const StoryDraftHttpResponseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Backend publish gate (`400` + `validation_failed`) with structured issues.
class StoryDraftValidationFailedException implements Exception {
  StoryDraftValidationFailedException(this.issues);

  final List<ValidationIssue> issues;

  @override
  String toString() =>
      'StoryDraftValidationFailedException(${issues.length} issues)';
}

/// User-facing copy when the backend rejects Full Learn because no PublishedMono exists yet.
const String kPublishFullLearnRequiresReadOnlyFirst =
    'We need to publish the reading version first, then publish Full Learn.';

/// Detects Nest `422` bodies where `error.details.unmet` includes `published_mono_missing`.
String? publishedMonoMissingFriendlyMessageIfAny({
  required int statusCode,
  required String body,
}) {
  if (statusCode != 422) return null;
  final trimmed = body.trim();
  if (trimmed.isEmpty) return null;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) return null;
    final err = decoded['error'];
    if (err is! Map) return null;
    final details = err['details'];
    if (details is! Map) return null;
    final unmet = details['unmet'];
    if (unmet is! List) return null;
    for (final item in unmet) {
      if (item == 'published_mono_missing') {
        return kPublishFullLearnRequiresReadOnlyFirst;
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}
