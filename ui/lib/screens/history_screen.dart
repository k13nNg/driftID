import 'package:flutter/material.dart';

import '../main.dart';
import '../models/history_entry.dart';
import '../services/history_store.dart';
import '../services/result_controller.dart';
import '../widgets/history_empty.dart';
import '../widgets/history_tile.dart';

/// History tab (US-09): a scannable, most-recent-first list of saved
/// identifications, or a guidance empty state when there are none. Rebuilds
/// whenever the [HistoryStore] notifies (auto-save in T006, delete/clear in
/// T009). The app-bar "Clear all" action and per-tile delete control let users
/// manage what's stored on their device (US-11).
///
/// Tapping an entry reopens it in the shared Result tab (T016, US-10) — the
/// result is reconstructed from the stored entry and published to
/// [resultController] with **no** API call, then the shell switches to Result
/// via [onReopen].
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.historyStore,
    this.resultController,
    this.onReopen,
  });

  final HistoryStore historyStore;

  /// Where reopened results are published (T016). When null (e.g. a standalone
  /// widget test), tapping a tile is a no-op.
  final ResultController? resultController;

  /// Called after a reopen so the shell can switch to the Result tab (T016).
  final VoidCallback? onReopen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          ListenableBuilder(
            listenable: historyStore,
            builder: (context, _) {
              // Hidden when history is already empty — nothing to clear.
              if (historyStore.entries.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                key: const Key('clear-history'),
                onPressed: () => _confirmClearAll(context),
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: 'Clear all',
              );
            },
          ),
        ],
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
                    onTap: () => _reopen(entry),
                    // Delete just this entry; persists immediately (T009, US-11).
                    onDelete: () => _deleteEntry(context, entry.id),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  /// Reopens a saved entry into the shared Result tab (T016, US-10). The image
  /// (decoded upload bytes or remote URL) and predictions come straight from the
  /// stored [HistoryEntry] — no [ResultController] API call, no inference.
  void _reopen(HistoryEntry entry) {
    final controller = resultController;
    if (controller == null) return;
    controller.show(
      bytes: entry.imageBytes,
      url: entry.imageUrl,
      predictions: entry.predictions,
      saved: true,
      savedAt: entry.createdAt,
    );
    onReopen?.call();
  }

  /// Removes a single entry from the store (which persists immediately) and
  /// surfaces a brief confirmation. The list re-renders via [HistoryStore].
  void _deleteEntry(BuildContext context, String id) {
    final messenger = ScaffoldMessenger.of(context);
    historyStore.delete(id);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Removed from history')),
    );
  }

  /// Confirms before wiping the whole history (US-11). Confirming clears the
  /// store, which empties storage and shows the T007 empty state.
  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear all history?'),
          content: const Text(
            'This removes every saved identification from this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('confirm-clear'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await historyStore.clear();
    }
  }
}
