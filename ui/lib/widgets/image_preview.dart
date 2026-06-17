import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Shows a preview of the image the user is about to identify — either picked
/// bytes (upload) or a network image (URL). Falls back to a placeholder when
/// nothing is selected (US-01).
class ImagePreview extends StatelessWidget {
  const ImagePreview({super.key, this.bytes, this.url});

  /// Raw bytes of a picked file (takes precedence over [url]).
  final Uint8List? bytes;

  /// A remote image URL.
  final String? url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = bytes != null || (url != null && url!.isNotEmpty);

    return Container(
      key: const Key('image-preview'),
      height: 220,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: hasImage ? _image() : _placeholder(theme),
    );
  }

  Widget _image() {
    if (bytes != null) {
      return Image.memory(bytes!, fit: BoxFit.contain);
    }
    return Image.network(
      url!,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _placeholder(
        Theme.of(context),
        message: 'Preview unavailable',
      ),
    );
  }

  Widget _placeholder(ThemeData theme, {String message = 'No image selected'}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.directions_car_outlined,
            size: 48, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 8),
        Text(message, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
