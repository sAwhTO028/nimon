/// How the folder-aware mono reader ([/mono-reader]) was opened from Profile.
/// Drives the dock story-options panel actions (Saved vs Uploaded).
enum MonoReaderMenuOrigin {
  /// Profile → Uploaded: Delete / Edit in reader menu panel.
  profileUploaded,

  /// Profile → Saved: Unsave / Move in reader menu panel.
  profileSaved,
}
