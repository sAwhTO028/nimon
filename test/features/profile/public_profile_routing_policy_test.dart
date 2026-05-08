import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/public_profile_routing_policy.dart';

void main() {
  group('legacyDemoCreatorProfileActive', () {
    test('true when creator handle present, no userId, debug mode', () {
      expect(
        legacyDemoCreatorProfileActive(
          userId: null,
          creatorHandle: '@demo',
          isDebugMode: true,
        ),
        isTrue,
      );
    });

    test('false outside debug even with creator handle', () {
      expect(
        legacyDemoCreatorProfileActive(
          userId: null,
          creatorHandle: '@demo',
          isDebugMode: false,
        ),
        isFalse,
      );
    });

    test('false when userId is present', () {
      expect(
        legacyDemoCreatorProfileActive(
          userId: '550e8400-e29b-41d4-a716-446655440000',
          creatorHandle: '@demo',
          isDebugMode: true,
        ),
        isFalse,
      );
    });
  });

  group('creatorHandleOnlyRouteRejectedOutsideDebug', () {
    test('true in release-style mode for creator-only route', () {
      expect(
        creatorHandleOnlyRouteRejectedOutsideDebug(
          userId: null,
          creatorHandle: '@demo',
          isDebugMode: false,
        ),
        isTrue,
      );
    });

    test('false in debug for creator-only route', () {
      expect(
        creatorHandleOnlyRouteRejectedOutsideDebug(
          userId: null,
          creatorHandle: '@demo',
          isDebugMode: true,
        ),
        isFalse,
      );
    });

    test('false when userId present', () {
      expect(
        creatorHandleOnlyRouteRejectedOutsideDebug(
          userId: ' uid ',
          creatorHandle: '@demo',
          isDebugMode: false,
        ),
        isFalse,
      );
    });
  });
}
