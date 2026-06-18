import 'package:flutter/material.dart';

/// A labeled URL text input for the Search screen (US-13).
///
/// Extracted from `HomeScreen` so the Search layout is composed of small,
/// self-contained inputs. Keeps `Key('url-field')` for automation; all picking
/// and identify logic stays in the owning screen.
class UrlInputField extends StatelessWidget {
  const UrlInputField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;

  /// When false the field is non-interactive (e.g. during inference).
  final bool enabled;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('url-field'),
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.url,
      decoration: const InputDecoration(
        labelText: 'Image URL',
        hintText: 'https://example.com/car.jpg',
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}
