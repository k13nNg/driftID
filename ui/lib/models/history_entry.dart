import 'prediction.dart';

/// How the source image for an identification was provided.
enum HistorySource {
  upload,
  url;

  static HistorySource fromName(String? name) {
    return HistorySource.values.firstWhere(
      (s) => s.name == name,
      orElse: () => HistorySource.upload,
    );
  }
}

/// One saved identification (US-08). Holds everything needed to render the
/// history list (T007) and reopen the full result with **no** API call (T008):
/// a reference to the image, the full top-k [predictions], and when it ran.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.createdAt,
    required this.source,
    required this.imageRef,
    required this.predictions,
  });

  /// Unique, stable id (timestamp-based; see [HistoryEntry.now]).
  final String id;

  /// When the identification ran (US-08 timestamp).
  final DateTime createdAt;

  /// Whether [imageRef] is an uploaded data URL or a remote URL.
  final HistorySource source;

  /// A `data:` URL for uploads (downscaled) or the original remote URL.
  final String imageRef;

  /// Full top-k results so reopening needs no network (US-10).
  final List<Prediction> predictions;

  /// Top prediction, or `null` when (defensively) there are none.
  Prediction? get top => predictions.isEmpty ? null : predictions.first;

  /// Builds an entry stamped with the current time and a unique id.
  factory HistoryEntry.now({
    required HistorySource source,
    required String imageRef,
    required List<Prediction> predictions,
  }) {
    final createdAt = DateTime.now();
    return HistoryEntry(
      // Microsecond timestamp keeps ids unique and naturally sortable.
      id: createdAt.microsecondsSinceEpoch.toString(),
      createdAt: createdAt,
      source: source,
      imageRef: imageRef,
      predictions: predictions,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'source': source.name,
        'imageRef': imageRef,
        // Mirror the API/`Prediction.fromJson` shape so one model is persisted
        // and the existing label getters re-derive on load (S002 conventions).
        'predictions': predictions
            .map((p) => {'class': p.className, 'confidence': p.confidence})
            .toList(),
      };

  /// Rebuilds an entry from stored JSON. Returns `null` if a required field is
  /// missing or malformed so a single bad record can't crash the whole load.
  static HistoryEntry? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final imageRef = json['imageRef'];
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    if (id is! String || imageRef is! String || createdAt == null) {
      return null;
    }

    final rawPredictions = json['predictions'];
    final predictions = <Prediction>[];
    if (rawPredictions is List) {
      for (final item in rawPredictions) {
        if (item is Map<String, dynamic>) {
          predictions.add(Prediction.fromJson(item));
        }
      }
    }

    return HistoryEntry(
      id: id,
      createdAt: createdAt,
      source: HistorySource.fromName(json['source']?.toString()),
      imageRef: imageRef,
      predictions: predictions,
    );
  }
}
