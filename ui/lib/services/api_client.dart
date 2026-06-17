import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/prediction.dart';

/// Thrown when a request fails. [message] is always safe to show to the user
/// (no stack traces, no raw server internals).
class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thin client over the FastAPI inference backend (T001).
///
/// Base URL defaults to `http://localhost:8000` and can be overridden at build
/// time with `--dart-define=API_BASE_URL=https://...`.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? _defaultBaseUrl,
        _client = client ?? http.Client();

  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  final String baseUrl;
  final http.Client _client;

  /// Upload raw image [bytes] to `POST /predict` and return the top-[k] results.
  Future<List<Prediction>> predictBytes(
    Uint8List bytes, {
    required String filename,
    int k = 5,
  }) async {
    final uri = Uri.parse('$baseUrl/predict?k=$k');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    try {
      final streamed = await _client.send(request);
      final response = await http.Response.fromStream(streamed);
      return _parse(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        "Couldn't reach the server. Make sure the API is running and try again.",
      );
    }
  }

  /// Send [url] to `POST /predict-url` and return the top-[k] results.
  Future<List<Prediction>> predictUrl(String url, {int k = 5}) async {
    final uri = Uri.parse('$baseUrl/predict-url');
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url, 'k': k}),
      );
      return _parse(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        "Couldn't reach the server. Make sure the API is running and try again.",
      );
    }
  }

  List<Prediction> _parse(http.Response response) {
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = (body['predictions'] as List?) ?? const [];
      return raw
          .map((e) => Prediction.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    }

    // Surface the server's user-facing detail when available, otherwise a
    // generic message. Never expose raw bodies / stack traces.
    String detail;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      detail = body['detail']?.toString() ??
          (body['detail'] is List ? 'Invalid input.' : 'Something went wrong.');
    } catch (_) {
      detail = 'Something went wrong. Please try again.';
    }
    throw ApiException(detail);
  }

  void close() => _client.close();
}
