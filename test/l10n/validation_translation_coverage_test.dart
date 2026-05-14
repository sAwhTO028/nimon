import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ARB vs English template', () {
    late Map<String, dynamic> en;
    late Map<String, dynamic> ja;
    late Map<String, dynamic> my;

    setUpAll(() {
      final root = Directory.current.path;
      en = jsonDecode(
        File('$root/lib/l10n/app_en.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      ja = jsonDecode(
        File('$root/lib/l10n/app_ja.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      my = jsonDecode(
        File('$root/lib/l10n/app_my.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
    });

    const spotKeys = <String>[
      'validationNetworkOffline',
      'validationProtectedReactLogin',
      'validationAuthEmailRequired',
      'validationPublishSheetTitle',
      'validationMediaImageInvalidType',
    ];

    test('Japanese high-priority strings differ from English', () {
      for (final k in spotKeys) {
        expect(ja[k], isNotNull);
        expect(en[k], isNotNull);
        expect(
          ja[k],
          isNot(en[k]),
          reason: '$k should have non-English Japanese copy',
        );
      }
    });

    test('Myanmar high-priority strings differ from English', () {
      for (final k in spotKeys) {
        expect(my[k], isNotNull);
        expect(en[k], isNotNull);
        expect(
          my[k],
          isNot(en[k]),
          reason: '$k should have non-English Myanmar copy',
        );
      }
    });

    test('placeholder tokens preserved for parameterized keys', () {
      const keysWithPlaceholders = <String>[
        'validationStorySentencesTooFew',
        'validationStoryBodyTooLong',
        'validationLearnCountVocabRange',
      ];
      for (final k in keysWithPlaceholders) {
        final es = en[k] as String;
        final js = ja[k] as String;
        final ms = my[k] as String;
        for (final ph in _placeholdersIn(es)) {
          expect(js.contains('{$ph}'), true, reason: 'ja $k missing {$ph}');
          expect(ms.contains('{$ph}'), true, reason: 'my $k missing {$ph}');
        }
      }
    });
  });
}

Iterable<String> _placeholdersIn(String template) sync* {
  final re = RegExp(r'\{([^}]+)\}');
  for (final m in re.allMatches(template)) {
    yield m.group(1)!;
  }
}
