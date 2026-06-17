import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/history_entry.dart';

/// One row in the history list (US-09): a small thumbnail, the top make/model
/// (+ year range), its confidence, and a relative timestamp. The whole row is
/// tappable to reopen the saved result (T008); a trailing delete control
/// removes just this entry (T009, US-11).
///
/// Reuses the existing [Prediction] formatting (US-06 carryover) and the shared
/// palette/spacing tokens; stays flat (no gradients/shadows) per AGENTS.md.
class HistoryTile extends StatelessWidget {
  const HistoryTile({
    super.key,
    required this.entry,
    this.onTap,
    this.onDelete,
  });

  final HistoryEntry entry;

  /// Wired in T008 to open the saved result; rendered tappable regardless.
  final VoidCallback? onTap;

  /// Wired in T009 to delete just this entry; the trailing delete control is
  /// only rendered when provided.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = entry.top;
    final title = top?.title ?? 'Unknown';
    final subtitle = top?.subtitle ?? '';
    final confidence = top?.confidencePercent ?? '';
    final when = formatRelativeTime(entry.createdAt);

    // Combine label + time so Playwright (T010) can target a specific entry.
    final semanticsLabel =
        [title, if (subtitle.isNotEmpty) subtitle, when].join(', ');

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: InkWell(
        key: Key('history-tile-${entry.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(kDriftRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: DriftSpacing.sm,
            horizontal: DriftSpacing.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Thumbnail(entry: entry),
              const SizedBox(width: DriftSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: DriftSpacing.xs),
                    Text(
                      when,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (confidence.isNotEmpty) ...[
                const SizedBox(width: DriftSpacing.sm),
                Text(
                  confidence,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (onDelete != null) ...[
                const SizedBox(width: DriftSpacing.xs),
                IconButton(
                  key: Key('delete-entry-${entry.id}'),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Fixed-size thumbnail for a saved entry. Decodes the stored data URL for
/// uploads and loads the remote URL otherwise, falling back to the same flat
/// car placeholder used by [ImagePreview] when an image can't be shown.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.entry});

  static const double _size = 56;

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(kDriftRadius),
        border: Border.all(color: const Color(0xFFCCCCCC)),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: _image(context),
    );
  }

  Widget _image(BuildContext context) {
    if (entry.source == HistorySource.url) {
      return Image.network(
        entry.imageRef,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(context),
      );
    }

    final bytes = _decodeDataUrl(entry.imageRef);
    if (bytes == null) return _placeholder(context);
    return Image.memory(
      bytes,
      width: _size,
      height: _size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Icon(
      Icons.directions_car_outlined,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}

/// Decodes the base64 payload of a `data:` URL, or returns null if it isn't one
/// (or is malformed) so the caller can fall back to a placeholder.
Uint8List? _decodeDataUrl(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma == -1 || !dataUrl.startsWith('data:')) return null;
  try {
    return base64Decode(dataUrl.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

/// Renders [time] as a compact, human-friendly relative string (US-09), e.g.
/// "Just now", "5m ago", "2h ago", "Yesterday", "3d ago", or an absolute date
/// for anything older than a week. [now] is injectable for deterministic tests.
String formatRelativeTime(DateTime time, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(time);

  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final month = months[time.month - 1];
  // Include the year only when it differs from the reference year.
  return time.year == reference.year
      ? '$month ${time.day}'
      : '$month ${time.day}, ${time.year}';
}
