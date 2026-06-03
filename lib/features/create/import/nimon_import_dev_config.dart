import 'package:flutter/foundation.dart' show kDebugMode;

/// Whether the hidden JSON import UI is available.
///
/// Enabled in debug builds, or when compiled with:
/// `--dart-define=NIMON_DEV_JSON_IMPORT=true`
abstract final class NimonImportDevConfig {
  NimonImportDevConfig._();

  static const bool devJsonImportFromEnvironment = bool.fromEnvironment(
    'NIMON_DEV_JSON_IMPORT',
    defaultValue: false,
  );

  static bool get jsonImportUiEnabled =>
      kDebugMode || devJsonImportFromEnvironment;
}
