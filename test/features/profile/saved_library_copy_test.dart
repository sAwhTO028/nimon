import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/saved_library_copy.dart';

void main() {
  test('Saved tab copy matches M8c1 spec', () {
    expect(
      SavedLibraryCopy.emptyBody,
      'Save stories from Mono to build your reading list.',
    );
    expect(
      SavedLibraryCopy.guestBody,
      'Save stories from Mono to find them here.',
    );
    expect(SavedLibraryCopy.emptyTitle, 'No saved stories yet.');
    expect(SavedLibraryCopy.guestTitle, 'Sign in to see saved stories.');
    expect(
      SavedLibraryCopy.removeFromSavedTooltip,
      'Remove from Saved',
    );
  });
}
