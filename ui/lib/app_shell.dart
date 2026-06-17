import 'package:flutter/material.dart';

import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';

/// App shell hosting the three top-level sections behind a persistent bottom
/// [NavigationBar] (US-07). An [IndexedStack] keeps every tab's state alive, so
/// switching sections never triggers a route push or full reload — the Search
/// flow keeps its picked image / results when the user visits History and back.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Default landing section is Search (US-07).
  int _index = 0;

  static const List<Widget> _sections = [
    HomeScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  void _onDestinationSelected(int index) {
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _sections,
      ),
      bottomNavigationBar: NavigationBar(
        key: const Key('app-nav-bar'),
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            key: Key('nav-search'),
            icon: Icon(Icons.search),
            label: 'Search',
            tooltip: 'Search tab',
          ),
          NavigationDestination(
            key: Key('nav-history'),
            icon: Icon(Icons.history),
            label: 'History',
            tooltip: 'History tab',
          ),
          NavigationDestination(
            key: Key('nav-settings'),
            icon: Icon(Icons.settings),
            label: 'Settings',
            tooltip: 'Settings tab',
          ),
        ],
      ),
    );
  }
}
