import 'package:flutter/material.dart';

import '../main.dart';
import '../services/settings_store.dart';

/// Settings tab (T013). Theme control + About blurb.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settingsStore});

  final SettingsStore settingsStore;

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
          child: ListView(
            padding: const EdgeInsets.all(DriftSpacing.lg),
            children: [
              Text('Theme', style: theme.textTheme.titleLarge),
              const SizedBox(height: DriftSpacing.sm),
              ListenableBuilder(
                listenable: settingsStore,
                builder: (context, _) {
                  return SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      key: const Key('settings-theme'),
                      segments: const <ButtonSegment<ThemeMode>>[
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.light,
                          label: Text('Light', key: Key('theme-light')),
                          icon: Icon(Icons.light_mode),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.dark,
                          label: Text('Dark', key: Key('theme-dark')),
                          icon: Icon(Icons.dark_mode),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.system,
                          label: Text('System', key: Key('theme-system')),
                          icon: Icon(Icons.brightness_auto),
                        ),
                      ],
                      selected: <ThemeMode>{settingsStore.themeMode},
                      onSelectionChanged: (Set<ThemeMode> newSelection) {
                        settingsStore.setThemeMode(newSelection.first);
                      },
                      showSelectedIcon: false,
                    ),
                  );
                },
              ),
              const SizedBox(height: DriftSpacing.lg),
              const Divider(),
              const SizedBox(height: DriftSpacing.lg),
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
    );
  }
}
