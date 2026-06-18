import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'services/history_store.dart';
import 'services/result_controller.dart';
import 'services/settings_store.dart';

void main() {
  runApp(const DriftIDApp());
}

/// Soft pastel palette (T004). Solid colors only — no gradients (AGENTS.md).
class DriftColors {
  const DriftColors._();

  static const Color thistle = Color(0xFFCDB4DB);
  static const Color pastelPetal = Color(0xFFFFC8DD);
  static const Color babyPink = Color(0xFFFFAFCC);
  static const Color icyBlue = Color(0xFFBDE0FE);
  static const Color skyBlue = Color(0xFFA2D2FF);

  /// Dark, high-contrast ink for text sitting on light pastel fills (US-06).
  static const Color ink = Color(0xFF2B2536);
}

/// Single spacing rhythm — reuse these instead of ad-hoc values.
class DriftSpacing {
  const DriftSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
}

/// One corner radius shared across preview, predictions, and error containers.
const double kDriftRadius = 12;

class DriftIDApp extends StatefulWidget {
  const DriftIDApp({
    super.key,
    this.historyStore,
    this.settingsStore,
    this.resultController,
  });

  /// Injectable for tests; defaults to a real [HistoryStore] in production.
  final HistoryStore? historyStore;

  /// Injectable for tests; defaults to a real [SettingsStore] in production.
  final SettingsStore? settingsStore;

  /// Injectable for tests; defaults to a real [ResultController] in production.
  final ResultController? resultController;

  @override
  State<DriftIDApp> createState() => _DriftIDAppState();
}

class _DriftIDAppState extends State<DriftIDApp> {
  late final HistoryStore _historyStore = widget.historyStore ?? HistoryStore();
  late final SettingsStore _settingsStore = widget.settingsStore ?? SettingsStore();
  late final ResultController _resultController =
      widget.resultController ?? ResultController();

  @override
  void initState() {
    super.initState();
    // Hydrate saved history from browser-local storage once on startup (US-08).
    _historyStore.load();
    _settingsStore.load();
  }

  @override
  void dispose() {
    if (widget.historyStore == null) _historyStore.dispose();
    if (widget.settingsStore == null) _settingsStore.dispose();
    if (widget.resultController == null) _resultController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settingsStore,
      builder: (context, _) {
        return MaterialApp(
          title: 'DriftID',
          debugShowCheckedModeBanner: false,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: _settingsStore.themeMode,
          home: AppShell(
            historyStore: _historyStore,
            settingsStore: _settingsStore,
            resultController: _resultController,
          ),
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: DriftColors.thistle,
      onPrimary: DriftColors.ink,
      primaryContainer: DriftColors.pastelPetal,
      onPrimaryContainer: DriftColors.ink,
      secondary: DriftColors.skyBlue,
      onSecondary: DriftColors.ink,
      secondaryContainer: DriftColors.icyBlue,
      onSecondaryContainer: DriftColors.ink,
      tertiary: DriftColors.babyPink,
      onTertiary: DriftColors.ink,
      tertiaryContainer: DriftColors.babyPink,
      onTertiaryContainer: DriftColors.ink,
      error: Color(0xFFB3261E),
      onError: Colors.white,
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      surface: Colors.white,
      onSurface: DriftColors.ink,
      surfaceContainerHighest: DriftColors.icyBlue,
      onSurfaceVariant: Color(0xFF574F61),
      outline: Color(0xFF8C8295),
      outlineVariant: Color(0xFFCFC6D6),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: DriftColors.thistle,
        foregroundColor: DriftColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DriftColors.thistle,
          foregroundColor: DriftColors.ink,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kDriftRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DriftColors.ink,
          side: const BorderSide(color: DriftColors.thistle),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kDriftRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kDriftRadius),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: DriftColors.thistle,
      onPrimary: DriftColors.ink,
      primaryContainer: Color(0xFF3D3545),
      onPrimaryContainer: Colors.white,
      secondary: DriftColors.skyBlue,
      onSecondary: DriftColors.ink,
      secondaryContainer: Color(0xFF2A3A4D),
      onSecondaryContainer: Colors.white,
      tertiary: DriftColors.babyPink,
      onTertiary: DriftColors.ink,
      tertiaryContainer: Color(0xFF402E38),
      onTertiaryContainer: Colors.white,
      error: Color(0xFFF2B8B5),
      onError: Color(0xFF601410),
      errorContainer: Color(0xFF8C1D18),
      onErrorContainer: Color(0xFFF9DEDC),
      surface: Color(0xFF1C1A22),
      onSurface: Colors.white,
      surfaceContainerHighest: Color(0xFF2E2B36),
      onSurfaceVariant: Color(0xFFCABFCF),
      outline: Color(0xFF968E9F),
      outlineVariant: Color(0xFF4B4554),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF1C1A22),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2E2B36),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DriftColors.thistle,
          foregroundColor: DriftColors.ink,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kDriftRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: DriftColors.thistle),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kDriftRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kDriftRadius),
        ),
      ),
    );
  }
}
