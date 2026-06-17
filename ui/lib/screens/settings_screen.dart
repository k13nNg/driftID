import 'package:flutter/material.dart';

import '../main.dart';

/// Settings tab. Minimal placeholder for T005 — a real settings feature set is
/// out of scope this sprint (see S002).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(DriftSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('About', style: theme.textTheme.titleLarge),
                const SizedBox(height: DriftSpacing.sm),
                Text(
                  'DriftID identifies a car\'s make and model from a photo.',
                  key: const Key('settings-about'),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
