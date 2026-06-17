import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Downscales image [bytes] to a JPEG `data:` URL using an offscreen canvas so
/// the saved history entry stays well within the ~5 MB `localStorage` budget
/// (T006). The longest edge is capped at [maxEdge]; aspect ratio is preserved.
///
/// On any failure the original bytes are returned as a JPEG data URL so a
/// best-effort thumbnail is still saved.
Future<String> encodeImageAsDataUrl(
  Uint8List bytes, {
  int maxEdge = 512,
  double quality = 0.82,
}) async {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/jpeg'),
  );
  final objectUrl = web.URL.createObjectURL(blob);
  try {
    final img = web.HTMLImageElement()..src = objectUrl;
    await img.decode().toDart;

    final w = img.naturalWidth;
    final h = img.naturalHeight;
    final longest = w > h ? w : h;
    final scale = (longest > maxEdge && longest > 0) ? maxEdge / longest : 1.0;
    final tw = (w * scale).round().clamp(1, w < 1 ? 1 : w);
    final th = (h * scale).round().clamp(1, h < 1 ? 1 : h);

    final canvas = web.HTMLCanvasElement()
      ..width = tw
      ..height = th;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(img, 0, 0, tw.toDouble(), th.toDouble());
    return canvas.toDataURL('image/jpeg', quality.toJS);
  } catch (_) {
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  } finally {
    web.URL.revokeObjectURL(objectUrl);
  }
}
