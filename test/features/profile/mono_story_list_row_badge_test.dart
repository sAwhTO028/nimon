import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/mono_story_list_row.dart';
import 'package:nimon/ui/widgets/community_badge.dart';
import 'package:nimon/ui/widgets/language_pair_badge.dart';

void main() {
  testWidgets('MonoStoryListRow languagePair mode shows dual badge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MonoStoryListRow(
            title: 'Title',
            description: 'Desc',
            jlptLevel: 'N5',
            badgeMode: MonoStoryListBadgeMode.languagePair,
            learningLanguage: 'en',
            contentLocale: 'my',
          ),
        ),
      ),
    );
    expect(find.byType(LanguagePairBadge), findsOneWidget);
    expect(find.text('EN · MY'), findsOneWidget);
    expect(find.byType(CommunityBadge), findsNothing);
  });

  testWidgets('MonoStoryListRow community mode keeps CommunityBadge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MonoStoryListRow(
            title: 'Title',
            description: 'Desc',
            jlptLevel: 'N5',
            showCommunityBadge: true,
            contentLocale: 'my',
          ),
        ),
      ),
    );
    expect(find.byType(CommunityBadge), findsOneWidget);
    expect(find.text('MY'), findsOneWidget);
    expect(find.byType(LanguagePairBadge), findsNothing);
  });
}
