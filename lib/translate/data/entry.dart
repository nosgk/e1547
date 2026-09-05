import 'package:e1547/translate/data/service.dart';
import 'package:e1547/translate/data/translate.dart';
import 'package:flutter/foundation.dart';

enum TranslationStatus { idle, loading, success, error }

/// Per-text translation state shared between the trigger button and the
/// translated-text display.
class TranslationEntry extends ChangeNotifier {
  TranslationEntry({required this.text, this.config});

  final String text;
  TranslationConfig? config;

  TranslationStatus _status = TranslationStatus.idle;
  String? _translation;
  String? _error;
  String? _providerLabel;
  bool _expanded = false;
  bool _autoAttempted = false;

  TranslationStatus get status => _status;

  /// The translated text, once loaded.
  String? get translation => _translation;

  /// Short error message for the error state.
  String? get error => _error;

  /// Human-readable attribution, e.g. "Google Translate" or a model name.
  String? get providerLabel => _providerLabel;

  /// Whether the translation is currently shown below the original text.
  bool get expanded => _expanded;

  /// Whether auto translation already ran for this entry.
  bool get autoAttempted => _autoAttempted;

  /// Runs (or re-runs) the translation with [config].
  Future<void> translate(TranslationConfig config) async {
    this.config = config;
    if (_status == TranslationStatus.loading) return;
    if (text.trim().isEmpty) return;
    _status = TranslationStatus.loading;
    _error = null;
    _autoAttempted = true;
    notifyListeners();
    try {
      final result = await TranslationService.instance.translate(
        text: text,
        config: config,
      );
      _translation = result.text;
      _providerLabel = result.providerLabel;
      _status = TranslationStatus.success;
      _expanded = true;
    } on Object catch (error) {
      _error = error is TranslationException ? error.message : '$error';
      _status = TranslationStatus.error;
    }
    notifyListeners();
  }

  /// Expands a previously loaded translation without requesting it again.
  void expand() {
    if (_translation == null || _expanded) return;
    _expanded = true;
    notifyListeners();
  }

  void collapse() {
    if (!_expanded) return;
    _expanded = false;
    notifyListeners();
  }

  /// Marks auto translation as attempted without running it (e.g. when the
  /// text already looks like the target language).
  void skipAuto() {
    _autoAttempted = true;
  }
}
