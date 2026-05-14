import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/pagination_defaults.dart';
import 'package:nimon/data/story_repo_mock.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/profile/data/remote_published_mono_repository.dart';
import 'package:nimon/features/profile/presentation/providers/profile_published_mono_pager.dart';
import 'package:nimon/features/profile/profile_screen.dart';

import 'profile_published_pagination_test.dart' show publishedMonoListJsonRow;

http.Response _page1Response() {
  final items = List<Map<String, Object?>>.generate(
    10,
    (i) => publishedMonoListJsonRow('m-$i', 3000 + i),
  );
  return http.Response(
    jsonEncode(<String, Object?>{
      'items': items,
      'nextCursor': 'opaque-c1',
      'hasMore': true,
      'totalCount': 21,
    }),
    200,
  );
}

http.Response _page2Response() {
  final items = List<Map<String, Object?>>.generate(
    10,
    (i) => publishedMonoListJsonRow('m-${10 + i}', 2000 + i),
  );
  return http.Response(
    jsonEncode(<String, Object?>{
      'items': items,
      'nextCursor': 'opaque-c2',
      'hasMore': true,
    }),
    200,
  );
}

http.Response _page3Response() {
  return http.Response(
    jsonEncode(<String, Object?>{
      'items': [publishedMonoListJsonRow('m-20', 1000)],
      'nextCursor': null,
      'hasMore': false,
    }),
    200,
  );
}

