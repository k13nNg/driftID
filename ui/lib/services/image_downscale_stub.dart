import 'dart:convert';
import 'dart:typed_data';

/// Non-web fallback: the Dart VM has no browser canvas to resize with, so the
/// original [bytes] are encoded directly. The web build downscales instead.
Future<String> encodeImageAsDataUrl(
  Uint8List bytes, {
  int maxEdge = 512,
  double quality = 0.82,
}) async {
  return 'data:image/jpeg;base64,${base64Encode(bytes)}';
}
