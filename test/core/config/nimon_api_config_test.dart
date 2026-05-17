import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/config/nimon_api_config.dart';

void main() {
  test('default apiBaseUrl without dart-defines is LAN Nest', () {
    expect(NimonApiConfig.apiBaseUrl, 'http://192.168.11.5:3000');
  });

  test('publicWebBaseUrl is empty when NIMON_PUBLIC_WEB_BASE_URL unset', () {
    expect(NimonApiConfig.publicWebBaseUrl, '');
  });

  /// Proves `--dart-define=NIMON_API_BASE_URL=...` is compiled into [NimonApiConfig].
  ///
  /// Full suite: skipped. Run locally or in a targeted job:
  ///
  /// `flutter test test/core/config/nimon_api_config_test.dart --dart-define=VERIFY_NIMON_API_DEFINE=true --dart-define=NIMON_API_BASE_URL=https://nimon-api-global-test.onrender.com`
  test(
    'NIMON_API_BASE_URL dart-define overrides default LAN base',
    () {
      expect(
        NimonApiConfig.apiBaseUrl,
        'https://nimon-api-global-test.onrender.com',
      );
    },
    skip: const bool.fromEnvironment('VERIFY_NIMON_API_DEFINE',
            defaultValue: false)
        ? false
        : 'Pass --dart-define=VERIFY_NIMON_API_DEFINE=true together with '
            '--dart-define=NIMON_API_BASE_URL=... to enable this assertion.',
  );
}
