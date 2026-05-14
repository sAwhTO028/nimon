import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/learn/learn_hub_screen.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

void main() {
  testWidgets('Learn hub shows Description heading and basics text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LearnHubScreen(
            contentId: 'cid',
            description: 'Story Basics description text.',
          ),
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
      const ProviderScope(
        child: MaterialApp(
          home: LearnHubScreen(contentId: 'cid'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Description'), findsNothing);
  });

  testWidgets('Learn hub header has no explanation-language icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LearnHubScreen(
            contentId: 'cid',
            storyTitle: 'Shown Title',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Learn'), findsOneWidget);
    expect(find.byType(NimonCircleNavButton), findsOneWidget);
    expect(find.byIcon(Icons.translate_outlined), findsNothing);
    expect(find.byTooltip('Explanation language'), findsNothing);
  });
}
