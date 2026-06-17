import 'package:flutter/material.dart';

import '../main.dart';

/// History tab. Placeholder destination for T005 — the real list of saved
/// identifications (thumbnail, label, confidence, time) is built in T007.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(DriftSpacing.lg),
          child: Semantics(
            child: Text(
              'No history yet',
              key: const Key('history-empty'),
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
      ),
    );
  }
}
