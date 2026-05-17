import 'dart:async' show unawaited;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/features/mono/mono_reader_menu_origin.dart';
import 'package:nimon/features/mono/mono_search_screen.dart';
import 'package:nimon/features/mono/mono_screen.dart';
import 'package:nimon/features/profile/profile_push_drawer_scope.dart';
import 'package:nimon/features/profile/profile_screen.dart';
import 'package:nimon/features/profile/profile_trash_screen.dart';
import 'package:nimon/features/profile/profile_connections_screen.dart';
import 'package:nimon/features/profile/edit_profile_screen.dart';
import 'package:nimon/features/profile/public_creator_collection_detail_screen.dart';
import 'package:nimon/features/profile/public_folder_detail_screen.dart';
import 'package:nimon/features/profile/public_profile_screen.dart';
import 'package:nimon/features/profile/owner_creator_collection_detail_screen.dart';
import 'package:nimon/features/profile/share_profile_screen.dart';
import 'package:nimon/features/profile/share_public_profile_url.dart';
import 'package:nimon/features/profile/notifications_screen.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_session_expired_bridge.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/auth/auth_startup_routing.dart';
import 'package:nimon/features/auth/login_screen.dart';
import 'package:nimon/features/auth/register_screen.dart';
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
import 'package:nimon/features/create/creator_back_policy.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';
import 'package:nimon/features/create/story_creator_sentences_screen.dart';
import 'package:nimon/core/networking/connectivity_status.dart';
import 'package:nimon/core/theme.dart';
import 'package:nimon/features/settings/help_feedback_screen.dart';
import 'package:nimon/features/settings/settings_screen.dart';
import 'package:nimon/features/settings/app_locale_resolver.dart';
import 'package:nimon/features/settings/theme_mode_resolver.dart';
import 'package:nimon/features/settings/reading_text_scale.dart';
import 'package:nimon/features/settings/presentation/providers/user_preferences_notifier.dart';
import 'package:nimon/l10n/app_localizations.dart';
import 'package:nimon/ui/app_messenger.dart';
import 'package:nimon/ui/shell/floating_dock_tab_handler.dart';
import 'package:nimon/widgets/floating_dock_nav_bar.dart';

void main() {
  if (kDebugMode || kProfileMode) {
    debugPrint('[M20D api-base] ${RemoteBackendConfig.apiBaseUrl}');
  }

  // Temporary crash stack capture (remove when resolved).
  FlutterError.onError = (details) {
    debugPrint(
        '[NIMON_CRASH_STACK] FlutterError: ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint('[NIMON_CRASH_STACK] stack:\n${details.stack}');
    }
    // Preserve default behavior (prints + may terminate in debug).
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[NIMON_CRASH_STACK] PlatformDispatcher error: $error');
    debugPrint('[NIMON_CRASH_STACK] stack:\n$stack');
    // Return false so the error is not swallowed.
    return false;
  };

  runApp(const ProviderScope(child: NimonApp()));
}

