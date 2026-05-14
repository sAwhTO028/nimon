import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/settings/app_locale_resolver.dart';

void main() {
  test('resolveMaterialLocaleFromAppLocaleCode: system -> null', () {
    expect(resolveMaterialLocaleFromAppLocaleCode('system'), isNull);
    expect(resolveMaterialLocaleFromAppLocaleCode(''), isNull);
  });

  test('resolveMaterialLocaleFromAppLocaleCode: en/ja/my', () {
    expect(
      resolveMaterialLocaleFromAppLocaleCode('en'),
      const Locale('en'),
    );
    expect(
      resolveMaterialLocaleFromAppLocaleCode('ja'),
      const Locale('ja'),
    );
    expect(
      resolveMaterialLocaleFromAppLocaleCode('my'),
      const Locale('my'),
    );
  });
}
