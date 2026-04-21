import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/mono/mono_reader_menu_origin.dart';
import 'package:nimon/features/mono/mono_search_screen.dart';
import 'package:nimon/features/mono/mono_screen.dart';
import 'package:nimon/features/profile/profile_push_drawer_scope.dart';
import 'package:nimon/features/profile/profile_screen.dart';
import 'package:nimon/features/profile/profile_connections_screen.dart';
import 'package:nimon/features/profile/public_folder_detail_screen.dart';
import 'package:nimon/features/profile/public_profile_screen.dart';
import 'package:nimon/features/profile/share_profile_screen.dart';
import 'package:nimon/features/profile/notifications_screen.dart';
import 'package:nimon/features/auth/login_screen.dart';
import 'package:nimon/data/repo_singleton.dart';
import 'package:nimon/features/learn/grammar_pattern.dart';
import 'package:nimon/features/learn/grammar_pattern_detail_screen.dart';
import 'package:nimon/features/learn/grammar_pattern_list_screen.dart';
import 'package:nimon/features/learn/learn_explanation_language.dart';
import 'package:nimon/features/learn/learn_hub_screen.dart';
import 'package:nimon/features/learn/listening_pronunciation_screen.dart';
import 'package:nimon/features/learn/quiz_play_screen.dart';
import 'package:nimon/features/learn/quiz_result_screen.dart';
import 'package:nimon/features/learn/quiz_session.dart';
import 'package:nimon/features/learn/quiz_setup_screen.dart';
import 'package:nimon/features/learn/vocab_kanji_list_screen.dart';
import 'package:nimon/features/create/create_screen.dart';
import 'package:nimon/features/create/story_creator_add_tab_screen.dart';
import 'package:nimon/features/create/story_creator_basics_screen.dart';
import 'package:nimon/features/create/story_creator_learn_hub_screen.dart';
import 'package:nimon/features/create/story_creator_sentences_screen.dart';
import 'package:nimon/core/theme.dart';
import 'package:nimon/features/settings/help_feedback_screen.dart';
import 'package:nimon/features/settings/settings_providers.dart';
import 'package:nimon/features/settings/settings_screen.dart';
import 'package:nimon/widgets/floating_dock_nav_bar.dart';

