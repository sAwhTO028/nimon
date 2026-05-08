import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/creator_profile_location.dart';

void main() {
  test('prefers userId route when present', () {
    final loc = creatorProfileLocation(
      userId: 'u1',
      handle: '@h',
      allowLegacyHandle: true,
    );
    expect(loc, '/profile/public?userId=u1');
  });

  test('legacy handle route only when allowed', () {
    final loc1 = creatorProfileLocation(
      userId: null,
      handle: '@h',
      allowLegacyHandle: true,
    );
    expect(loc1, '/profile/public?creator=%40h');

    final loc2 = creatorProfileLocation(
      userId: null,
      handle: '@h',
      allowLegacyHandle: false,
    );
    expect(loc2, isNull);
  });

  test('returns null when no usable identifier', () {
    final loc = creatorProfileLocation(
      userId: '   ',
      handle: '   ',
      allowLegacyHandle: true,
    );
    expect(loc, isNull);
  });
}
