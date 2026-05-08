/// English user-facing strings for share + core Mono/social gates (M8e).
///
/// The app already ships [flutter_localizations] + `intl` and supports `en` / `ja`
/// locales in [MaterialApp], but there is **no** ARB / codegen layer yet. This class
/// is the single source of truth for the strings below until a full i18n pass adds
/// translated ARBs and delegates.
abstract final class NimonAppStrings {
  // --- Share (clipboard path; see M8e report for share_plus decision) ---
  static const shareLinkCopied = 'Link copied.';
  static const shareLinkUnavailable = 'Share link is not available yet.';

  // --- Mono / profile social gates & bookmark feedback ---
  static const signInToSaveStories = 'Sign in to save stories.';
  static const signInToReact = 'Sign in to react.';
  static const signInToFollowCreators = 'Sign in to follow creators.';

  static const monoBookmarkSavedSnack = 'Saved.';
  static const monoBookmarkRemovedSnack = 'Removed from Saved.';
}
