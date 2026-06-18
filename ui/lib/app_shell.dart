import 'package:flutter/material.dart';

import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/result_screen.dart';
import 'screens/settings_screen.dart';
import 'services/history_store.dart';
import 'services/result_controller.dart';
import 'services/settings_store.dart';

/// App shell hosting the four top-level sections behind a persistent bottom
/// [NavigationBar] (US-07). An [IndexedStack] keeps every tab's state alive, so
/// switching sections never triggers a route push or full reload.
///
/// Destinations are fixed in order **Search / Result / History / Settings**
/// (T016, US-14) — static indices, no dynamic add/remove. Search stays the
/// default landing section. The Result tab is permanent: it shows an empty
/// state until a result exists, and a successful identification (or a History
/// reopen) auto-switches to it via [_showResult].
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.historyStore,
    required this.settingsStore,
    required this.resultController,
  });

  /// Shared, app-lifetime store. Search appends to it (T006); History
  /// reads/mutates it (T007/T009).
  final HistoryStore historyStore;

  /// Shared, app-lifetime settings store (T013).
  final SettingsStore settingsStore;

  /// Shared, app-lifetime result surface (T016). Search publishes fresh results
  /// and History publishes reopened ones into it; the Result tab renders it.
  final ResultController resultController;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Fixed destination indices (Search / Result / History / Settings).
  static const int _searchIndex = 0;
  static const int _resultIndex = 1;

  // Default landing section is Search (US-07).
  int _index = _searchIndex;

  void _onDestinationSelected(int index) {
    setState(() => _index = index);
  }

  /// Auto-switches to the permanent Result tab after a result is published
  /// (fresh identify or History reopen).
  void _showResult() {
    setState(() => _index = _resultIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            historyStore: widget.historyStore,
            resultController: widget.resultController,
            onResult: _showResult,
          ),
          ResultScreen(controller: widget.resultController),
          HistoryScreen(
            historyStore: widget.historyStore,
            resultController: widget.resultController,
            onReopen: _showResult,
          ),
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
            key: Key('nav-result'),
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Result',
            tooltip: 'Result tab',
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
