/// Encodes image [bytes] as a `data:` URL for local persistence (T006).
///
/// Picks a web implementation (downscales via an offscreen canvas to keep the
/// `localStorage` payload small) when compiled for the browser, and a plain
/// base64 fallback elsewhere (e.g. the Dart VM used by `flutter test`).
library;

export 'image_downscale_stub.dart'
    if (dart.library.js_interop) 'image_downscale_web.dart';
