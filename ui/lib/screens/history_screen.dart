import 'package:flutter/material.dart';

import '../main.dart';
import '../services/history_store.dart';
import '../widgets/history_empty.dart';
import '../widgets/history_tile.dart';

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
                  // Tapping a tile to reopen the full result is wired in T008.
                  return HistoryTile(entry: entries[index]);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