void main() => runApp(const ProviderScope(child: NimonApp()));

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: '/profile/public',
      builder: (ctx, st) => PublicProfileScreen(
        ownerPreview: st.uri.queryParameters['from'] == 'owner',
        creatorHandle: st.uri.queryParameters['creator'],
      ),
      routes: [
        GoRoute(
          path: 'folder/:folderId',
          builder: (ctx, st) => PublicFolderDetailScreen(
            folderId: st.pathParameters['folderId']!,
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/profile/share',
      builder: (_, __) => const ShareProfileScreen(
        displayName: 'Just4withYou',
        handle: '@just4withyou',
        publicProfileUrl: 'https://nimon.app/u/just4withyou',
      ),
    ),
    GoRoute(
      path: '/profile/notifications',
      builder: (_, __) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/profile/followers',
      builder: (_, __) => const ProfileConnectionsScreen(
        kind: ProfileConnectionsKind.followers,
      ),
    ),
    GoRoute(
      path: '/profile/following',
      builder: (_, __) => const ProfileConnectionsScreen(
        kind: ProfileConnectionsKind.following,
      ),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, __) => const SettingsScreen(),
      routes: [
        GoRoute(
          path: 'help',
          builder: (_, __) => const HelpFeedbackScreen(),
        ),
      ],
    ),
    // V1: Create is outside ShellRoute so it doesn't show bottom nav
    GoRoute(
      path: '/create',
      builder: (_, state) {
        // `/create` is the dock **Add** entry. V1 UX: show a lightweight hub for
        // continuing local drafts + starting a new story.
        //
        // `editBasics=1` opens the shared draft form (return path preserved).
        if (state.uri.queryParameters['editBasics'] == '1') {
          return CreateScreen(
            initialTab: state.uri.queryParameters['tab'],
            editFromReview: true,
          );
        }
        return const StoryCreatorAddTabScreen();
      },
    ),
    GoRoute(
      path: '/create/story',
      redirect: (_, st) {
        // Remove the standalone creator hub page from the product flow.
        // Keep subroutes (`/create/story/sentences`, etc.) working.
        if (st.uri.path == '/create/story' || st.uri.path == '/create/story/') {
          return '/create';
        }
        return null;
      },
      builder: (_, __) => const SizedBox.shrink(),
      routes: [
        GoRoute(
          path: 'basics',
          builder: (_, __) => const StoryCreatorBasicsScreen(),
        ),
        GoRoute(
          path: 'sentences',
          builder: (_, __) => const StoryCreatorSentencesScreen(),
        ),
        GoRoute(
          path: 'learn',
          builder: (_, __) => const StoryCreatorLearnHubScreen(),
          routes: [
            GoRoute(
              path: 'vocabulary',
              redirect: (_, __) => '/create/story/sentences?panel=vocabulary',
              builder: (_, __) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: 'grammar',
              redirect: (_, __) => '/create/story/sentences?panel=grammar',
              builder: (_, __) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: 'quiz',
              redirect: (_, __) => '/create/story/sentences?panel=quiz',
              builder: (_, __) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: 'audio',
              redirect: (_, __) => '/create/story/sentences?panel=listening',
              builder: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    ),
    // Learn is outside ShellRoute so it doesn't show bottom nav
    GoRoute(
      path: '/learn/:id/grammar/detail',
      builder: (ctx, st) {
        final id = st.pathParameters['id'] ?? 'mono';
        final extra = st.extra;
        GrammarPattern? pattern;
        if (extra is GrammarPattern) pattern = extra;
        return GrammarPatternDetailScreen(
          contentId: id,
          pattern: pattern,
        );
      },
    ),
    GoRoute(
      path: '/learn/:id/grammar',
      builder: (ctx, st) {
        final id = st.pathParameters['id'] ?? 'mono';
        return GrammarPatternListScreen(contentId: id);
      },
    ),
    GoRoute(
      path: '/learn/:id/vocabulary',
      builder: (ctx, st) {
        final id = st.pathParameters['id'] ?? 'mono';
        return VocabKanjiListScreen(contentId: id);
      },
    ),
    GoRoute(
      path: '/learn/:id/quiz/result',
      builder: (ctx, st) {
        final id = st.pathParameters['id'] ?? 'mono';
        final extra = st.extra;
        QuizResultSummary? summary;
        if (extra is QuizResultSummary) summary = extra;
        return QuizResultScreen(contentId: id, summary: summary);
      },
    ),
    GoRoute(
      path: '/learn/:id/quiz/play',
      builder: (ctx, st) {
        final id = st.pathParameters['id'] ?? 'mono';
        final extra = st.extra;
        QuizSessionStartArgs? args;
        if (extra is QuizSessionStartArgs) args = extra;
        return QuizPlayScreen(contentId: id, args: args);
      },
    ),
    GoRoute(
      path: '/learn/:id/quiz',
      builder: (ctx, st) {
        final id = st.pathParameters['id'] ?? 'mono';
        return QuizSetupScreen(contentId: id);
      },
    ),
    GoRoute(
      path: '/learn/:id/listening',
      builder: (ctx, st) {
        final id = st.pathParameters['id'] ?? 'mono';
        final extra = st.extra;
        String? storyTitle;
        String? audioUrl;
        LearnExplanationLanguage? explanationLanguageOverride;
        if (extra is Map) {
          final v1 = extra['storyTitle'];
          final v2 = extra['audioUrl'];
          final v3 = extra['explanationLanguage'];
          if (v1 is String) storyTitle = v1;
          if (v2 is String) audioUrl = v2;
          if (v3 == 'my') {
            explanationLanguageOverride = LearnExplanationLanguage.myanmar;
          } else if (v3 == 'en') {
            explanationLanguageOverride = LearnExplanationLanguage.english;
          }
        }
        return ListeningPronunciationScreen(
          contentId: id,
          storyTitle: storyTitle,
          audioUrl: audioUrl,
          explanationLanguageOverride: explanationLanguageOverride,
        );
      },
    ),
    GoRoute(
      path: '/learn/:id',
      builder: (ctx, st) {
        final extra = st.extra;
        String? coverImageUrl;
        String? coverFallbackAsset;
        String? storyTitle;
        String? level;
        String? category;
        String? unlock;
        String? description;
        if (extra is Map) {
          final v1 = extra['coverImageUrl'];
          final v2 = extra['coverFallbackAsset'];
          if (v1 is String) coverImageUrl = v1;
          if (v2 is String) coverFallbackAsset = v2;
          final v3 = extra['storyTitle'];
          final v4 = extra['level'];
          final v5 = extra['category'];
          final v7 = extra['unlock'];
          final v8 = extra['description'];
          if (v3 is String) storyTitle = v3;
          if (v4 is String) level = v4;
          if (v5 is String) category = v5;
          if (v7 is String) unlock = v7;
          if (v8 is String) description = v8;
        }
        return LearnHubScreen(
          contentId: st.pathParameters['id'] ?? 'mono',
          coverImageUrl: coverImageUrl,
          coverFallbackAsset: coverFallbackAsset,
          storyTitle: storyTitle,
          level: level,
          category: category,
          unlock: unlock,
          description: description,
        );
      },
    ),
    GoRoute(
      path: '/mono/search',
      builder: (_, __) => const MonoSearchScreen(),
    ),
    // Folder-aware reader (Uploaded / Bookmark): dedicated immersive screen with custom dock.
    GoRoute(
      path: '/mono-reader',
      builder: (ctx, st) {
        final extra = st.extra;
        var items = const <MonoFeedItem>[];
        var initialIndex = 0;
        MonoReaderMenuOrigin? readerMenuOrigin;
        void Function(String monoFeedItemId)? onUnsavedMonoFeedItemId;
        if (extra is Map) {
          final v1 = extra['items'];
          final v2 = extra['initialIndex'];
          if (v1 is List<MonoFeedItem>) items = v1;
          if (v2 is int) initialIndex = v2;
          final v3 = extra['readerMenuOrigin'];
          if (v3 is MonoReaderMenuOrigin) readerMenuOrigin = v3;
          final v4 = extra['onUnsavedMonoFeedItemId'];
          if (v4 is void Function(String)) {
            onUnsavedMonoFeedItemId = v4;
          }
        }
        return MonoScreen(
          repo: repo,
          initialItemsOverride: items,
          initialIndexOverride: initialIndex,
          showTopControls: false,
          readerMenuOrigin: readerMenuOrigin,
          onUnsavedMonoFeedItemId: onUnsavedMonoFeedItemId,
        );
      },
    ),
    // Stateful nested shell: Mono + Profile are parallel branch navigators in an
    // IndexedStack — no route transition animation when switching dock tabs.
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/mono',
              builder: (_, state) {
                final extra = state.extra;
                final MonoFeedItem? initial =
                    extra is MonoFeedItem ? extra : null;
                return MonoScreen(
                  repo: repo,
                  initialItemOverride: initial,
                );
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/more',
              builder: (_, state) {
                final q = state.uri.queryParameters;
                int? initialTab;
                if (q['tab'] == 'saved' || q['saved'] == '1') {
                  initialTab = 2;
                } else if (q['tab'] == 'processing') {
                  initialTab = 1;
                } else if (q['tab'] == 'uploaded') {
                  initialTab = 0;
                }
                final highlight = q['highlight']?.trim();
                return ProfileScreen(
                  repo: repo,
                  initialTabIndex: initialTab,
                  highlightDraftId:
                      highlight != null && highlight.isNotEmpty ? highlight : null,
                );
              },
            ),
          ],
        ),
      ],
    ),
  ],
);