void main() {
  test(
    'RemotePublishedMonoRepository maps total_count to PageResult.totalCount',
    () async {
      final items = List<Map<String, Object?>>.generate(
        3,
        (i) => publishedMonoListJsonRow('x-$i', 100 + i),
      );
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'http://stub.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(<String, Object?>{
              'items': items,
              'nextCursor': null,
              'hasMore': false,
              'total_count': 21,
            }),
            200,
          ),
        ),
        authHeaderBuilder: () async => <String, String>{},
        sendWithAuth401Recovery: null,
      );
      final r = await repo.fetchPage(
        PageRequest(limit: PaginationDefaults.profilePublishedMonoPageLimit),
      );
      expect(r.totalCount, 21);
    },
    skip: !RemoteBackendConfig.useRemoteDrafts,
  );

  testWidgets(
    'owner Profile Published Monos: header 21 with 10 rows; sentinel starts loadMore; '
    'two loadMore complete to 21 rows without duplicates',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final page2Gate = Completer<void>();
      final page3Gate = Completer<void>();
      var httpCalls = 0;
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'http://stub.test',
        client: MockClient((req) async {
          httpCalls++;
          expect(req.url.path, endsWith('/v1/published-monos'));
          expect(
            req.url.queryParameters['limit'],
            '${PaginationDefaults.profilePublishedMonoPageLimit}',
          );
          if (httpCalls == 1) {
            expect(req.url.queryParameters['cursor'], isNull);
            return _page1Response();
          }
          if (httpCalls == 2) {
            expect(req.url.queryParameters['cursor'], 'opaque-c1');
            await page2Gate.future;
            return _page2Response();
          }
          if (httpCalls == 3) {
            expect(req.url.queryParameters['cursor'], 'opaque-c2');
            await page3Gate.future;
            return _page3Response();
          }
          fail('unexpected published-monos list call #$httpCalls');
        }),
        authHeaderBuilder: () async => <String, String>{},
        sendWithAuth401Recovery: null,
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => ProfileScreen(
              repo: StoryRepoMock(),
              initialTabIndex: 0,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remotePublishedMonoRepositoryForProfileProvider
                .overrideWithValue(repo),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      final profileFinder = find.byType(ProfileScreen);

      // First page is applied; a second GET may already be in flight (sentinel /
      // underscroll prefetch) and blocked on [page2Gate] before page-2 JSON returns.
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (!tester.any(profileFinder)) continue;
        final ctx = tester.element(profileFinder);
        final p = ProviderScope.containerOf(ctx)
            .read(profilePublishedMonoPagerProvider);
        if (p.items.length == 10 && p.totalCount == 21) {
          if (httpCalls >= 2) break;
          if (i > 90) {
            fail('expected loadMore to start (httpCalls>=2), got $httpCalls');
          }
        }
      }

      expect(httpCalls, greaterThanOrEqualTo(1));
      expect(httpCalls, lessThanOrEqualTo(2));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      for (var i = 0; i < 80 && httpCalls < 2; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(httpCalls, 2);

      expect(find.text('21'), findsWidgets);
      expect(find.text('Tm-0'), findsOneWidget);

      final monosList = find.byKey(const ValueKey('profilePublishedMonosList'));
      expect(tester.any(monosList), isTrue);
      final sentinelFinder = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<Object> &&
            '${(w.key as ValueKey<Object>).value}'
                .startsWith('profilePublishedMonosSentinel_'),
      );
      for (var s = 0; s < 8 && !tester.any(sentinelFinder); s++) {
        await tester.drag(monosList, const Offset(0, -180));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(sentinelFinder, findsOneWidget);

      expect(find.byType(CircularProgressIndicator), findsWidgets);

      final profileContext = tester.element(find.byType(ProfileScreen));
      final container = ProviderScope.containerOf(profileContext);
      final mid = container.read(profilePublishedMonoPagerProvider);
      expect(mid.items, hasLength(10));
      expect(mid.totalCount, 21);
      expect(mid.hasMore, isTrue);
      expect(mid.nextCursor, 'opaque-c1');

      page2Gate.complete();
      await tester.pump();
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (container.read(profilePublishedMonoPagerProvider).items.length >=
            20) {
          break;
        }
      }
      expect(
        container.read(profilePublishedMonoPagerProvider).items.length,
        greaterThanOrEqualTo(20),
      );
      expect(httpCalls, greaterThanOrEqualTo(2));

      // Underscroll prefetch may start page 3 before this gate completes.
      if (!page3Gate.isCompleted) {
        page3Gate.complete();
      }
      await tester.pump();
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (container.read(profilePublishedMonoPagerProvider).items.length >=
            21) {
          break;
        }
      }
      expect(httpCalls, 3);

      await tester.pump(const Duration(milliseconds: 50));

      final done = container.read(profilePublishedMonoPagerProvider);
      expect(done.items, hasLength(21));
      expect(done.hasMore, isFalse);
      expect(done.nextCursor, isNull);

      final ids = done.items.map((e) => e.id).toSet();
      expect(ids, hasLength(21));
      expect(
        ids.containsAll(List<String>.generate(21, (i) => 'm-$i')),
        isTrue,
      );
    },
    skip: !RemoteBackendConfig.useRemoteDrafts,
  );

  testWidgets(
    'M17C-2 owner Profile Published Monos prefetches until 21 rows when list is short',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var httpCalls = 0;
      final repo = RemotePublishedMonoRepository(
        apiBaseUrl: 'http://stub.test',
        client: MockClient((req) async {
          httpCalls++;
          expect(req.url.path, endsWith('/v1/published-monos'));
          expect(
            req.url.queryParameters['limit'],
            '${PaginationDefaults.profilePublishedMonoPageLimit}',
          );
          if (httpCalls == 1) {
            expect(req.url.queryParameters['cursor'], isNull);
            return _page1Response();
          }
          if (httpCalls == 2) {
            expect(req.url.queryParameters['cursor'], 'opaque-c1');
            return _page2Response();
          }
          expect(req.url.queryParameters['cursor'], 'opaque-c2');
          return _page3Response();
        }),
        authHeaderBuilder: () async => <String, String>{},
        sendWithAuth401Recovery: null,
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => ProfileScreen(
              repo: StoryRepoMock(),
              initialTabIndex: 0,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remotePublishedMonoRepositoryForProfileProvider
                .overrideWithValue(repo),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        if (httpCalls >= 3) break;
      }
      await tester.pumpAndSettle();

      expect(httpCalls, 3);
      final profileContext = tester.element(find.byType(ProfileScreen));
      final container = ProviderScope.containerOf(profileContext);
      final published = container.read(profilePublishedMonoPagerProvider);
      expect(published.items, hasLength(21));
      expect(published.items.last.id, 'm-20');
    },
    skip: !RemoteBackendConfig.useRemoteDrafts,
  );
}
