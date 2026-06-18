import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../main.dart';
import 'image_preview_content.dart';

/// Shows a preview of the image the user is about to identify — either picked
/// bytes (upload) or a network image (URL). Falls back to a placeholder when
/// nothing is selected (US-01).
///
/// The neutral grey surface lives here; the bytes/url rendering (image +
/// loading + "Preview unavailable" placeholder) is delegated to the shared
/// [ImagePreviewContent] (T018) so this view, the image card, and History
/// thumbnails all render identically.
class ImagePreview extends StatelessWidget {
  const ImagePreview({super.key, this.bytes, this.url});

  /// Raw bytes of a picked file (takes precedence over [url]).
  final Uint8List? bytes;

  /// A remote image URL.
  final String? url;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF2A2831) : const Color(0xFFEDEDED);
    final borderColor = isDark ? const Color(0xFF444050) : const Color(0xFFCCCCCC);

    return Container(
      key: const Key('image-preview'),
      height: 220,
      decoration: BoxDecoration(
        // Neutral grey preview surface (not the pastel blue tint) so uploaded
        // photos read true-to-colour.
        color: backgroundColor,
        borderRadius: BorderRadius.circular(kDriftRadius),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: ImagePreviewContent(bytes: bytes, url: url),
    );
  }
}
