import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/mono/mono_search_screen.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';
import 'package:nimon/features/search/data/mono_search_remote.dart';
import 'package:nimon/features/search/data/mono_search_result.dart';
import 'package:nimon/features/search/presentation/mono_search_notifier.dart';
import 'package:nimon/features/search/presentation/mono_search_providers.dart';
import 'package:nimon/l10n/app_localizations.dart';
import 'package:nimon/ui/nimon_default_cover_asset.dart';

typedef _SearchHandler = Future<PaginatedPage<MonoSearchResult>> Function({
  String? q,
  String? level,
  String? category,
  String sort,
  int limit,
  String? cursor,
});

MonoSearchResult _oneResult(String id) {
  return MonoSearchResult(
    listItem: PublishedMonoListItemDto(
      id: id,
      ownerId: 'o',
      sourceDraftId: null,
      title: 'Hello $id',
      category: 'Love',
      level: 'N5',
      description: 'Desc',
      publishKind: 'read_only_v1',
      displayPublishKind: 'read_only',
      coverImageUrl: null,
      targetDurationLabel: '3 min',
      createdAt: '2020-01-01T00:00:00.000Z',
      updatedAt: '2020-01-01T00:00:00.000Z',
      contentSummary: null,
      writerDisplayName: 'Writer',
      writerHandle: 'w',
      writerAvatarUrl: null,
      shareUrl: 'https://example.com/mono/$id',
    ),
    likesCount: 2,
    isBookmarkedByMe: false,
    myReaction: null,
  );
}

class _RecordingSearchRemote implements MonoSearchRemote {
  _RecordingSearchRemote(this._handler);

  final _SearchHandler _handler;

  int callCount = 0;
  String? lastQ;
  String? lastLevel;
  String? lastCategory;

  @override
  Future<PaginatedPage<MonoSearchResult>> searchMonos({
    String? q,
    String? level,
    String? category,
    String sort = 'latest',
    int limit = 20,
    String? cursor,
  }) async {
    callCount++;
    lastQ = q;
    lastLevel = level;
    lastCategory = category;
    return _handler(
      q: q,
      level: level,
      category: category,
      sort: sort,
      limit: limit,
      cursor: cursor,
    );
  }
}

Widget _wrap({
  required GoRouter router,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
    ),
  );
}

