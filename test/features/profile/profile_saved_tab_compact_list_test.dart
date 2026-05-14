import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/mono/data/mono_feed_providers.dart';
import 'package:nimon/features/mono/data/remote_mono_social_repository.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';
import 'package:nimon/features/profile/mono_story_list_row.dart';
import 'package:nimon/features/profile/presentation/profile_saved_remote_tab.dart';
import '../../support/auth_session_test_overrides.dart';

class _FakeSocialRepo extends RemoteMonoSocialRepository {
  _FakeSocialRepo(this._page)
      : super(apiBaseUrl: 'http://x', authHeaderBuilder: () async => {});

  final PageResult<MonoFeedItem> _page;

  @override
  Future<PageResult<MonoFeedItem>> fetchBookmarkedPage(
    PageRequest request,
  ) async =>
      _page;
}

void main() {
  testWidgets('Saved tab shows compact MonoStoryListRow rows, no Cards', (
    tester,
  ) async {
    final fake = _FakeSocialRepo(
      PageResult(
        items: const [
          MonoFeedItem(
            id: 'm1',
            writerName: 'W',
            writerHandle: '@w',
            level: 'N5',
            contentType: MonoContentType.story,
            bodyText: 'b',
            title: 'Saved title one',
            storyDescription: 'Subtitle line for compact row.',
            coverImageUrl: 'https://example.com/cover.png',
            isBookmarkedByMe: true,
          ),
        ],
        hasMore: false,
        nextCursor: null,
      ),
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const ProfileSavedRemoteTab(bottomPadding: 0),
        ),
        GoRoute(
          path: '/mono-reader',
          builder: (_, __) => const Scaffold(body: Text('reader stub')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authenticatedAuthSessionOverride,
          remoteMonoSocialRepositoryProvider.overrideWithValue(fake),
        ],
        child: MaterialApp.router(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          ),
          routerConfig: router,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle();

    expect(find.byType(MonoStoryListRow), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.text('Saved title one'), findsOneWidget);
    expect(find.textContaining('Subtitle line'), findsOneWidget);
    expect(
      find.byKey(ValueKey('${kProfileSavedCompactRowKey}m1')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('${kProfileSavedUnsaveButtonKey}m1')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.bookmark_remove_outlined), findsOneWidget);

    await tester.tap(find.text('Saved title one'));
    await tester.pumpAndSettle();
    expect(find.text('reader stub'), findsOneWidget);
  });
}
