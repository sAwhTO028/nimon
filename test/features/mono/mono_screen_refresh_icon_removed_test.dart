import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mono_screen: For You refresh icon/tooltip removed; search unchanged',
      () {
    final p = File('lib/features/mono/mono_screen.dart').readAsStringSync();
    expect(p.contains("message: 'Refresh feed'"), isFalse);
    expect(p.contains('Icons.refresh_rounded'), isFalse);
    expect(p.contains("message: 'Search Mono'"), isTrue);
    expect(p.contains('Icons.search_rounded'), isTrue);
  });
}
