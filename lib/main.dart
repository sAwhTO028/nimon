import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/data/story_repo_mock.dart';
import 'package:nimon/features/home/home_screen.dart';
import 'package:nimon/features/mono/mono_screen.dart';
import 'package:nimon/features/settings/settings_screen.dart';
import 'package:nimon/features/story/story_detail_screen.dart';
import 'package:nimon/features/writer/writer_screen.dart';
import 'package:nimon/features/auth/login_screen.dart';
import 'package:nimon/data/repo_singleton.dart';
import 'package:nimon/features/learn/learn_hub_screen.dart';
import 'package:nimon/models/story.dart';
import 'package:nimon/features/reader/reader_screen.dart';
import 'package:nimon/create_mono/create_mono_screen.dart';
import 'package:nimon/features/create/create_screen.dart';

void main() => runApp(const ProviderScope(child: NimonApp()));

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => HomeScreen(repo: repo),
        ),
        GoRoute(
          path: '/mono',
          builder: (_, __) => MonoScreen(repo: repo),
        ),
        GoRoute(
          path: '/create-mono',
          builder: (_, __) => const CreateMonoScreen(),
        ),
        GoRoute(
          path: '/create',
          builder: (_, state) => CreateScreen(
            initialTab: state.uri.queryParameters['tab'],
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/story/:id',
          builder: (ctx, st) => StoryDetailScreen(
            repo: repo,
            storyId: st.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/story/:id/write',
          builder: (ctx, st) => WriterScreen(
              repo: repo,
              storyId: st.pathParameters['id']!),
        ),
        GoRoute(
          path: '/learn/:id',
          builder: (ctx, st) => LearnHubScreen(),
        ),
        GoRoute(
          path: '/reader',
          builder: (ctx, st) {
            final ep = st.extra as Episode?;
            return ReaderScreen(episode: ep!);
          },
        ),
      ],
    ),
  ],
);

class NimonApp extends StatelessWidget {
  const NimonApp({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff5b86e5)),
      textTheme: GoogleFonts.interTextTheme(),
      useMaterial3: true,
    );
    return MaterialApp.router(
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      theme: theme,
    );
  }
}

class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _indexFromLocation(String loc) {
    if (loc.startsWith('/mono')) return 1;
    if (loc.startsWith('/settings')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _indexFromLocation(GoRouterState.of(context).uri.toString());
    
    return Scaffold(
      body: SafeArea(child: widget.child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/mono');
              break;
            case 2:
              context.go('/settings');
              break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Mono'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Setting'),
        ],
      ),
    );
  }
}
