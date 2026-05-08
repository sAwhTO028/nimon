import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nimon/features/create/create_story_basics_form.dart';
import 'package:nimon/features/create/data/media_upload_repository.dart';
import 'package:nimon/features/create/story_basics_cover_upload_outcome.dart';
import 'package:nimon/features/create/story_creator_models.dart';

Future<StoryBasicsCoverUploadOutcome> _noopUpload(XFile file) async =>
    StoryBasicsCoverUploadOutcome.ok(
      const MediaUploadResponse(
        url: 'https://example.com/cover.jpg',
        mediaType: 'image/jpeg',
        originalName: 'c.jpg',
        sizeBytes: 10,
      ),
    );

void main() {
  group('CreateStoryBasicsForm cover UX', () {
    testWidgets('empty state shows Choose cover image and supported formats',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateStoryBasicsForm(
              initialDraft: null,
              onCoverUpload: _noopUpload,
              coverUploadAllowed: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Upload a cover image'), findsOneWidget);
      expect(find.text('Supported: JPG, PNG, WebP'), findsOneWidget);
      expect(find.text('Choose cover image'), findsOneWidget);
    });

    testWidgets('signed-out shows sign-in copy and disabled Choose cover image',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateStoryBasicsForm(
              initialDraft: null,
              onCoverUpload: _noopUpload,
              coverUploadAllowed: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Sign in to upload cover images.'),
        findsOneWidget,
      );
      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Choose cover image'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('remote cover shows Saved online', (tester) async {
      final empty = CreatorStoryV1.empty();
      final draft = empty.copyWith(
        basics: empty.basics.copyWith(
          coverImageUrl: 'https://cdn.example.com/story-cover.jpg',
          replaceCoverImage: true,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateStoryBasicsForm(
              initialDraft: draft,
              onCoverUpload: _noopUpload,
              coverUploadAllowed: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved online'), findsOneWidget);
      expect(find.text('Replace cover'), findsOneWidget);
    });
  });
}
