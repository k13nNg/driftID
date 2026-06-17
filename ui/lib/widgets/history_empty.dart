import 'package:flutter/material.dart';

import '../main.dart';

/// Empty-history guidance (US-09). Shown when there are no saved
/// identifications yet, explaining how entries get added so the History tab
/// never reads as broken. Kept visually flat per AGENTS.md.
class HistoryEmpty extends StatelessWidget {
  const HistoryEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DriftSpacing.lg),
        child: Semantics(
          label: 'No identifications yet',
          child: Column(
            key: const Key('history-empty'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: DriftSpacing.md),
              Text(
                'No identifications yet',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DriftSpacing.sm),
              Text(
                "Identify a car on the Search tab and it'll show up here "
                'automatically.',
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
