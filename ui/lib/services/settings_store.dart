import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory, persisted theme preference store (T012). Backed by
/// browser-local storage (SharedPreferencesAsync), so the choice survives
/// reloads and new sessions.
///
/// A [ChangeNotifier] so the Settings UI (T013) and MaterialApp can rebuild
/// when the theme preference changes.
class SettingsStore extends ChangeNotifier {
  // Private named field formals aren't permitted, so assign explicitly.
  // ignore: prefer_initializing_formals
  SettingsStore({SharedPreferencesAsync? prefs}) : _prefs = prefs;

  /// Versioned storage key.
  static const String storageKey = 'driftid.settings.theme_mode.v1';

  // Created lazily on first use so constructing the store never touches the
  // platform plugin (which throws when unregistered, e.g. in widget tests).
  SharedPreferencesAsync? _prefs;
  SharedPreferencesAsync get _store => _prefs ??= SharedPreferencesAsync();

  ThemeMode _themeMode = ThemeMode.system;

  /// The active theme mode preference.
  ThemeMode get themeMode => _themeMode;

  /// Loads the persisted theme preference once at startup. Missing or corrupt
  /// data degrades gracefully to [ThemeMode.system] rather than throwing.
  Future<void> load() async {
    try {
      final value = await _store.getString(storageKey);
      _themeMode = _parseThemeMode(value);
    } catch (_) {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  /// Updates the theme mode in-memory, notifies listeners immediately, then
  /// persists the value best-effort.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final value = _serializeThemeMode(_themeMode);
      await _store.setString(storageKey, value);
    } catch (_) {
      // Best-effort: storage failures must never surface in the UI.
    }
  }

  static ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _serializeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
