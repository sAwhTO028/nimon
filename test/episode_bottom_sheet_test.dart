import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/models/episode_meta.dart';
import 'package:nimon/ui/widgets/sheets/show_episode_modal.dart';

void main() {
  group('M3 Episode Modal Sheet Tests', () {
    late EpisodeMeta sampleMeta;

    setUp(() {
      sampleMeta = const EpisodeMeta(
        id: 'test_episode_7',
        title: 'Sample Story Title',
        episodeNo: 'Episode 7',
        authorName: 'Test Author',
        coverUrl: 'https://example.com/cover.jpg',
        jlpt: 'N5',
        likes: 4200,
        readTime: '5 min',
        category: 'Love',
        preview: 'Rain was falling softly in Kyoto. Aya stood under her umbrella.',
      );
    });

    testWidgets('Premium episode sheet displays correctly with Material 3 design', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showEpisodeModalFromMeta(context, sampleMeta),
                child: const Text('Show Sheet'),
              ),
            ),
          ),
        ),
      );

      // Tap to show bottom sheet
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Verify key elements are present with new premium design
      expect(find.text('Sample Story Title'), findsOneWidget);
      expect(find.text('Episode 7'), findsOneWidget);
      expect(find.text('Test Author'), findsOneWidget);
      expect(find.text('N5'), findsOneWidget);
      expect(find.text('4.2K'), findsOneWidget);
      expect(find.text('5 min'), findsOneWidget);
      expect(find.text('Love'), findsOneWidget);
      expect(find.text('Rain was falling softly in Kyoto. Aya stood under her umbrella.'), findsOneWidget);
      expect(find.text('Save for Later'), findsOneWidget);
      expect(find.text('Start Reading'), findsOneWidget);
    });

    testWidgets('Accessibility semantics are correct', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showEpisodeModalFromMeta(context, sampleMeta),
                child: const Text('Show Sheet'),
              ),
            ),
          ),
        ),
      );

      // Tap to show bottom sheet
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Check semantic labels
      expect(find.bySemanticsLabel('Episode title: Sample Story Title'), findsOneWidget);
      expect(find.bySemanticsLabel('JLPT level N5'), findsOneWidget);
    });

    testWidgets('Buttons respond to taps', (WidgetTester tester) async {
      bool saveLaterCalled = false;
      bool startReadingCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showEpisodeModalFromMeta(
                  context,
                  sampleMeta,
                  onSave: () {
                    saveLaterCalled = true;
                  },
                  onStartReading: () {
                    startReadingCalled = true;
                  },
                ),
                child: const Text('Show Sheet'),
              ),
            ),
          ),
        ),
      );

      // Tap to show bottom sheet
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Test Save for Later button
      await tester.tap(find.text('Save for Later'));
      await tester.pumpAndSettle();
      expect(saveLaterCalled, isTrue);

      // Test Start Reading button
      await tester.tap(find.text('Start Reading'));
      await tester.pumpAndSettle();
      expect(startReadingCalled, isTrue);
    });

    testWidgets('Sheet can be dismissed by swiping down', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showEpisodeModalFromMeta(context, sampleMeta),
                child: const Text('Show Sheet'),
              ),
            ),
          ),
        ),
      );

      // Tap to show bottom sheet
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Verify sheet is visible
      expect(find.text('Sample Story Title'), findsOneWidget);

      // Swipe down to dismiss
      await tester.drag(find.text('Sample Story Title'), const Offset(0, 300));
      await tester.pumpAndSettle();

      // Verify sheet is dismissed
      expect(find.text('Sample Story Title'), findsNothing);
    });
  });
}

