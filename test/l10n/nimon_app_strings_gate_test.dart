import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/saved_library_copy.dart';
import 'package:nimon/l10n/nimon_app_strings.dart';

void main() {
  test('bookmark/snack copy aliases NimonAppStrings', () {
    expect(SavedLibraryCopy.monoGuestSave, NimonAppStrings.signInToSaveStories);
    expect(SavedLibraryCopy.monoSavedSnack,
        NimonAppStrings.monoBookmarkSavedSnack);
    expect(
      SavedLibraryCopy.monoRemovedSnack,
      NimonAppStrings.monoBookmarkRemovedSnack,
    );
  });

  test('M8e gate strings are non-empty English literals', () {
    expect(NimonAppStrings.shareLinkCopied, isNotEmpty);
    expect(NimonAppStrings.shareLinkUnavailable, isNotEmpty);
    expect(NimonAppStrings.signInToSaveStories, contains('Sign in'));
    expect(NimonAppStrings.signInToReact, contains('react'));
    expect(NimonAppStrings.signInToFollowCreators, contains('follow'));
  });
}
