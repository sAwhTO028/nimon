// Copies **missing** keys from app_en.arb into app_ja.arb / app_my.arb using English text.
//
// Safety: existing keys in the target file are **never** overwritten. Manual translations
// are preserved. Run after adding new keys to the template only.
//
// Optional: `dart run tool/mirror_arb_locales.dart --dry-run` lists keys that would be
// added without writing files.
//
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

void mergeInto(
  String templatePath,
  String targetPath,
  String localeCode, {
  required bool dryRun,
}) {
  final template =
      jsonDecode(File(templatePath).readAsStringSync()) as Map<String, dynamic>;
  final existing =
      jsonDecode(File(targetPath).readAsStringSync()) as Map<String, dynamic>;

  final wouldAdd = <String>[];
  var added = 0;

  if (!dryRun) {
    for (final e in template.entries) {
      final k = e.key;
      if (k.startsWith('@@')) continue;
      if (existing.containsKey(k)) continue;
      existing[k] = e.value;
      added++;
      final metaKey = '@$k';
      if (template.containsKey(metaKey)) {
        existing[metaKey] = template[metaKey];
      }
    }
    existing['@@locale'] = localeCode;
    File(targetPath).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(existing)}\n',
    );
  } else {
    for (final e in template.entries) {
      final k = e.key;
      if (k.startsWith('@@')) continue;
      if (!existing.containsKey(k)) {
        wouldAdd.add(k);
      }
    }
  }

  if (dryRun) {
    print('[dry-run] $targetPath: would add ${wouldAdd.length} keys');
    for (final k in wouldAdd.take(40)) {
      print('  + $k');
    }
    if (wouldAdd.length > 40) {
      print('  ... and ${wouldAdd.length - 40} more');
    }
  } else {
    print('$targetPath: added $added keys');
  }
}

void main(List<String> args) {
  final dryRun = args.contains('--dry-run');
  mergeInto('lib/l10n/app_en.arb', 'lib/l10n/app_ja.arb', 'ja', dryRun: dryRun);
  mergeInto('lib/l10n/app_en.arb', 'lib/l10n/app_my.arb', 'my', dryRun: dryRun);
}
