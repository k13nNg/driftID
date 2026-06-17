import 'package:flutter/material.dart';

import '../models/prediction.dart';

/// Top-k results ordered by confidence (US-03). The first row is visually
/// emphasized as the best guess; remaining rows are listed compactly with a
/// confidence percentage (US-06).
class PredictionList extends StatelessWidget {
  const PredictionList({super.key, required this.predictions});

  final List<Prediction> predictions;

  @override
  Widget build(BuildContext context) {
    if (predictions.isEmpty) {
      return const SizedBox.shrink();
    }

    final top = predictions.first;
    final rest = predictions.skip(1).toList();

    return Semantics(
      label: 'Prediction results',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopPrediction(prediction: top),
          if (rest.isNotEmpty) const SizedBox(height: 12),
          for (final p in rest) _PredictionRow(prediction: p),
        ],
      ),
    );
  }
}

class _TopPrediction extends StatelessWidget {
  const _TopPrediction({required this.prediction});

  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('top-prediction'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Best match', style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  prediction.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (prediction.subtitle.isNotEmpty)
                  Text(prediction.subtitle, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          Text(
            prediction.confidencePercent,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionRow extends StatelessWidget {
  const _PredictionRow({required this.prediction});

  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: prediction.title,
                children: [
                  if (prediction.subtitle.isNotEmpty)
                    TextSpan(
                      text: '  ${prediction.subtitle}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          Text(
            prediction.confidencePercent,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
