import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';
import 'package:nimon/features/mono/mono_reader_menu_origin.dart';
import 'package:nimon/ui/bottom_sheets/mono_story_options_sheet.dart';

void main() {
  tearDown(hideMonoStoryOptionsPanel);

  testWidgets(
    'Profile Saved story options: flat remove only when demo folders disabled',
    (tester) async {
      final item = MonoFeedItem(
        id: 'mid-1',
        writerName: 'W',
        writerHandle: '@w',
        level: 'N5',
        contentType: MonoContentType.story,
        bodyText: 'Body',
        storyDescription: 'Desc',
        title: 'T',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) {
                  return ElevatedButton(
                    onPressed: () {
                      showMonoStoryOptionsPanel(
                        ctx,
                        item,
                        readerMenuOrigin: MonoReaderMenuOrigin.profileSaved,
                        demoBookmarkFoldersOverrideForTest: false,
                      );
                    },
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Remove from Saved'), findsOneWidget);
      expect(find.text('Move'), findsNothing);
      expect(find.text('Unsave'), findsNothing);
      expect(
          find.textContaining('collection', findRichText: true), findsNothing);
      expect(find.textContaining('folder', findRichText: true), findsNothing);
    },
  );
}