void main() {
  testWidgets('typing query triggers debounced search', (tester) async {
    final remote = _RecordingSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      return PaginatedPage<MonoSearchResult>(
        items: [if (q != null && q.isNotEmpty) _oneResult('1')],
        hasMore: false,
        nextCursor: null,
        totalCount: 1,
      );
    });

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const MonoSearchScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        router: router,
        overrides: [
          monoSearchNotifierProvider.overrideWith(
            (ref) => MonoSearchNotifier(
              remote,
              debounce: const Duration(milliseconds: 8),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    expect(remote.callCount, 0);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpAndSettle();
    expect(remote.callCount, 1);
    expect(remote.lastQ, 'abc');
    expect(find.text('Hello 1'), findsOneWidget);
  });

  testWidgets('level chip sets level and reloads', (tester) async {
    final remote = _RecordingSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      return PaginatedPage<MonoSearchResult>(
        items: [if (level == 'N4') _oneResult('n4')],
        hasMore: false,
        nextCursor: null,
        totalCount: 1,
      );
    });

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const MonoSearchScreen()),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        router: router,
        overrides: [
          monoSearchNotifierProvider.overrideWith(
            (ref) => MonoSearchNotifier(remote, debounce: Duration.zero),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('N4'));
    await tester.pumpAndSettle();
    expect(remote.lastLevel, 'N4');
    expect(find.text('Hello n4'), findsOneWidget);
  });

  testWidgets('category chip sets category', (tester) async {
    final remote = _RecordingSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      return PaginatedPage<MonoSearchResult>(
        items: [if (category == 'Horror') _oneResult('h1')],
        hasMore: false,
        nextCursor: null,
        totalCount: 1,
      );
    });

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const MonoSearchScreen()),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        router: router,
        overrides: [
          monoSearchNotifierProvider.overrideWith(
            (ref) => MonoSearchNotifier(remote, debounce: Duration.zero),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Horror'));
    await tester.pumpAndSettle();
    expect(remote.lastCategory, 'Horror');
    expect(find.text('Hello h1'), findsOneWidget);
  });

  testWidgets('shows marketing empty state before search', (tester) async {
    final remote = _RecordingSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      return PaginatedPage<MonoSearchResult>.empty();
    });
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const MonoSearchScreen()),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        router: router,
        overrides: [
          monoSearchNotifierProvider.overrideWith(
            (ref) => MonoSearchNotifier(remote, debounce: Duration.zero),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Find stories by title'), findsOneWidget);
    expect(remote.callCount, 0);
  });

  testWidgets('empty results panel after fetch', (tester) async {
    final remote = _RecordingSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      return PaginatedPage<MonoSearchResult>(
        items: const [],
        hasMore: false,
        nextCursor: null,
        totalCount: 0,
      );
    });
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const MonoSearchScreen()),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        router: router,
        overrides: [
          monoSearchNotifierProvider.overrideWith(
            (ref) => MonoSearchNotifier(remote, debounce: Duration.zero),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('N5').first);
    await tester.pumpAndSettle();
    expect(find.text('No results found'), findsOneWidget);
    expect(find.textContaining('Try another keyword'), findsOneWidget);
  });

  testWidgets('error shows retry and retry succeeds', (tester) async {
    var n = 0;
    final remote = _RecordingSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      n++;
      if (n == 1) throw StateError('offline');
      return PaginatedPage<MonoSearchResult>(
        items: [_oneResult('ok')],
        hasMore: false,
        nextCursor: null,
        totalCount: 1,
      );
    });

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const MonoSearchScreen()),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        router: router,
        overrides: [
          monoSearchNotifierProvider.overrideWith(
            (ref) => MonoSearchNotifier(remote, debounce: Duration.zero),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('N3'));
    await tester.pumpAndSettle();
    expect(find.textContaining('offline'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Hello ok'), findsOneWidget);
  });

  testWidgets('tap result opens mono-reader route', (tester) async {
    final remote = _RecordingSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      return PaginatedPage<MonoSearchResult>(
        items: [_oneResult('open-me')],
        hasMore: false,
        nextCursor: null,
        totalCount: 1,
      );
    });

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const MonoSearchScreen()),
        GoRoute(
          path: '/mono-reader',
          builder: (_, __) =>
              const Scaffold(body: Text('reader_opened_marker')),
        ),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        router: router,
        overrides: [
          monoSearchNotifierProvider.overrideWith(
            (ref) => MonoSearchNotifier(remote, debounce: Duration.zero),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('N2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hello open-me'));
    await tester.pumpAndSettle();

    expect(find.text('reader_opened_marker'), findsOneWidget);
  });

  testWidgets('guest: no sign-in gate on search screen', (tester) async {
    final remote = _RecordingSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async =>
        PaginatedPage<MonoSearchResult>.empty());
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const MonoSearchScreen()),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        router: router,
        overrides: [
          monoSearchNotifierProvider.overrideWith(
            (ref) => MonoSearchNotifier(remote, debounce: Duration.zero),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in required'), findsNothing);
  });

  testWidgets('dark theme: initial copy uses on-surface tones', (tester) async {
    final remote = _RecordingSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async =>
        PaginatedPage<MonoSearchResult>.empty());
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const MonoSearchScreen()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monoSearchNotifierProvider.overrideWith(
            (ref) => MonoSearchNotifier(remote, debounce: Duration.zero),
          ),
        ],
        child: MaterialApp.router(
          theme: ThemeData.dark(),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final body =
        tester.widget<Text>(find.textContaining('Find stories by title'));
    final color = body.style?.color;
    expect(color, isNotNull);
    expect(color!.a > 0.5, isTrue);
  });

  testWidgets('scroll near end triggers loadMore', (tester) async {
    final remote = _RecordingSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      if (cursor == null) {
        return PaginatedPage<MonoSearchResult>(
          items: List.generate(15, (i) => _oneResult('p1-$i')),
          hasMore: true,
          nextCursor: 'c2',
          totalCount: 30,
        );
      }
      return PaginatedPage<MonoSearchResult>(
        items: List.generate(15, (i) => _oneResult('p2-$i')),
        hasMore: false,
        nextCursor: null,
        totalCount: 30,
      );
    });

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const MonoSearchScreen()),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        router: router,
        overrides: [
          monoSearchNotifierProvider.overrideWith(
            (ref) => MonoSearchNotifier(remote, debounce: Duration.zero),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('N1'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('mono_search_results_list')),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();
    expect(remote.callCount, greaterThanOrEqualTo(2));
  });

  testWidgets('no bottom spinner when hasMore is false', (tester) async {
    final remote = _RecordingSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      return PaginatedPage<MonoSearchResult>(
        items: [_oneResult('only')],
        hasMore: false,
        nextCursor: null,
        totalCount: 1,
      );
    });
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const MonoSearchScreen()),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        router: router,
        overrides: [
          monoSearchNotifierProvider.overrideWith(
            (ref) => MonoSearchNotifier(remote, debounce: Duration.zero),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('N5').first);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('search result row with null cover renders default asset image',
      (tester) async {
    final remote = _RecordingSearchRemote(({
      String? q,
      String? level,
      String? category,
      String sort = 'latest',
      int limit = 20,
      String? cursor,
    }) async {
      return PaginatedPage<MonoSearchResult>(
        items: [if (q != null && q.isNotEmpty) _oneResult('1')],
        hasMore: false,
        nextCursor: null,
        totalCount: 1,
      );
    });

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const MonoSearchScreen()),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        router: router,
        overrides: [
          monoSearchNotifierProvider.overrideWith(
            (ref) => MonoSearchNotifier(remote, debounce: Duration.zero),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'mono');
    await tester.pumpAndSettle();

    var foundDefault = false;
    for (final img in tester.widgetList<Image>(find.byType(Image))) {
      final p = img.image;
      if (p is AssetImage && p.assetName == nimonDefaultStoryCoverAsset) {
        foundDefault = true;
        break;
      }
    }
    expect(foundDefault, isTrue);
  });
}
