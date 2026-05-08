/// Resolves the cover URL stored on the draft: only **remote** http(s) values.
///
/// Local filesystem paths are never returned (they must not be persisted as
/// [StoryBasics.coverImageUrl]).
String? storyBasicsRemoteCoverUrl({
  required String? coverLocalPath,
  required String? coverNetworkUrl,
}) {
  final p = coverLocalPath?.trim();
  if (p != null && p.isNotEmpty) {
    if (p.startsWith('http://') || p.startsWith('https://')) {
      return p;
    }
    return null;
  }
  final n = coverNetworkUrl?.trim();
  if (n != null &&
      n.isNotEmpty &&
      (n.startsWith('http://') || n.startsWith('https://'))) {
    return n;
  }
  return null;
}

/// Resolves [StoryBasics.coverImageUrl] for debounced autosave: keeps persisted URL
/// unless the user replaced it with a new remote URL or explicitly cleared cover.
String? storyBasicsPersistedCoverUrl({
  required bool coverExplicitlyCleared,
  required String? coverLocalPath,
  required String? coverNetworkUrl,
  required String? draftCoverImageUrl,
}) {
  if (coverExplicitlyCleared) {
    return null;
  }
  final remote = storyBasicsRemoteCoverUrl(
    coverLocalPath: coverLocalPath,
    coverNetworkUrl: coverNetworkUrl,
  );
  if (remote != null && remote.isNotEmpty) {
    return remote;
  }
  final d = draftCoverImageUrl?.trim();
  if (d != null && d.isNotEmpty) {
    return d;
  }
  return null;
}
