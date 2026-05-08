/// Helpers for validating IDs before calling creator-collections APIs.
///
/// Creator collections APIs accept **PublishedMono.id** UUIDv4 strings.
abstract final class PublishedMonoIdSanitizer {
  PublishedMonoIdSanitizer._();

  static final RegExp _uuidV4 = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  /// Returns a stable, deduped list of UUIDv4 ids.
  static List<String> sanitize(List<String> raw) {
    final out = <String>[];
    final seen = <String>{};
    for (final x in raw) {
      final t = x.trim();
      if (t.isEmpty) continue;
      if (!_uuidV4.hasMatch(t)) continue;
      if (seen.add(t)) out.add(t);
    }
    return out;
  }
}
