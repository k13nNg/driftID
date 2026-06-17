import 'package:driftid_ui/services/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('SettingsStore loads default system theme when empty', () async {
    final store = SettingsStore();
    await store.load();
    expect(store.themeMode, ThemeMode.system);
  });

  test('SettingsStore saves and restores theme mode', () async {
    final store = SettingsStore();
    await store.load();
    expect(store.themeMode, ThemeMode.system);

    await store.setThemeMode(ThemeMode.dark);
    expect(store.themeMode, ThemeMode.dark);

    final reloaded = SettingsStore();
    await reloaded.load();
    expect(reloaded.themeMode, ThemeMode.dark);
  });
}
