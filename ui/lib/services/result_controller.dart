import 'package:flutter/foundation.dart';

import '../models/prediction.dart';

/// The result currently shown by the Result tab (T016) — either a fresh
/// identification or a reopened saved entry from History. Reopened results carry
/// [saved]/[savedAt] so the shared `ResultView` can render the saved badge
/// (US-10); fresh results leave [saved] false.
@immutable
class ActiveResult {
  const ActiveResult({
    this.bytes,
    this.url,
    this.predictions = const [],
    this.saved = false,
    this.savedAt,
  });

  /// Picked image bytes (uploads / decoded saved uploads); preferred over [url].
  final Uint8List? bytes;

  /// Remote image URL (URL submissions / saved URL entries).
  final String? url;

  /// Full top-k results to render (US-03).
  final List<Prediction> predictions;

  /// Whether this is a reopened saved result rather than a fresh run (US-10).
  final bool saved;

  /// When a saved result was originally identified (drives the badge text).
  final DateTime? savedAt;
}

/// Holds the single result the Result tab displays (T016). A [ChangeNotifier]
/// so `ResultScreen` (and the shell's auto-switch) rebuild when the active
/// result changes. `null` ⇒ nothing identified yet, so the tab shows its empty
/// state. This controller never calls the API — reopening a saved result must
/// not re-run inference (US-10).
class ResultController extends ChangeNotifier {
  ActiveResult? _current;

  /// The active result, or `null` when there's nothing to show.
  ActiveResult? get current => _current;

  /// Whether a result is currently available to display.
  bool get hasResult => _current != null;

  /// Publishes a result to the Result tab and notifies listeners. A fresh
  /// identification leaves [saved] false; a History reopen passes
  /// `saved: true` with the original [savedAt].
  void show({
    Uint8List? bytes,
    String? url,
    List<Prediction> predictions = const [],
    bool saved = false,
    DateTime? savedAt,
  }) {
    _current = ActiveResult(
      bytes: bytes,
      url: url,
      predictions: predictions,
      saved: saved,
      savedAt: savedAt,
    );
    notifyListeners();
  }

  /// Clears the active result so the Result tab returns to its empty state.
  void clear() {
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }
}
