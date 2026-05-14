import 'package:flutter/material.dart';

/// M11d: resolves stored appLocale preference to Material locale.
///
/// Codes (V1):
/// - system -> null (follow OS)
/// - en -> Locale('en')
/// - ja -> Locale('ja')
/// - my -> Locale('my')
Locale? resolveMaterialLocaleFromAppLocaleCode(String code) {
  final t = code.trim().toLowerCase();
  return switch (t) {
    'en' => const Locale('en'),
    'ja' => const Locale('ja'),
    'my' => const Locale('my'),
    _ => null,
  };
}