GoRouter buildNimonGoRouter() {
  return GoRouter(
    navigatorKey: nimonAppNavigatorKey,
    initialLocation: '/startup',
    redirect: nimonAuthRedirect,
    routes: [
      GoRoute(
        path: '/startup',
        builder: (_, __) => const AuthStartupSplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/profile/public',
        // Query params: `userId` (canonical), optional `from=owner` preview banner,
        // optional legacy `creator` (debug/mock-only mock UI — see PublicProfileScreen).
        builder: (ctx, st) => PublicProfileScreen(
          ownerPreview: st.uri.queryParameters['from'] == 'owner',
          userId: st.uri.queryParameters['userId'],
          creatorHandle: st.uri.queryParameters['creator'],
        ),
        routes: [
          GoRoute(
            path: 'folder/:folderId',
            builder: (ctx, st) => PublicFolderDetailScreen(
              folderId: st.pathParameters['folderId']!,
            ),
          ),
          GoRoute(
            path: 'collections/detail',
            builder: (ctx, st) {
              final extra = st.extra;
              if (extra is! PublicCreatorCollectionDetailArgs) {
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Collection'),
                  ),
                  body: const Center(
                    child: Text('Missing collection.'),
                  ),
                );
              }
              return PublicCreatorCollectionDetailScreen(args: extra);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/profile/creator-collections/detail',
        builder: (ctx, st) {
          final extra = st.extra;
          if (extra is! OwnerCreatorCollectionDetailArgs) {
            return Scaffold(
              appBar: AppBar(title: const Text('Collection')),
              body: const Center(child: Text('Missing collection.')),
            );
          }
          return OwnerCreatorCollectionDetailScreen(args: extra);
        },
      ),
      GoRoute(
        path: '/profile/share',
        builder: (ctx, st) {
          final extra = st.extra;
          if (extra is ShareProfileScreenArgs) {
            final url = resolvePublicProfileShareUrl(
              explicitUrl: extra.explicitShareUrl,
              userId: extra.userId,
              handle: extra.handleLine,
            );
            return ShareProfileScreen(
              displayName: extra.displayName,
              handleLine: extra.handleLine,
              publicProfileUrl: url,
              avatarUrl: extra.avatarUrl,
            );
          }
          return ShareProfileScreen(
            displayName: 'Just4withYou',
            handleLine: 'just4withyou',
            publicProfileUrl: resolvePublicProfileShareUrl(
              explicitUrl: 'https://nimon.app/u/just4withyou',
              userId: null,
              handle: null,
            ),
            avatarUrl: null,
          );
        },
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const EditProfileScreen(),
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
        path: '/profile/trash',
        builder: (_, __) => const ProfileTrashScreen(),
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
      // V1: Create is outside ShellRoute so it doesn't show bottom nav.
      // Use [NoTransitionPage] so leaving create for `/mono` or `/more` does not
      // keep a Material-canvas transition page alive — that overlap was still
      // building creator subtrees and tripping duplicate keys / inactive elements.
      GoRoute(
        path: '/create',
        pageBuilder: (context, state) {
          final child = state.uri.queryParameters['editBasics'] == '1'
              ? CreateScreen(
                  initialTab: state.uri.queryParameters['tab'],
                  editFromReview: true,
                )
              : const StoryCreatorAddTabScreen();
          return NoTransitionPage<void>(
            key: state.pageKey,
            child: child,
          );
        },
      ),
      GoRoute(
        path: '/create/story',
        redirect: (_, st) {
          // Remove the standalone creator hub page from the product flow.
          // Keep subroutes (`/create/story/sentences`, etc.) working.
          if (st.uri.path == '/create/story' ||
              st.uri.path == '/create/story/') {
            return '/create';
          }
          return null;
        },
        builder: (_, __) => const SizedBox.shrink(),
        routes: [
          GoRoute(
            path: 'basics',
            pageBuilder: (context, state) {
              return NoTransitionPage<void>(
                key: state.pageKey,
                child: const StoryCreatorBasicsScreen(),
              );
            },
          ),
          GoRoute(
            path: 'sentences',
            pageBuilder: (context, state) {
              return NoTransitionPage<void>(
                key: state.pageKey,
                child: const StoryCreatorSentencesScreen(),
              );
            },
          ),
          GoRoute(
            path: 'learn',
            redirect: (context, state) {
              // Hard-remove standalone "Learn modules" hub from the creator flow.
              // Deep links to `/create/story/learn/...` still work via child redirects
              // (e.g. /learn/vocabulary -> sentences?panel=).
              if (state.uri.path == '/create/story/learn' ||
                  state.uri.path == '/create/story/learn/') {
                final d = state.uri.queryParameters['draftId']?.trim() ?? '';
                if (d.isNotEmpty) {
                  return '/create/story/sentences?draftId='
                      '${Uri.encodeQueryComponent(d)}';
                }
                return '/create/story/sentences';
              }
              return null;
            },
            builder: (_, __) => const SizedBox.shrink(),
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
                // Match create routes: no Material cross-fade when replacing a
                // full-screen /create/... page — reduces outgoing creator subtree
                // overlap with Mono during exit.
                pageBuilder: (context, state) {
                  final extra = state.extra;
                  final MonoFeedItem? initial =
                      extra is MonoFeedItem ? extra : null;
                  return NoTransitionPage<void>(
                    key: state.pageKey,
                    child: MonoScreen(
                      repo: repo,
                      initialItemOverride: initial,
                    ),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/more',
                pageBuilder: (context, state) {
                  final q = state.uri.queryParameters;
                  int? initialTab;
                  if (q['tab'] == 'saved' || q['saved'] == '1') {
                    initialTab = 2;
                  } else if (q['tab'] == 'workspace') {
                    initialTab = 1;
                  } else if (q['tab'] == 'uploaded') {
                    initialTab = 0;
                  }
                  final highlight = q['highlight']?.trim();
                  return NoTransitionPage<void>(
                    key: state.pageKey,
                    child: ProfileScreen(
                      repo: repo,
                      initialTabIndex: initialTab,
                      highlightDraftId:
                          highlight != null && highlight.isNotEmpty
                              ? highlight
                              : null,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class NimonApp extends ConsumerStatefulWidget {
  const NimonApp({super.key});

  @override
  ConsumerState<NimonApp> createState() => _NimonAppState();
}

class _NimonAppState extends ConsumerState<NimonApp> {
  late final GoRouter _router = buildNimonGoRouter();
  ProviderSubscription<AuthSessionState>? _authRouteSub;
  ProviderSubscription<AsyncValue<NimonConnectivityStatus>>? _connectivitySub;

  void _syncNetworkOnlineFromConnectivity(
      AsyncValue<NimonConnectivityStatus> v) {
    v.whenOrNull(
      data: (status) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        syncNimonNetworkOnlinePodFromStatus(ref.read, status);
      }),
    );
  }

  @override
  void initState() {
    super.initState();
    _authRouteSub = ref.listenManual<AuthSessionState>(
      authSessionProvider,
      (_, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _router.refresh();
          }
        });
      },
    );
    _connectivitySub = ref.listenManual<AsyncValue<NimonConnectivityStatus>>(
      nimonConnectivityStatusProvider,
      (previous, next) => _syncNetworkOnlineFromConnectivity(next),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncNetworkOnlineFromConnectivity(
        ref.read(nimonConnectivityStatusProvider),
      );
      AuthSessionExpiredBridge.instance.register(() async {
        await ref.read(authSessionProvider.notifier).forceSessionExpired();
        final ctx = nimonAppNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('Session expired — sign in again.')),
          );
          GoRouter.of(ctx).go('/login');
        }
      });
      unawaited(ref.read(authSessionProvider.notifier).restoreSession());
    });
  }

  @override
  void dispose() {
    _authRouteSub?.close();
    _connectivitySub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(userPreferencesNotifierProvider);
    final themeMode = resolveThemeModeFromPreference(prefs.prefs.themeMode);
    final code = prefs.prefs.appLocale;
    final Locale? appLocale = resolveMaterialLocaleFromAppLocaleCode(code);
    final readingScale = readingTextLinearScale(prefs.prefs.readingTextSize);

    return MaterialApp.router(
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: nimonRootScaffoldMessengerKey,
      theme: buildTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      locale: appLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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
        loc.startsWith('/profile/following') ||
        loc.startsWith('/profile/trash')) {
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

    ProviderScope.containerOf(context, listen: false)
        .read(creatorEntryChannelProvider.notifier)
        .state = creatorEntryChannelForShellPath(
      GoRouterState.of(context).uri.path,
    );
    // Push create page as a full-screen route (outside shell, so no bottom nav)
    context.push('/create');
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final dockSelectedIndex = _indexFromLocation(loc);
    final theme = Theme.of(context);

    void onDockTap(int i) {
      unawaited(
        handleFloatingDockTabSelection(
          context,
          navigationShell: widget.navigationShell,
          index: i,
          openCreate: _openCreate,
        ),
      );
    }

    return ProfilePushDrawerDockScope(
      obscuresDock: _profilePushDrawerObscuresDock,
      child: ListenableBuilder(
        listenable: _profilePushDrawerObscuresDock,
        builder: (context, _) {
          final hideDock =
              _profilePushDrawerObscuresDock.value && loc.startsWith('/more');
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
                    loc.startsWith('/profile/following') ||
                    loc.startsWith('/profile/trash')
                ? null
                : hideDock
                    ? null
                    : FloatingDockNavBar(
                        selectedIndex:
                            dockSelectedIndex >= 0 ? dockSelectedIndex : 0,
                        onItemTapped: onDockTap,
                        theme: theme,
                      ),
          );
        },
      ),
    );
  }
}
