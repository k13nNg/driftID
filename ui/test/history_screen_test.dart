import 'package:driftid_ui/models/history_entry.dart';
import 'package:driftid_ui/models/prediction.dart';
import 'package:driftid_ui/screens/history_screen.dart';
import 'package:driftid_ui/services/history_store.dart';
import 'package:driftid_ui/widgets/history_tile.dart';
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

  HistoryEntry entry({
    required String id,
    required DateTime at,
    HistorySource source = HistorySource.url,
  }) {
    return HistoryEntry(
      id: id,
      createdAt: at,
      source: source,
      imageRef: 'https://example.com/$id.jpg',
      predictions: const [
        Prediction(className: 'audi_a7-gen_2010_2014', confidence: 0.9),
        Prediction(className: 'bmw_m3', confidence: 0.05),
      ],
    );
  }

  Future<void> pumpScreen(WidgetTester tester, HistoryStore store) {
    return tester.pumpWidget(
      MaterialApp(home: HistoryScreen(historyStore: store)),
    );
  }

  testWidgets('empty history shows guidance, not the list', (tester) async {
    final store = HistoryStore();
    await store.load();
    await pumpScreen(tester, store);

    expect(find.byKey(const Key('history-empty')), findsOneWidget);
    expect(find.byKey(const Key('history-list')), findsNothing);
    expect(find.text('No identifications yet'), findsOneWidget);
  });

  testWidgets('populated history renders a tile per entry with label + '
      'confidence, most-recent-first', (tester) async {
    final store = HistoryStore();
    await store.load();
    await store.add(entry(id: 'old', at: DateTime(2026, 1, 1)));
    await store.add(entry(id: 'new', at: DateTime(2026, 6, 1)));
    await pumpScreen(tester, store);

    expect(find.byKey(const Key('history-list')), findsOneWidget);
    expect(find.byKey(const Key('history-empty')), findsNothing);
    expect(find.byKey(const Key('history-tile-new')), findsOneWidget);
    expect(find.byKey(const Key('history-tile-old')), findsOneWidget);

    // Reused Prediction formatting (US-06 carryover).
    expect(find.text('Audi A7'), findsNWidgets(2));
    expect(find.text('90.0%'), findsNWidgets(2));

    // Most-recent-first: the newest tile is positioned above the oldest.
    final newY = tester.getTopLeft(find.byKey(const Key('history-tile-new'))).dy;
    final oldY = tester.getTopLeft(find.byKey(const Key('history-tile-old'))).dy;
    expect(newY, lessThan(oldY));
  });

  testWidgets('the list rebuilds when the store changes', (tester) async {
    final store = HistoryStore();
    await store.load();
    await pumpScreen(tester, store);
    expect(find.byKey(const Key('history-empty')), findsOneWidget);

    await store.add(entry(id: 'a', at: DateTime(2026, 6, 1)));
    await tester.pump();

    expect(find.byKey(const Key('history-empty')), findsNothing);
    expect(find.byKey(const Key('history-tile-a')), findsOneWidget);
  });

  testWidgets('deleting a single entry removes its tile and persists (US-11)',
      (tester) async {
    final store = HistoryStore();
    await store.load();
    await store.add(entry(id: 'keep', at: DateTime(2026, 1, 1)));
    await store.add(entry(id: 'drop', at: DateTime(2026, 6, 1)));
    await pumpScreen(tester, store);

    await tester.tap(find.byKey(const Key('delete-entry-drop')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history-tile-drop')), findsNothing);
    expect(find.byKey(const Key('history-tile-keep')), findsOneWidget);
    expect(find.text('Removed from history'), findsOneWidget);
    // Persisted immediately: a fresh store reloads only the kept entry.
    final reloaded = HistoryStore();
    await reloaded.load();
    expect(reloaded.entries.map((e) => e.id), const ['keep']);
  });

  testWidgets('clear-all is hidden when history is empty (US-11)',
      (tester) async {
    final store = HistoryStore();
    await store.load();
    await pumpScreen(tester, store);

    expect(find.byKey(const Key('clear-history')), findsNothing);
  });

  testWidgets('clear-all confirms, empties the store, and shows empty state '
      '(US-11)', (tester) async {
    final store = HistoryStore();
    await store.load();
    await store.add(entry(id: 'a', at: DateTime(2026, 6, 1)));
    await store.add(entry(id: 'b', at: DateTime(2026, 6, 2)));
    await pumpScreen(tester, store);

    // Cancelling the confirmation leaves history intact.
    await tester.tap(find.byKey(const Key('clear-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-list')), findsOneWidget);

    // Confirming clears everything and falls back to the empty state.
    await tester.tap(find.byKey(const Key('clear-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-clear')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history-empty')), findsOneWidget);
    expect(find.byKey(const Key('clear-history')), findsNothing);

    final reloaded = HistoryStore();
    await reloaded.load();
    expect(reloaded.entries, isEmpty);
  });

  group('formatRelativeTime', () {
    final now = DateTime(2026, 6, 16, 12, 0);

    test('recent times', () {
      expect(formatRelativeTime(now, now: now), 'Just now');
      expect(
          formatRelativeTime(now.subtract(const Duration(minutes: 5)), now: now),
          '5m ago');
      expect(formatRelativeTime(now.subtract(const Duration(hours: 2)), now: now),
          '2h ago');
      expect(formatRelativeTime(now.subtract(const Duration(days: 1)), now: now),
          'Yesterday');
      expect(formatRelativeTime(now.subtract(const Duration(days: 3)), now: now),
          '3d ago');
    });

    test('older than a week falls back to a date', () {
      expect(formatRelativeTime(DateTime(2026, 1, 5), now: now), 'Jan 5');
      expect(formatRelativeTime(DateTime(2025, 12, 25), now: now),
          'Dec 25, 2025');
    });
  });
}
