import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/prediction.dart';
import 'history_tile.dart' show formatRelativeTime;
import 'image_preview.dart';
import 'prediction_list.dart';

/// Shared result presentation (T008): an [ImagePreview] of the identified image
/// followed by the top-k [PredictionList]. Used by both a fresh identification
/// (Search) and a reopened saved result (history detail) so the two views look
/// identical — same top-prediction emphasis and rows (US-03/US-06/US-10).
///
/// When [saved] is true a flat badge marks the view as a past result and, when
/// [savedAt] is supplied, says when it was originally identified.
class ResultView extends StatelessWidget {
  const ResultView({
    super.key,
    this.bytes,
    this.url,
    this.predictions = const [],
    this.saved = false,
    this.savedAt,
  });

  /// Picked image bytes (uploads); takes precedence over [url] in the preview.
  final Uint8List? bytes;

  /// Remote image URL (URL submissions).
  final String? url;

  /// Full top-k results; the list renders only when non-empty.
  final List<Prediction> predictions;

  /// Whether this is a reopened saved result (shows the saved badge, US-10).
  final bool saved;

  /// When the saved result was originally identified (drives the badge text).
  final DateTime? savedAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (saved) ...[
          _SavedBadge(savedAt: savedAt),
          const SizedBox(height: DriftSpacing.md),
        ],
        ImagePreview(bytes: bytes, url: url),
        if (predictions.isNotEmpty) ...[
          const SizedBox(height: DriftSpacing.lg),
          PredictionList(predictions: predictions),
        ],
      ],
    );
  }
}

/// Flat marker that the result on screen is a saved past identification rather
/// than a fresh run (US-10). Carries a stable `Key`/`Semantics` for automation.
class _SavedBadge extends StatelessWidget {
  const _SavedBadge({this.savedAt});

  final DateTime? savedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = savedAt == null ? null : formatRelativeTime(savedAt!);
    final label =
        when == null ? 'Saved result' : 'Saved result · Identified $when';

    return Semantics(
      label: 'Saved result',
      child: Container(
        key: const Key('saved-result'),
        padding: const EdgeInsets.symmetric(
          vertical: DriftSpacing.sm,
          horizontal: DriftSpacing.md,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(kDriftRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 18,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: DriftSpacing.sm),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
