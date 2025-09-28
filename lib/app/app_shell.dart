import 'package:flutter/material.dart';
import '../features/auth/login_screen.dart';
import '../features/home/home_screen.dart';
import '../features/mono/mono_screen.dart';
import '../features/settings/settings_screen.dart';
import '../data/repo_singleton.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    // Login → Guest >> goes Home (UI-only)
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => _AppScaffold(idx: _idx, setIdx: (i) => setState(()=>_idx=i)),
      ),
    );
  }
}

class _AppScaffold extends StatelessWidget {
  final int idx;
  final ValueChanged<int> setIdx;
  const _AppScaffold({required this.idx, required this.setIdx});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: idx,
        children: [
          HomeScreen(repo: repo),
          MonoScreen(repo: repo),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: setIdx,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Mono'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Setting'),
        ],
      ),
    );
  }
}
