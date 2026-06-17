import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/history_entry.dart';
import '../widgets/result_view.dart';

/// Reopened saved result (US-10): the same full result view as a fresh
/// identification — image preview + complete top-k list — reconstructed entirely
/// from the stored [HistoryEntry]. This screen intentionally does **not** import
/// or construct [ApiClient]; reopening never re-runs inference.
class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({super.key, required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    // Uploads are stored as a data URL → decode back to bytes for the preview;
    // URL submissions keep their remote reference. No network call either way.
    final bytes =
        entry.source == HistorySource.upload ? _decodeDataUrl(entry.imageRef) : null;
    final url = entry.source == HistorySource.url ? entry.imageRef : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved result'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DriftSpacing.lg),
            child: ResultView(
              bytes: bytes,
              url: url,
              predictions: entry.predictions,
              saved: true,
              savedAt: entry.createdAt,
            ),
          ),
        ),
      ),
    );
  }
}

/// Decodes the base64 payload of a `data:` URL, or returns null when it isn't
/// one (or is malformed) so [ResultView] falls back to the image placeholder.
Uint8List? _decodeDataUrl(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma == -1 || !dataUrl.startsWith('data:')) return null;
  try {
    return base64Decode(dataUrl.substring(comma + 1));
  } catch (_) {
    return null;
  }
}
