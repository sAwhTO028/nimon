/// Single source of truth for Nimon API / public-web base URLs (compile-time).
///
/// **API base:** `--dart-define=NIMON_API_BASE_URL=...`
///
/// Default (no dart-define) is LAN dev Nest on the same Wi‑Fi as a physical device.
///
/// **Public web** (share links): `--dart-define=NIMON_PUBLIC_WEB_BASE_URL=...`
/// When unset, share helpers fall back to a non-loopback [apiBaseUrl] (see
/// `share_mono_link.dart` / `share_public_profile_url.dart`).
abstract final class NimonApiConfig {
  NimonApiConfig._();

  static const String _apiBaseUrlEnv = String.fromEnvironment(
    'NIMON_API_BASE_URL',
    defaultValue: 'http://192.168.11.5:3000',
  );

  static const String _publicWebBaseUrlEnv = String.fromEnvironment(
    'NIMON_PUBLIC_WEB_BASE_URL',
    defaultValue: '',
  );

  /// Effective REST API origin (no trailing slash).
  static String get apiBaseUrl => _stripTrailingSlashes(_apiBaseUrlEnv.trim());

  /// Public web origin for `/mono/:id` and similar (no trailing slash).
  static String get publicWebBaseUrl =>
      _stripTrailingSlashes(_publicWebBaseUrlEnv.trim());

  static String _stripTrailingSlashes(String url) {
    return url.replaceAll(RegExp(r'/+$'), '');
  }
}
