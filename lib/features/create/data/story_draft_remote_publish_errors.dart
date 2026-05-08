import 'dart:convert';

/// Thrown on non-2xx draft HTTP responses so [Exception.toString] is UI-safe
/// (avoids `Bad state:` prefixes from [StateError]).
class StoryDraftHttpResponseException implements Exception {
  const StoryDraftHttpResponseException(this.message);

  final String message;

  @override
  String toString() => message;
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
