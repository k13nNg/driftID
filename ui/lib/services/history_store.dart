import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/history_entry.dart';

/// In-memory, most-recent-first cache of saved identifications backed by
/// browser-local storage (US-08). On web `SharedPreferencesAsync` writes to
/// `localStorage`, so history survives reloads and new sessions — and never
/// leaves the device (no server, no new API calls).
///
/// A [ChangeNotifier] so the History UI (T007) and manage/clear UI (T009) can
/// rebuild when entries change; the Search flow (T006) only calls [add].
class HistoryStore extends ChangeNotifier {
  // Private named field formals aren't permitted, so assign explicitly.
  // ignore: prefer_initializing_formals
  HistoryStore({SharedPreferencesAsync? prefs}) : _prefs = prefs;

  /// Versioned key — bump the suffix if [HistoryEntry] serialization changes.
  static const String storageKey = 'driftid.history.v1';

  /// Keep storage bounded; oldest entries beyond this are dropped on [add].
  static const int maxEntries = 50;

  // Created lazily on first use so constructing the store never touches the
  // platform plugin (which throws when unregistered, e.g. in widget tests).
  SharedPreferencesAsync? _prefs;
  SharedPreferencesAsync get _store => _prefs ??= SharedPreferencesAsync();

  List<HistoryEntry> _entries = const [];

  /// Saved entries, most-recent-first. Unmodifiable so callers can't bypass
  /// persistence by mutating the list directly.
  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  /// Loads persisted entries once at startup. Missing or corrupt data degrades
  /// gracefully to an empty history rather than throwing into the UI.
  Future<void> load() async {
    try {
      _entries = _decode(await _store.getString(storageKey));
    } catch (_) {
      _entries = const [];
    }
    notifyListeners();
  }

  /// Prepends [entry], caps the list, notifies listeners, then persists. The
  /// in-memory update happens first so the UI reflects the save immediately and
  /// never blocks on (or fails because of) storage.
  Future<void> add(HistoryEntry entry) async {
    final next = [entry, ..._entries];
    next.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _entries = next.length > maxEntries ? next.sublist(0, maxEntries) : next;
    notifyListeners();
    await _persist();
  }

  /// Removes the entry with [id] (exercised by the manage UI in T009).
  Future<void> delete(String id) async {
    _entries = _entries.where((e) => e.id != id).toList(growable: false);
    notifyListeners();
    await _persist();
  }

  /// Removes every entry (exercised by the clear-all UI in T009).
  Future<void> clear() async {
    _entries = const [];
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final payload = jsonEncode([for (final e in _entries) e.toJson()]);
      await _store.setString(storageKey, payload);
    } catch (_) {
      // Best-effort: storage failures must never surface as inference errors.
    }
  }

  static List<HistoryEntry> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final entries = <HistoryEntry>[];
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        final entry = HistoryEntry.fromJson(item);
        if (entry != null) entries.add(entry);
      }
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }
}
