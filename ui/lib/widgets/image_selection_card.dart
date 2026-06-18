import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../main.dart';
import 'image_preview_content.dart';

/// A single, self-contained image picker + preview (US-13).
///
/// The whole card is one clickable surface: tapping anywhere triggers [onPick]
/// to open the file picker. Once an image is chosen ([bytes] or [url]) it
/// previews inside the same card without changing the card's footprint — empty
/// and filled states are the same fixed size. When an image is present, an
/// explicit expand control (separate from the tap-to-pick surface) opens it
/// larger for inspection.
class ImageSelectionCard extends StatelessWidget {
  const ImageSelectionCard({
    super.key,
    this.bytes,
    this.url,
    required this.onPick,
    this.enabled = true,
  });

  /// Raw bytes of a picked file (takes precedence over [url]).
  final Uint8List? bytes;

  /// A remote image URL.
  final String? url;

  /// Opens the file picker. The entire card surface invokes this.
  final VoidCallback onPick;

  /// When false the card is non-interactive (e.g. during inference).
  final bool enabled;

  /// Fixed card height — matches the previous inline preview footprint so the
  /// layout doesn't shift between empty and filled states.
  static const double _cardHeight = 220;

  bool get _hasImage => bytes != null || (url != null && url!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      label: 'Add a car photo',
      button: true,
      child: SizedBox(
        height: _cardHeight,
        width: double.infinity,
        child: Material(
          key: const Key('image-card'),
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(kDriftRadius),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              InkWell(
                onTap: enabled ? onPick : null,
                child: Padding(
                  // Symmetric padding on all four sides.
                  padding: const EdgeInsets.all(DriftSpacing.md),
                  child: _hasImage ? _preview() : _empty(theme),
                ),
              ),
              if (_hasImage)
                Positioned(
                  top: DriftSpacing.sm,
                  right: DriftSpacing.sm,
                  child: _ExpandButton(
                    onPressed:
                        enabled ? () => _showFullImage(context) : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview() {
    // Bytes/url rendering (+ loading + "Preview unavailable" failure) is shared
    // with the History thumbnail and Result view (T018).
    return ImagePreviewContent(bytes: bytes, url: url, fit: BoxFit.contain);
  }

  Widget _empty(ThemeData theme, {String message = 'Tap to add a car photo'}) {
    final scheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car_outlined,
              size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: DriftSpacing.sm),
          Text(message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _FullImageDialog(bytes: bytes, url: url),
    );
  }
}

/// Corner affordance to inspect the selected image at a larger size.
class _ExpandButton extends StatelessWidget {
  const _ExpandButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        key: const Key('expand-image'),
        tooltip: 'Expand image',
        onPressed: onPressed,
        icon: const Icon(Icons.fullscreen),
        color: scheme.onSurface,
      ),
    );
  }
}

/// Full-bleed, pinch/scroll-zoomable view of the selected image (US-13 inspect).
class _FullImageDialog extends StatelessWidget {
  const _FullImageDialog({this.bytes, this.url});

  final Uint8List? bytes;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final Widget image = bytes != null
        ? Image.memory(bytes!, fit: BoxFit.contain)
        : Image.network(url!, fit: BoxFit.contain);

    return Dialog(
      key: const Key('expanded-image-dialog'),
      insetPadding: const EdgeInsets.all(DriftSpacing.md),
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(child: image),
            ),
          ),
          Positioned(
            top: DriftSpacing.sm,
            right: DriftSpacing.sm,
            child: IconButton(
              key: const Key('close-expanded-image'),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
