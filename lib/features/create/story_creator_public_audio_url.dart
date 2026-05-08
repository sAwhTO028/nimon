/// Shared rules for **reader-visible** story audio URLs (matches Learn M4b3d policy).
bool isPublicHttpAudioSourceUrl(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return false;
  final lower = t.toLowerCase();
  return lower.startsWith('http://') || lower.startsWith('https://');
}

/// `null` when [raw] is acceptable for [StoryCreatorDraftNotifier.setStoryAudio].
String? publicAudioSourceUrlValidationMessage(String raw) {
  if (raw.trim().isEmpty) {
    return 'Enter a valid http(s) audio URL.';
  }
  if (!isPublicHttpAudioSourceUrl(raw)) {
    return 'Enter a valid http(s) audio URL.';
  }
  return null;
}
