import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lightweight app-wide translation layer.
///
/// Translations are looked up by the original English string, so call sites
/// only need to append `.tr` and automatically fall back to the source text
/// when no translation exists. This keeps diffs against upstream minimal and
/// makes rebasing on new upstream versions painless: new or changed upstream
/// strings simply stay English until a translation is added.
///
/// The mapping lives in `assets/i18n/zh-CN.json`. Each entry is keyed by the
/// English source string and carries `en`, `zh` and an optional `ctx`
/// (context) note for translators.
class I18n {
  I18n._();

  static final I18n instance = I18n._();

  static const String asset = 'assets/i18n/zh-CN.json';

  Map<String, String> _translations = const {};
  bool _enabled = false;
  bool _loaded = false;

  final ValueNotifier<bool> notifier = ValueNotifier<bool>(false);

  /// Whether translations are applied. False for non-Chinese device locales
  /// and until [load] has finished.
  bool get enabled => _enabled;

  bool get loaded => _loaded;

  /// Loads the zh-CN mapping from the bundled asset.
  ///
  /// [overrideZh] forces Chinese on/off regardless of the device locale
  /// (null = follow the system locale).
  ///
  /// Never throws: any failure (missing asset, malformed JSON) leaves the
  /// app in its original English state.
  Future<void> load({bool? overrideZh}) async {
    try {
      bool useZh = overrideZh ?? _systemUsesZh();
      if (!useZh) {
        _translations = const {};
        _enabled = false;
        _loaded = true;
        notifier.value = true;
        return;
      }
      final String raw = await rootBundle.loadString(asset);
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        _translations = {
          for (final MapEntry(:key, :value) in decoded.entries)
            if (value is Map<String, Object?>)
              key: value['zh']?.toString() ?? key
            else if (value is String)
              key: value,
        };
        _enabled = true;
      }
    } on Object catch (error, trace) {
      // Translation must never break the app; fall back to English.
      debugPrint('I18n: failed to load translations: $error\n$trace');
      _translations = const {};
      _enabled = false;
    }
    _loaded = true;
    notifier.value = true;
  }

  static bool _systemUsesZh() =>
      PlatformDispatcher.instance.locale.languageCode == 'zh';

  /// Whether the device locale is Chinese (used as the default setting).
  static bool get systemIsZh => _systemUsesZh();

  /// Switch translation on/off at runtime (app language setting).
  Future<void> setEnabled(bool value) => load(overrideZh: value);

  /// Returns the translation for [key], or [key] itself when none exists.
  String translate(String key) {
    if (!_enabled) return key;
    return _translations[key] ?? key;
  }

  /// Translates [key] and fills `{name}` placeholders from [args].
  ///
  /// Placeholders missing from [args] are left untouched, so a mismatch can
  /// never throw at runtime.
  String translateArgs(String key, Map<String, Object?> args) {
    String result = translate(key);
    args.forEach((name, value) {
      result = result.replaceAll('{$name}', '$value');
    });
    return result;
  }
}

extension StringI18n on String {
  /// Translates this string via the zh-CN mapping, falling back to the
  /// original English text when no translation is available.
  String get tr => I18n.instance.translate(this);

  /// Translates this string and fills `{name}` placeholders with [args].
  String trArgs(Map<String, Object?> args) =>
      I18n.instance.translateArgs(this, args);
}
