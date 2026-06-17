import 'dart:convert';

import 'package:driftid_ui/models/history_entry.dart';
import 'package:driftid_ui/models/prediction.dart';
import 'package:driftid_ui/services/history_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  HistoryEntry sampleEntry({
    required String id,
    required DateTime at,
    HistorySource source = HistorySource.upload,
  }) {
    return HistoryEntry(
      id: id,
      createdAt: at,
      source: source,
      imageRef: 'data:image/jpeg;base64,AAAA',
      predictions: const [
        Prediction(className: 'audi_a7-gen_2010_2014', confidence: 0.9),
        Prediction(className: 'bmw_m3', confidence: 0.05),
      ],
    );
  }

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('absent storage loads to an empty history', () async {
    final store = HistoryStore();
    await store.load();
    expect(store.entries, isEmpty);
  });

  test('add persists and survives a fresh store (reload/session)', () async {
    final store = HistoryStore();
    await store.load();
    await store.add(sampleEntry(id: '1', at: DateTime(2026, 1, 1)));

    // A brand-new store instance reads the same backing storage.
    final reloaded = HistoryStore();
    await reloaded.load();
    expect(reloaded.entries, hasLength(1));
    expect(reloaded.entries.first.id, '1');
    expect(reloaded.entries.first.top?.title, 'Audi A7');
    expect(reloaded.entries.first.predictions, hasLength(2));
  });

  test('entries are ordered most-recent-first', () async {
    final store = HistoryStore();
    await store.load();
    await store.add(sampleEntry(id: 'old', at: DateTime(2026, 1, 1)));
    await store.add(sampleEntry(id: 'new', at: DateTime(2026, 6, 1)));

    expect(store.entries.map((e) => e.id).toList(), ['new', 'old']);
  });

  test('history is capped at maxEntries', () async {
    final store = HistoryStore();
    await store.load();
    for (var i = 0; i < HistoryStore.maxEntries + 10; i++) {
      await store.add(sampleEntry(id: '$i', at: DateTime(2026, 1, 1, 0, i)));
    }
    expect(store.entries, hasLength(HistoryStore.maxEntries));
  });

  test('delete and clear remove entries', () async {
    final store = HistoryStore();
    await store.load();
    await store.add(sampleEntry(id: 'a', at: DateTime(2026, 1, 1)));
    await store.add(sampleEntry(id: 'b', at: DateTime(2026, 2, 1)));

    await store.delete('a');
    expect(store.entries.map((e) => e.id), ['b']);

    await store.clear();
    expect(store.entries, isEmpty);
  });

  test('corrupt stored data degrades gracefully to empty', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString(HistoryStore.storageKey, 'not json at all {');

    final store = HistoryStore();
    await store.load();
    expect(store.entries, isEmpty);
  });

  test('a single malformed entry is skipped, valid ones kept', () async {
    final prefs = SharedPreferencesAsync();
    final payload = jsonEncode([
      {'garbage': true},
      {
        'id': 'ok',
        'createdAt': DateTime(2026, 3, 1).toIso8601String(),
        'source': 'url',
        'imageRef': 'https://example.com/car.jpg',
        'predictions': [
          {'class': 'audi_a7-gen_2010_2014', 'confidence': 0.9},
        ],
      },
    ]);
    await prefs.setString(HistoryStore.storageKey, payload);

    final store = HistoryStore();
    await store.load();
    expect(store.entries, hasLength(1));
    expect(store.entries.first.id, 'ok');
    expect(store.entries.first.source, HistorySource.url);
  });
}
