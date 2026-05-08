import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';
import 'package:nimon/features/mono/mono_reader_menu_origin.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';
import 'package:nimon/features/profile/data/remote_published_mono_repository.dart';
import 'package:nimon/features/profile/presentation/providers/profile_published_mono_pager.dart';
import 'package:nimon/ui/bottom_sheets/mono_story_options_sheet.dart';

const _catalogMonoUuid = '11111111-1111-1111-1111-111111111111';

class _RecordingTrashRepo extends RemotePublishedMonoRepository {
  _RecordingTrashRepo()
      : super(
          apiBaseUrl: 'http://stub.test',
          client: MockClient((_) async => http.Response('{"items":[]}', 200)),
        );

  final List<String> trashedIds = <String>[];

  @override
  Future<PublishedMonoTrashMutationResult> trashPublishedMono(String id) async {
    trashedIds.add(id);
    return PublishedMonoTrashMutationResult(
      id: id,
      trashedAt: '2026-05-05T01:02:03.000Z',
    );
  }

  @override
  Future<PageResult<PublishedMonoListItemDto>> fetchPage(
      PageRequest request) async {
    return PageResult<PublishedMonoListItemDto>.empty();
  }
}

void main() {
  tearDown(hideMonoStoryOptionsPanel);

  testWidgets('Move to Trash dialog closes sheet and Cancel reopens it',
      (tester) async {
    final item = MonoFeedItem(
      id: _catalogMonoUuid,
      writerName: 'W',
      writerHandle: '@w',
      level: 'N5',
      contentType: MonoContentType.story,
      bodyText: 'Body sentence',
      storyDescription: 'Basics description',
      title: 'T',
      catalogMonoId: null,
      sourceDraftId: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remotePublishedMonoRepositoryForProfileProvider.overrideWith((ref) {
            return RemotePublishedMonoRepository(
              apiBaseUrl: 'http://stub.test',
              client:
                  MockClient((_) async => http.Response('{"items":[]}', 200)),
            );
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    showMonoStoryOptionsPanel(
                      ctx,
                      item,
                      readerMenuOrigin: MonoReaderMenuOrigin.profileUploaded,
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

    expect(find.text('Move to Trash'), findsOneWidget);
    expect(find.text('Basics description'), findsOneWidget);

    // Tap: sheet closes, dialog appears above the page.
    await tester.tap(find.byKey(const ValueKey('movePublishedMonoToTrash')));
    await tester.pumpAndSettle();
    expect(find.text('Move to Trash?'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('movePublishedMonoToTrash')), findsNothing);

    // Cancel: dialog closes, original sheet returns.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Move to Trash?'), findsNothing);
    expect(
        find.byKey(const ValueKey('movePublishedMonoToTrash')), findsOneWidget);
  });

  testWidgets(
      'Confirm Move to Trash calls repository and does not reopen sheet',
      (tester) async {
    final recorder = _RecordingTrashRepo();
    final item = MonoFeedItem(
      id: _catalogMonoUuid,
      writerName: 'W',
      writerHandle: '@w',
      level: 'N5',
      contentType: MonoContentType.story,
      bodyText: 'Body',
      storyDescription: 'Basics description',
      title: 'T',
      catalogMonoId: null,
      sourceDraftId: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remotePublishedMonoRepositoryForProfileProvider.overrideWithValue(
            recorder,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    showMonoStoryOptionsPanel(
                      ctx,
                      item,
                      readerMenuOrigin: MonoReaderMenuOrigin.profileUploaded,
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
    await tester.tap(find.byKey(const ValueKey('movePublishedMonoToTrash')));
    await tester.pumpAndSettle();
    expect(find.text('Move to Trash?'), findsOneWidget);
    await tester
        .tap(find.byKey(const ValueKey('confirmMovePublishedMonoToTrash')));
    await tester.pumpAndSettle();

    expect(recorder.trashedIds, [_catalogMonoUuid]);
    // Sheet should remain closed after confirm.
    expect(
        find.byKey(const ValueKey('movePublishedMonoToTrash')), findsNothing);
  });
}
