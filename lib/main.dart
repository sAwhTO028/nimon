import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nimon/data/story_repo_mock.dart';
import 'package:nimon/features/home/home_screen.dart';
import 'package:nimon/features/mono/mono_screen.dart';
import 'package:nimon/features/settings/settings_screen.dart';
import 'package:nimon/features/library/library_screen.dart';
import 'package:nimon/features/library/following_writers_screen.dart';
import 'package:nimon/features/profile/profile_screen.dart';
import 'package:nimon/features/more/more_screen.dart';
import 'package:nimon/features/story/story_detail_screen.dart';
import 'package:nimon/features/writer/writer_screen.dart';
import 'package:nimon/features/auth/login_screen.dart';
import 'package:nimon/data/repo_singleton.dart';
import 'package:nimon/features/learn/learn_hub_screen.dart';
import 'package:nimon/models/story.dart';
import 'package:nimon/features/reader/reader_screen.dart';
import 'package:nimon/features/reader/episode_reader_screen.dart';
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
    // Create route is outside ShellRoute so it doesn't show bottom nav
    GoRoute(
      path: '/create',
      builder: (_, state) => CreateScreen(
        initialTab: state.uri.queryParameters['tab'],
      ),
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
          builder: (_, __) => const _MonoPlaceholderScreen(),
        ),
        GoRoute(
          path: '/create-mono',
          builder: (_, __) => const CreateMonoScreen(),
        ),
        GoRoute(
          path: '/library',
          builder: (_, __) => const LibraryScreen(),
          routes: [
            GoRoute(
              path: 'following-writers',
              builder: (_, __) => const FollowingWritersScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/more',
          builder: (_, __) => ProfileScreen(repo: repo),
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
          builder: (ctx, st) =>
              WriterScreen(repo: repo, storyId: st.pathParameters['id']!),
        ),
        GoRoute(
          path: '/learn/:id',
          builder: (ctx, st) => LearnHubScreen(),
        ),
        GoRoute(
          path: '/reader',
          builder: (ctx, st) {
            final ep = st.extra as Episode?;
            return EpisodeReaderScreen(episode: ep!);
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
  int _currentIndex = 0;

  int _indexFromLocation(String loc) {
    if (loc.startsWith('/mono')) return 1;
    if (loc.startsWith('/library')) return 2;
    if (loc.startsWith('/more') || loc.startsWith('/settings')) return 3;
    return 0; // Default to Home
  }

  void _openCreate(BuildContext context) {
    // Check if we're already on the create page to prevent duplicates
    final currentLocation = GoRouterState.of(context).uri.toString();
    if (currentLocation == '/create' || currentLocation.startsWith('/create?')) {
      return; // Already on create page, do nothing
    }
    
    // Push create page as a full-screen route (outside ShellRoute, so no bottom nav)
    context.push('/create');
  }

  @override
  void initState() {
    super.initState();
    // Initialize index based on current location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final loc = GoRouterState.of(context).uri.toString();
        setState(() {
          _currentIndex = _indexFromLocation(loc);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final idx = _indexFromLocation(loc);
    
    // Update current index if it changed
    if (idx != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentIndex = idx;
          });
        }
      });
    }

    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(child: widget.child),
      bottomNavigationBar: _CustomBottomNavBar(
        selectedIndex: _currentIndex,
        onItemTapped: (i) {
          switch (i) {
            case 0:
              context.go('/');
              setState(() => _currentIndex = 0);
              break;
            case 1:
              context.go('/mono');
              setState(() => _currentIndex = 1);
              break;
            case 2:
              // Create button - navigate but don't change selected index
              _openCreate(context);
              break;
            case 3:
              context.go('/library');
              setState(() => _currentIndex = 2);
              break;
            case 4:
              context.go('/more');
              setState(() => _currentIndex = 3);
              break;
          }
        },
        theme: theme,
      ),
    );
  }
}

/// Custom bottom navigation bar with 5 items including center Create button
class _CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final ThemeData theme;

  const _CustomBottomNavBar({
    required this.selectedIndex,
    required this.onItemTapped,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Home',
                isSelected: selectedIndex == 0,
                onTap: () => onItemTapped(0),
                colorScheme: colorScheme,
              ),
              _NavItem(
                icon: Icons.menu_book_outlined,
                selectedIcon: Icons.menu_book_rounded,
                label: 'Mono',
                isSelected: selectedIndex == 1,
                onTap: () => onItemTapped(1),
                colorScheme: colorScheme,
              ),
              _CreateNavItem(
                onTap: () => onItemTapped(2),
                colorScheme: colorScheme,
              ),
              _NavItem(
                icon: Icons.local_library_outlined,
                selectedIcon: Icons.local_library_rounded,
                label: 'Library',
                isSelected: selectedIndex == 2,
                onTap: () => onItemTapped(3),
                colorScheme: colorScheme,
              ),
              _NavItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: 'Profile',
                isSelected: selectedIndex == 3,
                onTap: () => onItemTapped(4),
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? colorScheme.primary : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? colorScheme.primary : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateNavItem extends StatelessWidget {
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _CreateNavItem({
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add_rounded,
              size: 24,
              color: colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder screen for Mono tab (reserved for future feature)
class _MonoPlaceholderScreen extends StatelessWidget {
  const _MonoPlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mono'),
      ),
      body: const Center(
        child: Text(
          'Mono Screen\nComing soon',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
