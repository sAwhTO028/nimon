import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/mono/saved_only_ux_policy.dart';

void main() {
  group('savedOnlyUxDemoFoldersEnabled', () {
    test('off when remote Mono feed is on (debug)', () {
      expect(
        savedOnlyUxDemoFoldersEnabled(
          isDebugMode: true,
          useRemoteMonoFeed: true,
          useRemoteDrafts: false,
        ),
        isFalse,
      );
    });

    test('off when remote drafts is on (debug)', () {
      expect(
        savedOnlyUxDemoFoldersEnabled(
          isDebugMode: true,
          useRemoteMonoFeed: false,
          useRemoteDrafts: true,
        ),
        isFalse,
      );
    });

    test('off in release even without remote flags', () {
      expect(
        savedOnlyUxDemoFoldersEnabled(
          isDebugMode: false,
          useRemoteMonoFeed: false,
          useRemoteDrafts: false,
        ),
        isFalse,
      );
    });

    test('on only in debug with both remote flags off', () {
      expect(
        savedOnlyUxDemoFoldersEnabled(
          isDebugMode: true,
          useRemoteMonoFeed: false,
          useRemoteDrafts: false,
        ),
        isTrue,
      );
    });
  });
}
