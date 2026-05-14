// Generates validation ARB entries from validation_fallback_messages.dart.
// Run: dart run tool/emit_validation_arb.dart
//
// ignore_for_file: avoid_print

import 'dart:io';

String arbMethodName(String messageKey) {
  final parts = messageKey.split('.');
  final buf = StringBuffer('validation');
  for (final p in parts) {
    if (p.isEmpty) continue;
    buf.write(p[0].toUpperCase());
    if (p.length > 1) buf.write(p.substring(1));
  }
  return buf.toString();
}

void main() {
  final src = File('lib/core/validation/validation_fallback_messages.dart')
      .readAsStringSync();
  final re = RegExp(r"'([^']+)':\s*'((?:\\'|[^'])*)'", multiLine: true);
  final entries = <String, String>{};
  for (final m in re.allMatches(src)) {
    entries[m.group(1)!] = m.group(2)!;
  }
  // Multiline values: 'key':\n      'line1'
  final reMulti = RegExp(
    r"'([^']+)':\s*\n\s*'((?:\\'|[^'])*)'",
    multiLine: true,
  );
  for (final m in reMulti.allMatches(src)) {
    entries[m.group(1)!] = m.group(2)!;
  }

  final keys = entries.keys.toList()..sort();
  final out = StringBuffer();
  for (final k in keys) {
    final name = arbMethodName(k);
    var text = entries[k]!;
    text = text.replaceAll("'", r"\'");
    // ARB placeholders use single braces; escape $ for Dart would not apply here.
    out.writeln('  "$name": "${text.replaceAll('"', r'\"')}",');
  }
  File('tool/_validation_arb_keys_emit.txt').writeAsStringSync(out.toString());
  print('Wrote ${keys.length} keys to tool/_validation_arb_keys_emit.txt');
}
