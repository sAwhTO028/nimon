import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/features/profile/data/remote_creator_collections_repository.dart';
import 'package:nimon/features/profile/presentation/add_to_collection_sheet.dart';
import 'package:nimon/features/profile/presentation/providers/my_creator_collections_notifier.dart';

void main() {
  testWidgets('Add to collection sheet loads collections from GET',
      (tester) async {
    http.Request? createdReq;
    http.Request? bulkReq;
    final repo = RemoteCreatorCollectionsRepository(
      apiBaseUrl: 'http://stub.test',
      authHeaderBuilder: () async => <String, String>{},
      client: MockClient((req) async {
        if (req.method == 'GET' &&
            req.url.path.endsWith('/v1/me/creator-collections')) {
          return http.Response(
            jsonEncode({
              'collections': [
                {
                  'id': 'ccc',
                  'ownerId': 'ooo',
                  'title': 'Morning reads',
                  'description': null,
                  'coverImageUrl': null,
                  'visibility': 'public',
                  'itemCount': 2,
                  'createdAt': '2026-01-01T00:00:00.000Z',
                  'updatedAt': '2026-01-02T00:00:00.000Z',
                },
              ],
            }),
            200,
          );
        }
        if (req.method == 'POST' &&
            req.url.path.endsWith('/v1/me/creator-collections')) {
          createdReq = req;
          return http.Response(
            jsonEncode({
              'collection': {
                'id': 'new-col',
                'ownerId': 'ooo',
                'title': 'New',
                'description': null,
                'coverImageUrl': null,
                'visibility': 'public',
                'itemCount': 0,
                'createdAt': '2026-01-01T00:00:00.000Z',
                'updatedAt': '2026-01-02T00:00:00.000Z',
              },
            }),
            201,
          );
        }
        if (req.method == 'POST' && req.url.path.endsWith('/items/bulk')) {
          bulkReq = req;
          return http.Response(
            jsonEncode({
              'inserted': 1,
              'skippedDuplicates': 0,
              'skippedNotOwnedOrMissing': 0,
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteCreatorCollectionsRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => showAddToCollectionSheet(
                    context: ctx,
                    publishedMonoIds: const [
                      '00000000-0000-4000-8000-000000000001',
                    ],
                  ),
                  child: const Text('Open sheet'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Move to collection'), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Morning reads'), findsOneWidget);

    await tester.tap(find.text('Morning reads'));
    await tester.pumpAndSettle();

    expect(find.text('Added to collection.'), findsOneWidget);

    // Create path (createAndAdd): POST create then POST bulk.
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create new collection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'New');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(createdReq, isNotNull);
    expect(createdReq!.url.path, endsWith('/v1/me/creator-collections'));
    expect(bulkReq, isNotNull);
  });

  testWidgets('CreateOnly mode creates without bulk add', (tester) async {
    http.Request? createdReq;
    http.Request? bulkReq;
    final repo = RemoteCreatorCollectionsRepository(
      apiBaseUrl: 'http://stub.test',
      authHeaderBuilder: () async => <String, String>{},
      client: MockClient((req) async {
        if (req.method == 'GET' &&
            req.url.path.endsWith('/v1/me/creator-collections')) {
          return http.Response(jsonEncode({'collections': []}), 200);
        }
        if (req.method == 'POST' &&
            req.url.path.endsWith('/v1/me/creator-collections')) {
          createdReq = req;
          return http.Response(
            jsonEncode({
              'collection': {
                'id': 'new-col',
                'ownerId': 'ooo',
                'title': 'Empty',
                'description': null,
                'coverImageUrl': null,
                'visibility': 'public',
                'itemCount': 0,
                'createdAt': '2026-01-01T00:00:00.000Z',
                'updatedAt': '2026-01-02T00:00:00.000Z',
              },
            }),
            201,
          );
        }
        if (req.method == 'POST' && req.url.path.endsWith('/items/bulk')) {
          bulkReq = req;
          return http.Response(jsonEncode({}), 200);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteCreatorCollectionsRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => showAddToCollectionSheet(
                    context: ctx,
                    publishedMonoIds: const [],
                    mode: AddToCollectionSheetMode.createOnly,
                    startInCreateMode: true,
                  ),
                  child: const Text('Open sheet'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Empty');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(createdReq, isNotNull);
    expect(bulkReq, isNull);
  });
}
