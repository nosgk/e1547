import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:e1547/translate/data/translate.dart';
import 'package:flutter/foundation.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';

/// Result of a successful translation.
typedef TranslationResult = ({String text, String providerLabel});

/// App-wide online translation service.
///
/// Supports four providers, each with optional URL/header/body overrides
/// ("advanced customization"). Templates may reference variables via
/// `@token` placeholders:
///
/// - `@text`      the text to translate
/// - `@toLang`    the target language code (or native name for AI prompts)
/// - `@fromLang`  the source language, always `auto`
/// - `@apiKey`    the configured API key
/// - `@model`     the configured model name
/// - `@systemPrompt`, `@userPrompt`  the rendered AI prompts
///
/// In URLs, values are percent-encoded; in JSON bodies, quoted `"@token"`s
/// are replaced with the JSON-encoded value.
class TranslationService {
  TranslationService._() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
        validateStatus: (status) => true,
      ),
    );
    _dio.httpClientAdapter = NativeAdapter();
  }

  static final TranslationService instance = TranslationService._();

  late final Dio _dio;

  /// Session-scoped translation cache, keyed by provider|target|text.
  final Map<String, String> _cache = {};

  static const int _cacheLimit = 500;

  // --- rate limiting ---------------------------------------------------------

  /// Maximum requests per minute; 0 disables limiting.
  int _requestsPerMinute = 0;
  final List<DateTime> _requestTimes = [];

  /// Current client-side request quota (requests per minute; 0 = unlimited).
  int get requestsPerMinute => _requestsPerMinute;

  /// Sets the client-side request quota (requests per minute; 0 = unlimited).
  /// Applies to every outgoing translation request, including URL-chunked
  /// Google requests.
  set requestsPerMinute(int value) =>
      _requestsPerMinute = value < 0 ? 0 : value;

  /// Waits until the sliding one-minute window has room for another request.
  Future<void> _awaitRateLimit() async {
    final limit = _requestsPerMinute;
    if (limit <= 0) return;
    while (true) {
      final now = DateTime.now();
      _requestTimes.removeWhere(
        (time) => now.difference(time) >= const Duration(minutes: 1),
      );
      if (_requestTimes.length < limit) {
        _requestTimes.add(now);
        return;
      }
      final oldest = _requestTimes.first;
      final wait = const Duration(minutes: 1) - now.difference(oldest);
      await Future<void>.delayed(
        wait <= Duration.zero ? const Duration(milliseconds: 50) : wait,
      );
    }
  }

  /// Translates [text] with the given [config].
  ///
  /// Returns the translated text plus a short provider label for the
  /// "translated by" caption. Throws [TranslationException] with a
  /// user-presentable message on failure.
  Future<TranslationResult> translate({
    required String text,
    required TranslationConfig config,
  }) async {
    if (text.trim().isEmpty) {
      throw const TranslationException('nothing to translate');
    }

    final cacheKey = '${config.provider.name}|${config.targetLanguage}|$text';
    final cached = _cache[cacheKey];
    if (cached != null) {
      return (text: cached, providerLabel: _providerLabel(config));
    }

    final result = switch (config.provider) {
      TranslationProvider.google => await _translateGoogle(text, config),
      TranslationProvider.microsoft => await _translateMicrosoft(text, config),
      TranslationProvider.azure => await _translateAzure(text, config),
      TranslationProvider.openai => await _translateOpenAi(text, config),
    };

    if (_cache.length >= _cacheLimit) {
      _cache.remove(_cache.keys.first);
    }
    _cache[cacheKey] = result;
    return (text: result, providerLabel: _providerLabel(config));
  }

  /// Lists model ids from an OpenAI-compatible `/models` endpoint.
  Future<List<String>> fetchModels(TranslationConfig config) async {
    final headers = _requestHeaders(
      config,
      const {'Authorization': 'Bearer @apiKey', 'Accept': 'application/json'},
      vars: {
        'apiKey': config.apiKey,
        'model': config.model,
        'toLang': config.targetLanguage,
      },
      requireApiKey: true,
    );
    try {
      final response = await _dio.get(
        config.openaiModelsUrl,
        options: Options(headers: headers),
      );
      _validateStatus(response);
      final data = response.data;
      if (data is! Map || data['data'] is! List) {
        throw const TranslationException('unexpected response format');
      }
      final models = [
        for (final model in data['data'] as List)
          if (model is Map && model['id'] is String) model['id'] as String,
      ]..sort();
      if (models.isEmpty) {
        throw const TranslationException('no models returned');
      }
      return models;
    } on TranslationException {
      rethrow;
    } on DioException catch (error) {
      throw _dioError(error);
    } on Object catch (error) {
      throw TranslationException('$error');
    }
  }

  /// Translates a short fixed phrase to verify the configuration works.
  Future<String> testConnection(TranslationConfig config) async {
    final result = await translate(text: 'Hello, world!', config: config);
    return result.text;
  }

  String _providerLabel(TranslationConfig config) => switch (config.provider) {
    TranslationProvider.google => TranslationProvider.google.label,
    TranslationProvider.microsoft => TranslationProvider.microsoft.label,
    TranslationProvider.azure => TranslationProvider.azure.label,
    TranslationProvider.openai => config.model,
  };

  // ---------------------------------------------------------------------------
  // Google (unofficial free endpoint)
  // ---------------------------------------------------------------------------

  static const String _googleUrlTemplate =
      'https://translate.googleapis.com/translate_a/single'
      '?client=gtx&sl=auto&tl=@toLang&dt=t&q=@text';

  Future<String> _translateGoogle(String text, TranslationConfig config) async {
    final urlTemplate = _effectiveUrl(config, _googleUrlTemplate);
    final headers = _requestHeaders(config, const {}, vars: _baseVars(config));
    // GET URLs are length limited; long texts are split on line/sentence
    // boundaries and translated chunk by chunk.
    final chunks = splitForUrl(text, 1200);
    final parts = <String>[];
    try {
      for (final chunk in chunks) {
        await _awaitRateLimit();
        final url = renderUrlTemplate(urlTemplate, {
          ..._baseVars(config),
          'text': chunk,
        });
        final response = await _dio.get(
          url,
          options: Options(headers: headers),
        );
        _validateStatus(response);
        parts.add(_parseGoogleResponse(response.data));
      }
    } on TranslationException {
      rethrow;
    } on DioException catch (error) {
      throw _dioError(error);
    } on Object catch (error) {
      throw TranslationException('$error');
    }
    return parts.join();
  }

  String _parseGoogleResponse(Object? data) {
    // [[["translated","original",...],["translated","original",...]],...]
    if (data is! List || data.isEmpty || data[0] is! List) {
      throw const TranslationException('unexpected response format');
    }
    final buffer = StringBuffer();
    for (final segment in data[0] as List) {
      if (segment is List && segment.isNotEmpty) {
        buffer.write('${segment[0]}');
      }
    }
    final result = buffer.toString();
    if (result.isEmpty) {
      throw const TranslationException('empty translation');
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Microsoft (free Edge endpoint)
  // ---------------------------------------------------------------------------

  static const String _microsoftUrlTemplate =
      'https://edge.microsoft.com/translate/translatetext?from=&to=@toLang';
  static const String _microsoftBodyTemplate = '["@text"]';

  Future<String> _translateMicrosoft(
    String text,
    TranslationConfig config,
  ) async {
    final urlTemplate = _effectiveUrl(config, _microsoftUrlTemplate);
    final bodyTemplate = _effectiveBody(config, _microsoftBodyTemplate);
    final target = _microsoftLanguage(config.targetLanguage);
    final url = renderUrlTemplate(urlTemplate, {
      ..._baseVars(config),
      'toLang': target,
      'text': text,
    });
    final headers = _requestHeaders(
      config,
      const {'Accept': 'application/json'},
      vars: {..._baseVars(config), 'toLang': target},
    );
    try {
      await _awaitRateLimit();
      final response = await _dio.post(
        url,
        data: renderJsonTemplate(bodyTemplate, {
          ..._baseVars(config),
          'toLang': target,
          'text': text,
        }),
        options: Options(headers: headers),
      );
      _validateStatus(response);
      return _parseMicrosoftResponse(response.data);
    } on TranslationException {
      rethrow;
    } on DioException catch (error) {
      throw _dioError(error);
    } on Object catch (error) {
      throw TranslationException('$error');
    }
  }

  String _parseMicrosoftResponse(Object? data) {
    // [{"translations":[{"text":"..."}]}, ...]
    if (data is! List || data.isEmpty || data[0] is! Map) {
      throw const TranslationException('unexpected response format');
    }
    final translations = (data[0] as Map)['translations'];
    if (translations is! List || translations.isEmpty) {
      throw const TranslationException('unexpected response format');
    }
    final first = translations[0];
    final translated = first is Map ? first['text'] : null;
    if (translated is! String || translated.isEmpty) {
      throw const TranslationException('empty translation');
    }
    return translated;
  }

  String _microsoftLanguage(String code) => switch (code) {
    'zh-CN' => 'zh-Hans',
    'zh-TW' => 'zh-Hant',
    _ => code,
  };

  // ---------------------------------------------------------------------------
  // Azure Cognitive Translator (API key required)
  // ---------------------------------------------------------------------------

  Future<String> _translateAzure(String text, TranslationConfig config) async {
    if (config.azureApiKey.trim().isEmpty) {
      throw const TranslationException('no API key configured');
    }
    final target = _microsoftLanguage(config.targetLanguage);
    final url =
        '${config.azureTranslateUrl}'
        '?api-version=3.0&to=${Uri.encodeComponent(target)}&textType=plain';
    final headers = {
      ..._effectiveHeaders(config, const {'Accept': 'application/json'}),
      'Ocp-Apim-Subscription-Key': config.azureApiKey,
      'Content-Type': 'application/json',
    };
    try {
      await _awaitRateLimit();
      final response = await _dio.post(
        url,
        data: renderJsonTemplate(
          _effectiveBody(config, '[{"Text": "@text"}]'),
          {..._baseVars(config), 'toLang': target, 'text': text},
        ),
        options: Options(headers: headers),
      );
      _validateStatus(response);
      return _parseMicrosoftResponse(response.data);
    } on TranslationException {
      rethrow;
    } on DioException catch (error) {
      throw _dioError(error);
    } on Object catch (error) {
      throw TranslationException('$error');
    }
  }

  // ---------------------------------------------------------------------------
  // OpenAI-compatible chat APIs
  // ---------------------------------------------------------------------------

  Future<String> _translateOpenAi(String text, TranslationConfig config) async {
    final urlTemplate = _effectiveUrl(config, config.openaiChatUrl);
    final bodyTemplate = _effectiveBody(config, kOpenAiBodyTemplate);
    final targetName =
        kTranslationLanguages[config.targetLanguage] ?? config.targetLanguage;
    final url = renderUrlTemplate(urlTemplate, {
      ..._baseVars(config),
      'toLang': targetName,
      'text': text,
    });
    final headers = _requestHeaders(
      config,
      const {'Authorization': 'Bearer @apiKey', 'Accept': 'application/json'},
      vars: {..._baseVars(config), 'toLang': targetName},
      requireApiKey: config.customHeaders?.trim().isNotEmpty != true,
    );
    final body = renderJsonTemplate(bodyTemplate, {
      ..._baseVars(config),
      'toLang': targetName,
      'text': text,
      'systemPrompt': config.systemPrompt,
      'userPrompt': _renderUserPrompt(text, config),
    });
    try {
      await _awaitRateLimit();
      final response = await _dio.post(
        url,
        data: body,
        options: Options(headers: headers),
      );
      _validateStatus(response);
      return _parseOpenAiResponse(response.data);
    } on TranslationException {
      rethrow;
    } on DioException catch (error) {
      throw _dioError(error);
    } on Object catch (error) {
      throw TranslationException('$error');
    }
  }

  String _parseOpenAiResponse(Object? data) {
    if (data is! Map) {
      throw const TranslationException('unexpected response format');
    }
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty || choices[0] is! Map) {
      throw const TranslationException('unexpected response format');
    }
    final message = (choices[0] as Map)['message'];
    var content = message is Map ? message['content'] : null;
    if (content is! String) {
      throw const TranslationException('empty translation');
    }
    // Reasoning models may prepend a think block; strip it and any wrapping
    // code fences the model might have added.
    content = content.replaceAll(
      RegExp(r'<think>[\s\S]*?</think>', multiLine: true),
      '',
    );
    content = content.trim();
    final fence = RegExp(r'^```[a-zA-Z]*\n([\s\S]*)\n```$');
    final match = fence.firstMatch(content);
    if (match != null) content = match.group(1)!.trim();
    if (content.isEmpty) {
      throw const TranslationException('empty translation');
    }
    return content;
  }

  // ---------------------------------------------------------------------------
  // Template rendering
  // ---------------------------------------------------------------------------

  String _effectiveUrl(TranslationConfig config, String defaultUrl) =>
      (config.customUrl?.trim().isNotEmpty ?? false)
      ? config.customUrl!.trim()
      : defaultUrl;

  String _effectiveBody(TranslationConfig config, String defaultBody) =>
      (config.customBody?.trim().isNotEmpty ?? false)
      ? config.customBody!.trim()
      : defaultBody;

  /// Effective request headers: the custom set when configured, otherwise the
  /// defaults; values are template-rendered. A JSON content type is ensured
  /// because request bodies are always rendered JSON templates.
  Map<String, String> _requestHeaders(
    TranslationConfig config,
    Map<String, String> defaults, {
    required Map<String, String> vars,
    bool requireApiKey = false,
  }) {
    if (requireApiKey && config.apiKey.trim().isEmpty) {
      throw const TranslationException('no API key configured');
    }
    final custom = config.customHeaders?.trim() ?? '';
    Map<String, String> base = defaults;
    if (custom.isNotEmpty) {
      try {
        final decoded = jsonDecode(custom);
        if (decoded is Map) {
          base = {for (final e in decoded.entries) '${e.key}': '${e.value}'};
        }
      } on FormatException {
        // fall through to defaults on malformed JSON
      }
    }
    final rendered = {
      for (final entry in base.entries)
        entry.key: renderPlainTemplate(entry.value, vars),
    };
    rendered.putIfAbsent('Content-Type', () => 'application/json');
    return rendered;
  }

  /// Effective custom headers, when configured; otherwise [defaults].
  Map<String, String> _effectiveHeaders(
    TranslationConfig config,
    Map<String, String> defaults,
  ) {
    final custom = config.customHeaders?.trim() ?? '';
    if (custom.isEmpty) return defaults;
    try {
      final decoded = jsonDecode(custom);
      if (decoded is Map) {
        return {for (final e in decoded.entries) '${e.key}': '${e.value}'};
      }
    } on FormatException {
      // fall through to defaults on malformed JSON
    }
    return defaults;
  }

  Map<String, String> _baseVars(TranslationConfig config) => {
    'toLang': config.targetLanguage,
    'fromLang': 'auto',
    'apiKey': config.apiKey,
    'model': config.model,
  };

  String _renderUserPrompt(String text, TranslationConfig config) {
    final targetName =
        kTranslationLanguages[config.targetLanguage] ?? config.targetLanguage;
    return config.userPrompt
        .replaceAll('@toLang', targetName)
        .replaceAll('@text', text);
  }

  /// Renders a plain-text template (header values), substituting verbatim.
  @visibleForTesting
  static String renderPlainTemplate(String template, Map<String, String> vars) {
    var result = template;
    for (final entry in vars.entries) {
      result = result.replaceAll('@${entry.key}', entry.value);
    }
    return result;
  }

  /// Renders a URL template, percent-encoding every substituted value.
  @visibleForTesting
  static String renderUrlTemplate(String template, Map<String, String> vars) {
    var result = template;
    for (final entry in vars.entries) {
      result = result.replaceAll(
        '@${entry.key}',
        Uri.encodeComponent(entry.value),
      );
    }
    return result;
  }

  /// Renders a JSON body template. Quoted tokens (`"@token"`) are replaced
  /// with the JSON-encoded value so strings keep valid escaping; remaining
  /// bare tokens are replaced verbatim (for numbers etc.).
  @visibleForTesting
  static String renderJsonTemplate(String template, Map<String, String> vars) {
    var result = template;
    for (final entry in vars.entries) {
      result = result.replaceAll('"@${entry.key}"', jsonEncode(entry.value));
    }
    for (final entry in vars.entries) {
      result = result.replaceAll('@${entry.key}', entry.value);
    }
    return result;
  }

  /// Splits [text] into chunks whose percent-encoded form stays well below
  /// common URL length limits, preferring line and sentence boundaries.
  /// Separators stay attached to the end of each chunk so joining the
  /// translated chunks preserves the original layout.
  @visibleForTesting
  static List<String> splitForUrl(String text, int limit) {
    if (Uri.encodeComponent(text).length <= limit) return [text];
    final chunks = <String>[];
    final pending = <String>[];
    for (final line in text.split('\n')) {
      if (pending.isNotEmpty &&
          Uri.encodeComponent('${pending.join('\n')}\n$line').length > limit) {
        chunks.add('${pending.join('\n')}\n');
        pending.clear();
      }
      var remaining = line;
      while (Uri.encodeComponent(remaining).length > limit) {
        var cut = limit;
        final window = remaining.substring(0, cut);
        final lastSpace = window.lastIndexOf(' ');
        if (lastSpace > limit ~/ 2) cut = lastSpace + 1;
        chunks.add(remaining.substring(0, cut));
        remaining = remaining.substring(cut);
      }
      if (remaining.isNotEmpty) pending.add(remaining);
    }
    if (pending.isNotEmpty) chunks.add(pending.join('\n'));
    return chunks;
  }

  void _validateStatus(Response response) {
    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) return;
    final detail = _responseDetail(response);
    if (status == 401 || status == 403) {
      throw TranslationException(
        'invalid API key',
        code: status,
        detail: detail,
      );
    }
    if (status == 429) {
      throw TranslationException('rate limited', code: status, detail: detail);
    }
    throw TranslationException(
      'server error ($status)',
      code: status,
      detail: detail,
    );
  }

  /// First 200 characters of an error response body, for diagnostics.
  String? _responseDetail(Response response) {
    final data = response.data;
    final String body;
    if (data is String) {
      body = data;
    } else if (data != null) {
      body = jsonEncode(data);
    } else {
      return null;
    }
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length <= 200 ? trimmed : '${trimmed.substring(0, 200)}…';
  }

  TranslationException _dioError(DioException error) {
    final response = error.response;
    final status = response?.statusCode;
    final detail = response == null ? null : _responseDetail(response);
    final message = _dioErrorMessage(error);
    return TranslationException(message, code: status, detail: detail);
  }

  String _dioErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'connection timed out';
      case DioExceptionType.connectionError:
        return 'connection failed';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        if (status == 401 || status == 403) return 'invalid API key';
        return 'server error ($status)';
      case DioExceptionType.cancel:
        return 'request cancelled';
      default:
        return 'network error';
    }
  }
}
