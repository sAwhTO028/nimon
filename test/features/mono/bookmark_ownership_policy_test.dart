import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/mono/bookmark_ownership_policy.dart';

void main() {
  test('canBookmarkMono returns false for own content', () {
    expect(
      canBookmarkMono(currentUserId: 'u1', monoOwnerId: 'u1'),
      isFalse,
    );
  });

  test('canBookmarkMono returns true for other user content', () {
    expect(
      canBookmarkMono(currentUserId: 'u1', monoOwnerId: 'u2'),
      isTrue,
    );
  });

  test('canBookmarkMono returns true when current user unknown', () {
    expect(
      canBookmarkMono(currentUserId: null, monoOwnerId: 'u1'),
      isTrue,
    );
  });
}
