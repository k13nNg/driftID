import 'package:flutter/material.dart';

import '../main.dart';
import '../services/result_controller.dart';
import '../widgets/result_view.dart';

/// Result tab (US-14): the single host for every identification result, fresh
/// or reopened. Listens to [ResultController]; before anything is identified it
/// shows a flat empty state, and once a result is published it renders the
/// shared [ResultView] (with the saved badge for reopened History entries).
///
/// This screen never constructs or calls `ApiClient` — reopening a saved result
/// must not re-run inference (US-10). A permanent tab that auto-fills on a
/// successful identify (the shell switches to it) and on a History reopen.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.controller});

  /// Holds the active result; `null` ⇒ show the empty state.
  final ResultController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final current = controller.current;
          if (current == null) {
            return const _ResultEmpty();
          }
          return Align(
            key: const Key('result-screen'),
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(DriftSpacing.lg),
                child: ResultView(
                  bytes: current.bytes,
                  url: current.url,
                  predictions: current.predictions,
                  saved: current.saved,
                  savedAt: current.savedAt,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Flat guidance shown on the Result tab before any identification exists
/// (US-14), mirroring the History empty state so the tab never reads as broken.
class _ResultEmpty extends StatelessWidget {
  const _ResultEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DriftSpacing.lg),
        child: Semantics(
          label: 'No result yet',
          child: Column(
            key: const Key('result-empty'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insights_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: DriftSpacing.md),
              Text(
                'No result yet',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DriftSpacing.sm),
              Text(
                'Identify a car on the Search tab and the result will show up '
                'here.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
