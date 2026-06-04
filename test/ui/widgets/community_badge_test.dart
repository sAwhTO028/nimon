import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/ui/widgets/community_badge.dart';

void main() {
  testWidgets('CommunityBadge renders MY EN JA and legacy', (tester) async {
    Future<void> pump(String? locale) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommunityBadge(contentLocale: locale)),
        ),
      );
    }

    await pump('my');
    expect(find.text('MY'), findsOneWidget);

    await pump('en');
    expect(find.text('EN'), findsOneWidget);

    await pump('ja');
    expect(find.text('JA'), findsOneWidget);

    await pump(null);
    expect(find.text('—'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityBadge(contentLocale: null, legacyAsMixed: true),
        ),
      ),
    );
    expect(find.text('MIX'), findsOneWidget);
  });
}
