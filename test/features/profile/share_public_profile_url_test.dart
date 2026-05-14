import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/profile/share_public_profile_url.dart';

void main() {
  group('resolvePublicProfileShareUrl', () {
    test('explicit URL wins', () {
      expect(
        resolvePublicProfileShareUrl(
          explicitUrl: 'https://nimon.app/u/alice',
          userId: 'x',
          handle: 'bob',
        ),
        'https://nimon.app/u/alice',
      );
    });

    test('public web base + handle slug', () {
      expect(
        resolvePublicProfileShareUrl(
          explicitUrl: '',
          userId: null,
          handle: '@alice',
          publicWebBaseFromDefine: 'https://nimon.app',
          apiBaseFromDefine: RemoteBackendConfig.apiBaseUrl,
        ),
        'https://nimon.app/u/alice',
      );
    });

    test('public web base + userId when no handle', () {
      expect(
        resolvePublicProfileShareUrl(
          explicitUrl: '',
          userId: '550e8400-e29b-41d4-a716-446655440000',
          handle: '',
          publicWebBaseFromDefine: 'https://nimon.app',
          apiBaseFromDefine: RemoteBackendConfig.apiBaseUrl,
        ),
        'https://nimon.app/u/550e8400-e29b-41d4-a716-446655440000',
      );
    });

    test('LAN api fallback when public web empty', () {
      expect(
        resolvePublicProfileShareUrl(
          explicitUrl: '',
          userId: null,
          handle: 'bob',
          publicWebBaseFromDefine: '',
          apiBaseFromDefine: 'http://192.168.1.5:3000',
        ),
        'http://192.168.1.5:3000/u/bob',
      );
    });

    test('empty when only loopback api', () {
      expect(
        resolvePublicProfileShareUrl(
          explicitUrl: '',
          userId: null,
          handle: 'bob',
          publicWebBaseFromDefine: '',
          apiBaseFromDefine: 'http://localhost:3000',
        ),
        '',
      );
    });
  });

  group('shortPublicProfileLinkLabel', () {
    test('strips scheme for display', () {
      expect(
        shortPublicProfileLinkLabel('https://nimon.app/u/alice'),
        'nimon.app/u/alice',
      );
    });
  });
}
