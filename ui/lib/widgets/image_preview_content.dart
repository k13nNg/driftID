import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../main.dart';

/// Single source of truth for rendering a previewed image (T018).
///
/// Given picked [bytes] (uploads) or a remote [url] (URL submissions) it shows
/// the image with the given [fit], a loading indicator while a network image
/// fetches, and a flat car placeholder when there's nothing to show or a URL
/// fails to load. Previewing makes no API/inference call — a URL is rendered by
/// a plain [Image.network].
///
/// Callers supply their own surrounding surface (e.g. the image card or the
/// neutral grey preview container); this widget only renders the content so the
/// card, History thumbnails, and the Result view all preview identically.
class ImagePreviewContent extends StatelessWidget {
  const ImagePreviewContent({
    super.key,
    this.bytes,
    this.url,
    this.fit = BoxFit.contain,
    this.compact = false,
    this.emptyMessage = 'No image selected',
    this.errorMessage = 'Preview unavailable',
  });

  /// Raw bytes of a picked file (takes precedence over [url]).
  final Uint8List? bytes;

  /// A remote image URL.
  final String? url;

  /// How the image fills its surface (card → [BoxFit.contain], history
  /// thumbnail → [BoxFit.cover]).
  final BoxFit fit;

  /// When true the placeholder is icon-only (for small thumbnails); otherwise
  /// it pairs the icon with a message.
  final bool compact;

  /// Placeholder text shown when no image is present (large variant only).
  final String emptyMessage;

  /// Placeholder text shown when an image fails to load (large variant only).
  final String errorMessage;

  bool get _hasImage => bytes != null || (url != null && url!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    if (!_hasImage) return _placeholder(context, emptyMessage);

    if (bytes != null) {
      return Image.memory(
        bytes!,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            _placeholder(context, errorMessage),
      );
    }

    return Image.network(
      url!,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _loading();
      },
      errorBuilder: (context, error, stackTrace) =>
          _placeholder(context, errorMessage),
    );
  }

  Widget _loading() {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _placeholder(BuildContext context, String message) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final icon = Icon(
      Icons.directions_car_outlined,
      size: compact ? 24 : 48,
      color: color,
    );

    if (compact) return Center(child: icon);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: DriftSpacing.sm),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
