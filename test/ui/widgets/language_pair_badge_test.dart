import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/ui/widgets/language_pair_badge.dart';

void main() {
  testWidgets('LanguagePairBadge renders EN · MY', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LanguagePairBadge(
            learningLanguage: 'en',
            contentLocale: 'my',
          ),
        ),
      ),
    );
    expect(find.text('EN · MY'), findsOneWidget);
  });

  testWidgets('LanguagePairBadge renders JA · EN', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LanguagePairBadge(
            learningLanguage: 'ja',
            contentLocale: 'en',
          ),
        ),
      ),
    );
    expect(find.text('JA · EN'), findsOneWidget);
  });

  testWidgets('LanguagePairBadge null legacy renders —', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LanguagePairBadge(),
        ),
      ),
    );
    expect(find.text('—'), findsOneWidget);
  });
}
