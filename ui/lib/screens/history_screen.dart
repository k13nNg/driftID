import 'package:flutter/material.dart';

import '../main.dart';
import '../services/history_store.dart';
import '../widgets/history_empty.dart';
import '../widgets/history_tile.dart';
import 'history_detail_screen.dart';

/// History tab (US-09): a scannable, most-recent-first list of saved
/// identifications, or a guidance empty state when there are none. Rebuilds
/// whenever the [HistoryStore] notifies (auto-save in T006, clear in T009).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.historyStore});

  final HistoryStore historyStore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: ListenableBuilder(
        listenable: historyStore,
        builder: (context, _) {
          final entries = historyStore.entries;
          if (entries.isEmpty) {
            return const HistoryEmpty();
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView.separated(
                key: const Key('history-list'),
                padding: const EdgeInsets.symmetric(
                  vertical: DriftSpacing.sm,
                  horizontal: DriftSpacing.md,
                ),
                itemCount: entries.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  // Reopen the full saved result with no API call (T008, US-10).
                  return HistoryTile(
                    entry: entry,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HistoryDetailScreen(entry: entry),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
