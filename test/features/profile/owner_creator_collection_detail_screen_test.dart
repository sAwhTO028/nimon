import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/features/profile/data/creator_mono_collection.dart';
import 'package:nimon/features/profile/data/remote_creator_collections_repository.dart';
import 'package:nimon/features/profile/mono_story_list_row.dart';
import 'package:nimon/features/profile/owner_creator_collection_detail_screen.dart';
import 'package:nimon/features/profile/presentation/providers/my_creator_collections_notifier.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

void main() {
  testWidgets('Owner collection detail uses MonoStoryListRow + standard back',
      (tester) async {
    http.Request? removeReq;
    final repo = RemoteCreatorCollectionsRepository(
      apiBaseUrl: 'http://stub.test',
      authHeaderBuilder: () async => <String, String>{},
      client: MockClient((req) async {
        if (req.method == 'GET' &&
            req.url.path.endsWith('/v1/me/creator-collections/col-1/monos')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': '00000000-0000-4000-8000-000000000001',
                  'ownerId': 'ooo',
                  'sourceDraftId': null,
                  'title': 'Mono T',
                  'category': 'Cat',
                  'level': 'N3',
                  'description': 'Desc',
                  'publishKind': 'read_only_v1',
                  'displayPublishKind': 'read_only',
                  'coverImageUrl': 'https://img.test/x.png',
                  'targetDurationLabel': null,
                  'createdAt': '2026-01-01T00:00:00.000Z',
                  'updatedAt': '2026-01-02T00:00:00.000Z',
                  'contentSummary': {},
                }
              ],
              'nextCursor': null,
              'hasMore': false,
            }),
            200,
          );
        }
        if (req.method == 'DELETE' &&
            req.url.path.endsWith(
              '/v1/me/creator-collections/col-1/items/00000000-0000-4000-8000-000000000001',
            )) {
          removeReq = req;
          return http.Response('', 204);
        }
        return http.Response('not found', 404);
      }),
    );

    final coll = CreatorMonoCollection(
      id: 'col-1',
      ownerId: 'ooo',
      title: 'My Pack',
      description: 'About',
      coverImageUrl: null,
      visibility: 'public',
      itemCount: 1,
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-02T00:00:00.000Z',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteCreatorCollectionsRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: OwnerCreatorCollectionDetailScreen(
            args: OwnerCreatorCollectionDetailArgs(collection: coll),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NimonBackButton), findsOneWidget);
    expect(find.byType(MonoStoryListRow), findsOneWidget);
    expect(find.text('Mono T'), findsOneWidget);

    // 3-dot should open a menu (no immediate remove).
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Remove from collection'), findsOneWidget);
    expect(removeReq, isNull);

    await tester.tap(find.text('Remove from collection'));
    await tester.pumpAndSettle();
    expect(removeReq, isNotNull);
  });
}
