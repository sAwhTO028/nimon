import 'package:nimon/l10n/nimon_app_strings.dart';

/// English copy for the flat Saved library (M8c1). Single source for tests.
abstract final class SavedLibraryCopy {
  static const guestTitle = 'Sign in to see saved stories.';
  static const guestBody = 'Save stories from Mono to find them here.';

  static const emptyTitle = 'No saved stories yet.';
  static const emptyBody = 'Save stories from Mono to build your reading list.';

  static const removeFromSavedTooltip = 'Remove from Saved';
  static const removeFromSavedCta = 'Remove from Saved';

  static const monoSavedSnack = NimonAppStrings.monoBookmarkSavedSnack;
  static const monoRemovedSnack = NimonAppStrings.monoBookmarkRemovedSnack;
  static const monoGuestSave = NimonAppStrings.signInToSaveStories;
  static const monoSaveError = 'Could not save story.';
}
