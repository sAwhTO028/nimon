import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/creator_audio_upload_sheet.dart';
import 'package:nimon/features/create/data/media_upload_repository.dart';

void main() {
  group('CreatorAudioUploadSheet', () {
    testWidgets('pick phase shows Upload story audio and Choose audio file', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreatorAudioUploadSheet(
              sheetTitle: 'Upload story audio',
              canUpload: true,
              initialPublicSourceUrl: '',
              initialDisplayName: '',
              initialDurationSeconds: null,
              existingFileLabel: '',
              uploadAudio: (_) async => null,
            ),
          ),
        ),
      );

      expect(find.text('Upload story audio'), findsOneWidget);
      expect(find.text('Choose an audio file for this story.'), findsOneWidget);
      expect(find.text('Supported: mp3, m4a, wav'), findsOneWidget);
      expect(
        find.text('Choose a file first. After upload, add it to your story.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Choose audio file'),
          findsOneWidget);
      expect(find.text('Public audio URL'), findsNothing);
      expect(find.text('Attach without uploading'), findsNothing);
      expect(find.text('Optional details'), findsNothing);
      expect(find.text('Advanced options'), findsNothing);
    });

    testWidgets(
        'release sheet hides URL and attach; advanced flag shows collapsed sections',
        (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreatorAudioUploadSheet(
              sheetTitle: 'Upload story audio',
              canUpload: true,
              initialPublicSourceUrl: '',
              initialDisplayName: '',
              initialDurationSeconds: null,
              existingFileLabel: '',
              uploadAudio: (_) async => null,
              showAdvancedOptions: true,
            ),
          ),
        ),
      );

      expect(find.text('Advanced options'), findsOneWidget);
      expect(find.text('Save public URL'), findsNothing);
      await tester.tap(find.text('Advanced options'));
      await tester.pumpAndSettle();
      expect(find.text('Public audio URL'), findsOneWidget);
      expect(find.text('Save public URL'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Attach without uploading'),
        findsOneWidget,
      );
    });

    testWidgets('signed-out shows friendly copy and disabled Choose audio file',
        (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreatorAudioUploadSheet(
              sheetTitle: 'Upload story audio',
              canUpload: false,
              initialPublicSourceUrl: '',
              initialDisplayName: '',
              initialDurationSeconds: null,
              existingFileLabel: '',
              uploadAudio: (_) async => null,
            ),
          ),
        ),
      );

      expect(find.text('Sign in to upload audio.'), findsOneWidget);
      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Choose audio file'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets(
        'success state shows Add audio to story, Replace audio, Remove audio', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreatorAudioUploadSheet(
              sheetTitle: 'Upload story audio',
              canUpload: true,
              initialPublicSourceUrl: '',
              initialDisplayName: '',
              initialDurationSeconds: null,
              existingFileLabel: '',
              uploadAudio: (_) async => null,
              debugSuccessResponse: const MediaUploadResponse(
                url: 'https://cdn.example.com/x.mp3',
                mediaType: 'audio/mpeg',
                originalName: 'story.mp3',
                sizeBytes: 2048,
                durationSeconds: 12,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Upload complete'), findsOneWidget);
      expect(find.text('Replace audio'), findsOneWidget);
      expect(find.text('Remove audio'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Add audio to story'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Tap Add audio to story to attach this file to your draft.',
        ),
        findsOneWidget,
      );
      expect(find.text('story.mp3'), findsOneWidget);
    });
  });
}
