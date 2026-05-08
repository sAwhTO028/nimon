/// How the folder-aware mono reader ([/mono-reader]) was opened from Profile / learner flows.
/// Drives the dock story-options panel actions (Saved vs Uploaded vs hide entirely).
enum MonoReaderMenuOrigin {
  /// Profile → Uploaded: Delete / Edit in reader menu panel.
  profileUploaded,

  /// Profile → Saved: Unsave / Move in reader menu panel.
  profileSaved,

  /// Public creator profile (or other learner discovery): no owner/edit/delete menu on the dock.
  publicCreatorProfile,
}
