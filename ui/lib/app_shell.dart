import 'package:flutter/material.dart';

import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/history_store.dart';
import 'services/settings_store.dart';

/// App shell hosting the three top-level sections behind a persistent bottom
/// [NavigationBar] (US-07). An [IndexedStack] keeps every tab's state alive, so
/// switching sections never triggers a route push or full reload — the Search
/// flow keeps its picked image / results when the user visits History and back.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.historyStore,
    required this.settingsStore,
  });

  /// Shared, app-lifetime store. Search appends to it (T006); History
  /// reads/mutates it (T007/T009).
  final HistoryStore historyStore;

  /// Shared, app-lifetime settings store (T013).
  final SettingsStore settingsStore;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Default landing section is Search (US-07).
  int _index = 0;

  void _onDestinationSelected(int index) {
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(historyStore: widget.historyStore),
          HistoryScreen(historyStore: widget.historyStore),
          SettingsScreen(settingsStore: widget.settingsStore),
        ],
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
