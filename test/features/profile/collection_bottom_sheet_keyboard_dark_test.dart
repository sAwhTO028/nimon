import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/features/profile/data/remote_creator_collections_repository.dart';
import 'package:nimon/features/profile/presentation/add_to_collection_sheet.dart';
import 'package:nimon/features/profile/presentation/providers/my_creator_collections_notifier.dart';
import 'package:nimon/features/profile/presentation/widgets/profile_collection_bottom_sheet_frame.dart';

import '../../support/auth_session_test_overrides.dart';

ThemeData _darkTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: Brightness.dark,
      ),
    );

void main() {
  testWidgets('Add-to-collection selected count uses onSurfaceVariant in dark',
      (tester) async {
    final repo = RemoteCreatorCollectionsRepository(
      apiBaseUrl: 'http://stub.test',
      authHeaderBuilder: () async => <String, String>{},
      client: MockClient((req) async {
        if (req.method == 'GET' &&
            req.url.path.endsWith('/v1/me/creator-collections')) {
          return http.Response('{"collections":[]}', 200);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authenticatedAuthSessionOverride,
          remoteCreatorCollectionsRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: _darkTheme(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: TextButton(
                  onPressed: () => showAddToCollectionSheet(
                    context: ctx,
                    publishedMonoIds: const [
                      '00000000-0000-4000-8000-000000000001',
                    ],
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final countText =
        tester.widget<Text>(find.byKey(collectionSheetSelectedCountTextKey));
    final c = countText.style?.color;
    expect(c, isNotNull);
    expect(c, isNot(equals(const Color(0xFF000000))));
    expect(c!.computeLuminance(), greaterThan(0.35));
  });

  testWidgets(
      'ProfileCollectionBottomSheetFrame keeps field and actions visible with keyboard insets',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 640),
            viewInsets: EdgeInsets.only(bottom: 220),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ProfileCollectionBottomSheetFrame(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'New collection',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const TextField(
                      decoration: InputDecoration(
                        labelText: 'Collection name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {},
                            child: const Text('Create'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('ProfileCollectionBottomSheetFrame light theme — no overflow',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        ),
        home: Scaffold(
          body: ProfileCollectionBottomSheetFrame(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('Title'),
                SizedBox(height: 8),
                Text('Body'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final exc = tester.takeException();
    if (exc != null) {
      expect(exc.toString(), isNot(contains('overflowed')));
    }
  });
}
