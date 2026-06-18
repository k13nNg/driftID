import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../models/history_entry.dart';
import '../models/prediction.dart';
import '../services/api_client.dart';
import '../services/history_store.dart';
import '../services/image_downscale.dart';
import '../services/result_controller.dart';
import '../widgets/image_selection_card.dart';
import '../widgets/url_input_field.dart';

/// One-line summary of what the app does (US-05). Mirrors the README intent.
///
/// No longer rendered on Search (T015 decluttered the screen) but kept defined
/// for reuse elsewhere (e.g. Settings/About).
const String kAppTagline =
    'Identify a car\'s make and model from a photo.';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.apiClient,
    this.historyStore,
    this.resultController,
    this.onResult,
  });

  final ApiClient? apiClient;

  /// When provided, each successful identification is auto-saved here (US-08).
  final HistoryStore? historyStore;

  /// When provided, a successful identification is published here so the Result
  /// tab renders it (T016). Search itself no longer shows the result inline.
  final ResultController? resultController;

  /// Called after a successful identify so the shell can switch to the Result
  /// tab (T016, US-14).
  final VoidCallback? onResult;

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
    });

    try {
      final List<Prediction> results;
      final HistorySource source;
      Uint8List? resultBytes;
      String? resultUrl;
      if (hasFile) {
        source = HistorySource.upload;
        resultBytes = _bytes;
        results = await _api.predictBytes(
          _bytes!,
          filename: _filename ?? 'upload.jpg',
        );
      } else {
        source = HistorySource.url;
        resultUrl = url;
        results = await _api.predictUrl(url);
      }
      // Auto-save the successful identification (US-08). Fire-and-forget: don't
      // block the result view on persistence, and never surface storage errors.
      // (Captures the current bytes synchronously, so the reset below is safe.)
      if (results.isNotEmpty) {
        _saveToHistory(source: source, url: url, results: results);
      }
      // Publish the fresh result and hand off to the Result tab (T016, US-14),
      // then reset Search so it's clean when revisited (US-13).
      widget.resultController?.show(
        bytes: resultBytes,
        url: resultUrl,
        predictions: results,
      );
      widget.onResult?.call();
      _resetAfterIdentify();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Clears every input + local result state after a successful identify so
  /// returning to Search shows the clean/empty state (US-13). [IndexedStack]
  /// keeps this screen alive, so the reset must be explicit.
  void _resetAfterIdentify() {
    if (!mounted) return;
    _urlController.clear();
    setState(() {
      _bytes = null;
      _filename = null;
      _previewUrl = null;
      _error = null;
    });
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
                ImageSelectionCard(
                  bytes: _bytes,
                  url: _previewUrl,
                  onPick: _pickImage,
                  enabled: !_loading,
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
                UrlInputField(
                  controller: _urlController,
                  enabled: !_loading,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
