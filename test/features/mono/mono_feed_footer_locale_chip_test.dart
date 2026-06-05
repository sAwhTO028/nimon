import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/mono/widgets/mono_feed_footer_locale_chips.dart';
import 'package:nimon/ui/widgets/language_pair_badge.dart';

void main() {
  testWidgets('MonoFeedFooterLocaleChip shows EN · MY on feed footer', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MonoFeedFooterLocaleChip(
            learningLanguage: 'en',
            contentLocale: 'my',
          ),
        ),
      ),
    );
    expect(find.byType(LanguagePairBadge), findsOneWidget);
    expect(find.text('EN · MY'), findsOneWidget);
  });

  testWidgets('MonoFeedFooterLocaleChip hidden when both locale dimensions legacy',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MonoFeedFooterLocaleChip(),
        ),
      ),
    );
    expect(find.byType(LanguagePairBadge), findsNothing);
  });
}
