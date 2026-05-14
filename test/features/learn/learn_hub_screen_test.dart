import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/learn/learn_hub_screen.dart';
import 'package:nimon/l10n/app_localizations.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

Widget _learnApp(Widget home) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: home,
    ),
  );
}

void main() {
  testWidgets('Learn hub shows Description heading and basics text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _learnApp(
        const LearnHubScreen(
          contentId: 'cid',
          description: 'Story Basics description text.',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Story Basics description text.'), findsOneWidget);
    expect(find.text("What's inside"), findsNothing);
  });

  testWidgets('Learn hub hides Description block when empty', (tester) async {
    await tester.pumpWidget(
      _learnApp(const LearnHubScreen(contentId: 'cid')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Description'), findsNothing);
  });

  testWidgets('Learn hub header has no explanation-language icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      _learnApp(
        const LearnHubScreen(
          contentId: 'cid',
          storyTitle: 'Shown Title',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Learn'), findsOneWidget);
    expect(find.byType(NimonCircleNavButton), findsOneWidget);
    expect(find.byIcon(Icons.translate_outlined), findsNothing);
    expect(find.byTooltip('Explanation language'), findsNothing);
  });

  testWidgets('Learn hub shows Manual / Creator-made (not download/offline)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _learnApp(const LearnHubScreen(contentId: 'cid')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Manual'), findsOneWidget);
    expect(find.text('Creator-made'), findsOneWidget);
    expect(find.text('Download'), findsNothing);
    expect(find.text('Use offline'), findsNothing);
  });
}
