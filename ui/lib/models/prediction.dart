/// A single top-k result returned by the API: a raw class string plus a
/// confidence in the range [0, 1].
///
/// Class strings follow the dataset convention
/// `make_model-gen_startYear_endYear` (e.g. `audi_a7-gen_2010_2014`). The
/// getters below parse that into human-readable fields for display (US-06),
/// while always keeping the original string available as a fallback.
class Prediction {
  const Prediction({required this.className, required this.confidence});

  final String className;
  final double confidence;

  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      className: json['class'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Confidence formatted as an easy-to-scan percentage, e.g. `42.0%`.
  String get confidencePercent =>
      '${(confidence * 100).toStringAsFixed(1)}%';

  _ParsedLabel get _parsed => _ParsedLabel.parse(className);

  /// Capitalized make, e.g. `Audi`. Falls back to the raw string.
  String get make => _parsed.make;

  /// Model with the trailing `-gen` marker stripped, e.g. `A7`.
  String get model => _parsed.model;

  /// Generation/year range when present, e.g. `2010–2014`, otherwise empty.
  String get years => _parsed.years;

  /// Primary line: make + model, e.g. `Audi A7`.
  String get title {
    final parts = [make, model].where((p) => p.isNotEmpty).join(' ');
    return parts.isEmpty ? className : parts;
  }

  /// Secondary line: the year range, may be empty.
  String get subtitle => years;
}

class _ParsedLabel {
  const _ParsedLabel({
    required this.make,
    required this.model,
    required this.years,
  });

  final String make;
  final String model;
  final String years;

  static final RegExp _year = RegExp(r'^\d{4}$');

  factory _ParsedLabel.parse(String raw) {
    if (raw.isEmpty) {
      return const _ParsedLabel(make: '', model: '', years: '');
    }

    final tokens = raw.split('_');

    // Trailing 4-digit tokens form a start/end year range.
    var end = tokens.length;
    final yearTokens = <String>[];
    while (end > 0 && _year.hasMatch(tokens[end - 1])) {
      yearTokens.insert(0, tokens[end - 1]);
      end--;
    }

    final head = tokens.sublist(0, end);
    final make = head.isNotEmpty ? _titleCase(head.first) : '';
    final modelTokens = head.length > 1 ? head.sublist(1) : <String>[];
    final model = modelTokens
        .map((t) => t.replaceAll('-gen', ''))
        .map(_titleCase)
        .where((t) => t.isNotEmpty)
        .join(' ');

    final years = yearTokens.join('–'); // en dash

    return _ParsedLabel(make: make, model: model, years: years);
  }

  static String _titleCase(String value) {
    // Keep model designations like "a7" mostly intact but capitalize words.
    return value
        .split('-')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
