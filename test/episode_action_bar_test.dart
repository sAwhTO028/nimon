import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/models/episode_meta.dart';
import 'package:nimon/ui/widgets/episode_action_bar.dart';

void main() {
  group('EpisodeActionBar Tests', () {
    late EpisodeMeta sampleMeta;

    setUp(() {
      sampleMeta = const EpisodeMeta(
        id: 'test_episode_1',
        title: 'Test Episode Title',
        episodeNo: 'Episode 1',
        authorName: 'Test Author',
        coverUrl: 'https://example.com/cover.jpg',
        jlpt: 'N5',
        likes: 1500,
        readTime: '3 min',
        category: 'Adventure',
        preview: 'This is a test episode preview text.',
      );
    });

    testWidgets('EpisodeActionBar displays all three buttons correctly', (WidgetTester tester) async {
      bool saveCalled = false;
      bool shareCalled = false;
      bool startCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeActionBar(
              onSave: () => saveCalled = true,
              onShare: () => shareCalled = true,
              onStart: () => startCalled = true,
              episodeMeta: sampleMeta,
            ),
          ),
        ),
      );

      // Verify all buttons are present
      expect(find.text('Save for Later'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Start Reading'), findsOneWidget);

      // Verify icons are present
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('Button callbacks work correctly', (WidgetTester tester) async {
      bool saveCalled = false;
      bool shareCalled = false;
      bool startCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeActionBar(
              onSave: () => saveCalled = true,
              onShare: () => shareCalled = true,
              onStart: () => startCalled = true,
              episodeMeta: sampleMeta,
            ),
          ),
        ),
      );

      // Test Save for Later button
      await tester.tap(find.text('Save for Later'));
      await tester.pumpAndSettle();
      expect(saveCalled, isTrue);

      // Test Share button
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(shareCalled, isTrue);

      // Test Start Reading button
      await tester.tap(find.text('Start Reading'));
      await tester.pumpAndSettle();
      expect(startCalled, isTrue);
    });

    testWidgets('Responsive layout - share button has fixed size, others are flexible', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeActionBar(
              onSave: () {},
              onStart: () {},
              episodeMeta: sampleMeta,
            ),
          ),
        ),
      );

      // Find the share button (icon only, fixed size)
      final shareButton = find.ancestor(
        of: find.byIcon(Icons.ios_share_rounded),
        matching: find.byType(SizedBox),
      );

      // Verify share button has fixed size
      final shareButtonWidget = tester.widget<SizedBox>(shareButton);
      expect(shareButtonWidget.width, equals(48.0));
      expect(shareButtonWidget.height, equals(48.0));

      // Verify Save for Later and Start Reading are Expanded widgets
      final saveExpanded = find.ancestor(
        of: find.text('Save for Later'),
        matching: find.byType(Expanded),
      );
      final startExpanded = find.ancestor(
        of: find.text('Start Reading'),
        matching: find.byType(Expanded),
      );

      expect(saveExpanded, findsOneWidget);
      expect(startExpanded, findsOneWidget);

      // Verify Start Reading has flex: 2 (more space)
      final startExpandedWidget = tester.widget<Expanded>(startExpanded);
      expect(startExpandedWidget.flex, equals(2));
    });

    testWidgets('Three button layout works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400, // Set a specific width for testing
              child: EpisodeActionBar(
                onSave: () {},
                onStart: () {},
                episodeMeta: sampleMeta,
              ),
            ),
          ),
        ),
      );

      // Verify all three buttons are present
      expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget); // Share icon
      expect(find.text('Save for Later'), findsOneWidget);
      expect(find.text('Start Reading'), findsOneWidget);

      // Verify the layout structure
      final shareButton = find.byIcon(Icons.ios_share_rounded);
      final saveButton = find.text('Save for Later');
      final startButton = find.text('Start Reading');

      expect(shareButton, findsOneWidget);
      expect(saveButton, findsOneWidget);
      expect(startButton, findsOneWidget);
    });

    testWidgets('Share button is icon-only and compact', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeActionBar(
              onSave: () {},
              onStart: () {},
              episodeMeta: sampleMeta,
            ),
          ),
        ),
      );

      // Find the share button
      final shareButton = find.ancestor(
        of: find.byIcon(Icons.ios_share_rounded),
        matching: find.byType(OutlinedButton),
      );

      expect(shareButton, findsOneWidget);
      
      // Verify it's icon-only (no text)
      expect(find.descendant(
        of: shareButton,
        matching: find.byType(Text),
      ), findsNothing);
      
      // Verify it has the share icon
      expect(find.descendant(
        of: shareButton,
        matching: find.byIcon(Icons.ios_share_rounded),
      ), findsOneWidget);
    });

    testWidgets('Accessibility semantics are correct', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeActionBar(
              onSave: () {},
              onStart: () {},
              episodeMeta: sampleMeta,
            ),
          ),
        ),
      );

      // Check semantic labels
      expect(find.bySemanticsLabel('Save episode for later'), findsOneWidget);
      expect(find.bySemanticsLabel('Share episode'), findsOneWidget);
      expect(find.bySemanticsLabel('Start reading episode'), findsOneWidget);
      expect(find.bySemanticsLabel('Episode actions'), findsOneWidget);
    });

    testWidgets('Loading state disables buttons correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeActionBar(
              onSave: () {},
              onStart: () {},
              episodeMeta: sampleMeta,
              isLoading: true,
            ),
          ),
        ),
      );

      // Find button widgets
      final saveButton = find.ancestor(
        of: find.text('Save for Later'),
        matching: find.byType(OutlinedButton),
      );
      final startButton = find.ancestor(
        of: find.text('Start Reading'),
        matching: find.byType(FilledButton),
      );

      // Verify buttons are disabled when loading
      final saveButtonWidget = tester.widget<OutlinedButton>(saveButton);
      final startButtonWidget = tester.widget<FilledButton>(startButton);

      expect(saveButtonWidget.onPressed, isNull);
      expect(startButtonWidget.onPressed, isNull);
    });

    testWidgets('Built-in sharing works when no onShare callback provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeActionBar(
              onSave: () {},
              onStart: () {},
              episodeMeta: sampleMeta,
              // No onShare callback provided - should use built-in sharing
            ),
          ),
        ),
      );

      // Tap share button - should not throw error
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      // Should show a snackbar with success message
      expect(find.text('Episode link copied to clipboard!'), findsOneWidget);
    });

    testWidgets('Landscape orientation maintains proportions', (WidgetTester tester) async {
      // Set landscape orientation
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeActionBar(
              onSave: () {},
              onStart: () {},
              episodeMeta: sampleMeta,
            ),
          ),
        ),
      );

      // Verify share button still has fixed size in landscape
      final shareButton = find.ancestor(
        of: find.byIcon(Icons.ios_share_rounded),
        matching: find.byType(SizedBox),
      );

      final shareButtonWidget = tester.widget<SizedBox>(shareButton);
      expect(shareButtonWidget.width, equals(48.0));
      expect(shareButtonWidget.height, equals(48.0));

      // Verify Save for Later and Start Reading are still Expanded
      final saveExpanded = find.ancestor(
        of: find.text('Save for Later'),
        matching: find.byType(Expanded),
      );
      final startExpanded = find.ancestor(
        of: find.text('Start Reading'),
        matching: find.byType(Expanded),
      );
      
      expect(saveExpanded, findsOneWidget);
      expect(startExpanded, findsOneWidget);

      // Reset view
      addTearDown(tester.view.reset);
    });
  });
}
