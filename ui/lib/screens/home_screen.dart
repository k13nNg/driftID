import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../models/history_entry.dart';
import '../models/prediction.dart';
import '../services/api_client.dart';
import '../services/history_store.dart';
import '../services/image_downscale.dart';
import '../widgets/image_preview.dart';
import '../widgets/prediction_list.dart';

/// One-line summary of what the app does (US-05). Mirrors the README intent.
const String kAppTagline =
    'Identify a car\'s make and model from a photo.';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.apiClient, this.historyStore});

  final ApiClient? apiClient;

  /// When provided, each successful identification is auto-saved here (US-08).
  final HistoryStore? historyStore;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  final TextEditingController _urlController = TextEditingController();

  Uint8List? _bytes;
  String? _filename;
  String? _previewUrl;
  bool _loading = false;
  String? _error;
  List<Prediction> _predictions = const [];

  @override
  void dispose() {
    _urlController.dispose();
    if (widget.apiClient == null) _api.close();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      setState(() => _error = 'Could not read that file. Please try another image.');
      return;
    }
    setState(() {
      _bytes = file.bytes;
      _filename = file.name;
      _previewUrl = null;
      _predictions = const [];
      _error = null;
    });
  }

  Future<void> _identify() async {
    final url = _urlController.text.trim();
    final hasFile = _bytes != null;
    final hasUrl = url.isNotEmpty;

    if (!hasFile && !hasUrl) {
      setState(() => _error = 'Upload an image or paste an image URL first.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _predictions = const [];
    });

    try {
      final List<Prediction> results;
      final HistorySource source;
      if (hasFile) {
        source = HistorySource.upload;
        results = await _api.predictBytes(
          _bytes!,
          filename: _filename ?? 'upload.jpg',
        );
      } else {
        source = HistorySource.url;
        results = await _api.predictUrl(url);
        setState(() => _previewUrl = url);
      }
      setState(() => _predictions = results);
      // Auto-save the successful identification (US-08). Fire-and-forget: don't
      // block the result view on persistence, and never surface storage errors.
      if (results.isNotEmpty) {
        _saveToHistory(source: source, url: url, results: results);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Persists a successful identification to history without blocking the result
  /// view (US-08). Uploads are stored as a downscaled data URL; URL submissions
  /// keep the original reference. Storage failures are swallowed so they never
  /// look like inference errors.
  Future<void> _saveToHistory({
    required HistorySource source,
    required String url,
    required List<Prediction> results,
  }) async {
    final store = widget.historyStore;
    if (store == null) return;
    try {
      final String imageRef;
      if (source == HistorySource.upload) {
        final bytes = _bytes;
        if (bytes == null) return;
        imageRef = await encodeImageAsDataUrl(bytes);
      } else {
        imageRef = url;
      }
      await store.add(HistoryEntry.now(
        source: source,
        imageRef: imageRef,
        predictions: results,
      ));
    } catch (_) {
      // Best-effort persistence — never surface storage errors to the user.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('DriftID'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DriftSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(kAppTagline, style: theme.textTheme.titleMedium),
                ),
                const SizedBox(height: DriftSpacing.lg),
                ImagePreview(bytes: _bytes, url: _previewUrl),
                const SizedBox(height: DriftSpacing.md),
                OutlinedButton.icon(
                  key: const Key('upload-button'),
                  onPressed: _loading ? null : _pickImage,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload image'),
                ),
                if (_filename != null)
                  Padding(
                    padding: const EdgeInsets.only(top: DriftSpacing.sm),
                    child: Text('Selected: $_filename',
                        style: theme.textTheme.bodySmall),
                  ),
                const SizedBox(height: DriftSpacing.md),
                const Row(children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: DriftSpacing.sm),
                    child: Text('or'),
                  ),
                  Expanded(child: Divider()),
                ]),
                const SizedBox(height: DriftSpacing.md),
                TextField(
                  key: const Key('url-field'),
                  controller: _urlController,
                  enabled: !_loading,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                    hintText: 'https://example.com/car.jpg',
                  ),
                  onChanged: (_) {
                    if (_bytes != null) {
                      setState(() {
                        _bytes = null;
                        _filename = null;
                      });
                    }
                  },
                  onSubmitted: (_) => _identify(),
                ),
                const SizedBox(height: DriftSpacing.lg),
                FilledButton(
                  key: const Key('identify-button'),
                  onPressed: _loading ? null : _identify,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: DriftSpacing.md),
                    child: Text('Identify'),
                  ),
                ),
                const SizedBox(height: DriftSpacing.lg),
                if (_loading)
                  const Center(
                    key: Key('loading-indicator'),
                    child: Padding(
                      padding: EdgeInsets.all(DriftSpacing.md),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                if (_error != null)
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      key: const Key('error-message'),
                      padding: const EdgeInsets.all(DriftSpacing.md),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(kDriftRadius),
                      ),
                      child: Row(children: [
                        Icon(Icons.error_outline,
                            color: theme.colorScheme.onErrorContainer),
                        const SizedBox(width: DriftSpacing.sm),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                                color: theme.colorScheme.onErrorContainer),
                          ),
                        ),
                      ]),
                    ),
                  ),
                if (_predictions.isNotEmpty)
                  PredictionList(predictions: _predictions),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
