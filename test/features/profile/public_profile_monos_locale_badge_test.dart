import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';
import 'package:nimon/features/mono/mono_content_model.dart';
import 'package:nimon/features/profile/mono_story_list_row.dart';
import 'package:nimon/ui/widgets/language_pair_badge.dart';

void main() {
  testWidgets('public profile monos row shows dual language badge', (tester) async {
    const item = MonoFeedItem(
      id: 'm1',
      writerName: 'W',
      writerHandle: '@w',
      level: 'N5',
      contentType: MonoContentType.article,
      bodyText: 'body',
      contentLocale: 'my',
      learningLanguage: 'ja',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonoStoryListRow(
            title: 'Story',
            description: 'Desc',
            jlptLevel: item.level,
            badgeMode: MonoStoryListBadgeMode.languagePair,
            contentLocale: item.contentLocale,
            learningLanguage: item.learningLanguage,
          ),
        ),
      ),
    );

    expect(find.byType(LanguagePairBadge), findsOneWidget);
    expect(find.text('JA · MY'), findsOneWidget);
  });
}
