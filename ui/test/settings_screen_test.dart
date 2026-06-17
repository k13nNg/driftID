import 'package:driftid_ui/screens/settings_screen.dart';
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

  Future<void> pumpScreen(WidgetTester tester, SettingsStore store) {
    return tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(settingsStore: store),
      ),
    );
  }

  testWidgets('SettingsScreen displays theme options and about blurb',
      (WidgetTester tester) async {
    final store = SettingsStore();
    await store.load();
    await pumpScreen(tester, store);

    expect(find.text('Theme'), findsOneWidget);
    expect(find.byKey(const Key('settings-theme')), findsOneWidget);
    expect(find.byKey(const Key('theme-light')), findsOneWidget);
    expect(find.byKey(const Key('theme-dark')), findsOneWidget);
    expect(find.byKey(const Key('theme-system')), findsOneWidget);

    expect(find.text('About'), findsOneWidget);
    expect(find.byKey(const Key('settings-about')), findsOneWidget);
  });

  testWidgets('Tapping a theme option updates the store',
      (WidgetTester tester) async {
    final store = SettingsStore();
    await store.load();
    await pumpScreen(tester, store);

    expect(store.themeMode, ThemeMode.system);

    // Tap Light option
    await tester.tap(find.byKey(const Key('theme-light')));
    await tester.pumpAndSettle();

    expect(store.themeMode, ThemeMode.light);

    // Tap Dark option
    await tester.tap(find.byKey(const Key('theme-dark')));
    await tester.pumpAndSettle();

    expect(store.themeMode, ThemeMode.dark);
  });
}