class NimonApp extends ConsumerWidget {
  const NimonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeSettingProvider);
    final appLocale = ref.watch(appLocaleSettingProvider);
    final readingScale = ref.watch(readingTextScaleSettingProvider);

    return MaterialApp.router(
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      locale: appLocale,
      supportedLocales: const [
        Locale('en'),
        Locale('ja'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(readingScale)),
          child: child!,
        );
      },
    );
  }
}

class AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Profile right push drawer: hide bottom dock while open (see [ProfilePushDrawerDockScope]).
  final ValueNotifier<bool> _profilePushDrawerObscuresDock =
      ValueNotifier(false);

  int _indexFromLocation(String loc) {
    if (loc.startsWith('/mono')) return 0;
    if (loc.startsWith('/more') ||
        loc.startsWith('/profile/public') ||
        loc.startsWith('/profile/notifications') ||
        loc.startsWith('/profile/followers') ||
        loc.startsWith('/profile/following')) {
      return 2;
    }
    return -1;
  }

  @override
  void dispose() {
    _profilePushDrawerObscuresDock.dispose();
    super.dispose();
  }

  void _openCreate(BuildContext context) {
    // Check if we're already on the create page to prevent duplicates
    final currentLocation = GoRouterState.of(context).uri.toString();
    if (currentLocation == '/create' ||
        currentLocation.startsWith('/create?')) {
      return; // Already on create page, do nothing
    }

    // Push create page as a full-screen route (outside shell, so no bottom nav)
    context.push('/create');
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final dockSelectedIndex = _indexFromLocation(loc);
    final theme = Theme.of(context);

    final onDockTap = (int i) {
      switch (i) {
        case 0:
          widget.navigationShell.goBranch(0);
          break;
        case 1:
          _openCreate(context);
          break;
        case 2:
          widget.navigationShell.goBranch(1);
          break;
      }
    };

    return ProfilePushDrawerDockScope(
      obscuresDock: _profilePushDrawerObscuresDock,
      child: ListenableBuilder(
        listenable: _profilePushDrawerObscuresDock,
        builder: (context, _) {
          final hideDock = _profilePushDrawerObscuresDock.value &&
              loc.startsWith('/more');
          return Scaffold(
            extendBody: true,
            body: SafeArea(
              bottom: false,
              child: widget.navigationShell,
            ),
            bottomNavigationBar: loc.startsWith('/mono') ||
                    loc.startsWith('/profile/public') ||
                    loc.startsWith('/profile/notifications') ||
                    loc.startsWith('/profile/followers') ||
                    loc.startsWith('/profile/following')
                ? null
                : hideDock
                    ? null
                    : FloatingDockNavBar(
                        selectedIndex: dockSelectedIndex >= 0 ? dockSelectedIndex : 0,
                        onItemTapped: onDockTap,
                        theme: theme,
                      ),
          );
        },
      ),
    );
  }
}
