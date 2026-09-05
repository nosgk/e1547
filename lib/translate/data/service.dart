import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:e1547/translate/data/profile.dart';
import 'package:e1547/translate/data/translate.dart';
import 'package:flutter/foundation.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';

/// Result of a successful translation.
typedef TranslationResult = ({String text, String providerLabel});

/// Diagnostic record of one request-configurator test run: what was sent,
/// what came back and what the parse rule produced.
class TranslationProbe {
  const TranslationProbe({
    this.status,
    this.elapsedMs = 0,
    this.parsed,
    this.rawBody,
    this.error,
    this.errorDetail,
    this.requestUrl,
    this.requestHeaders = const {},
    this.requestBody,
  });

  /// HTTP status code, when a response arrived.
  final int? status;

  /// Wall-clock duration of the request in milliseconds.
  final int elapsedMs;

  /// Translation extracted by the parse rule, on success.
  final String? parsed;

  /// Raw response body, for inspection.
  final String? rawBody;

  /// User-presentable error message, on failure.
  final String? error;

  /// Extra error context (HTTP status, server excerpt).
  final String? errorDetail;

  /// The exact request that was sent.
  final String? requestUrl;
  final Map<String, String> requestHeaders;
  final String? requestBody;
}

/// App-wide online translation service.
///
/// Every provider — built-in or user-configured — runs through one generic
/// executor driven by a [TranslationRequestProfile]. The profile describes
/// the complete HTTP request (method, URL, query, headers, body) and how to
/// extract the translation from the response; nothing is added or changed
/// behind the user's back.
class TranslationService {
  TranslationService._() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
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

  // --- performance & rate limiting -------------------------------------------

  int _maxConcurrency = kDefaultTranslateConcurrency;
  int _intervalMs = kDefaultTranslateIntervalMs;
  int _timeoutSeconds = kDefaultTranslateTimeoutSeconds;

  int _inFlight = 0;
  final List<Completer<void>> _slotWaiters = [];
  DateTime _lastRequestStart = DateTime.fromMillisecondsSinceEpoch(0);

  /// Maximum number of translation requests in flight at the same time.
  int get maxConcurrency => _maxConcurrency;
  set maxConcurrency(int value) => _maxConcurrency = value < 1 ? 1 : value;

  /// Minimum interval between two request starts, in milliseconds.
  int get requestIntervalMs => _intervalMs;
  set requestIntervalMs(int value) => _intervalMs = value < 0 ? 0 : value;

  /// Per-request timeout in seconds.
  int get requestTimeoutSeconds => _timeoutSeconds;
  set requestTimeoutSeconds(int value) =>
      _timeoutSeconds = value < 1 ? kDefaultTranslateTimeoutSeconds : value;

  Duration get _timeout => Duration(seconds: _timeoutSeconds);

  /// Takes a concurrency slot, waiting until one frees up.
  Future<void> _acquireSlot() async {
    if (_inFlight < _maxConcurrency) {
      _inFlight++;
      return;
    }
    final completer = Completer<void>();
    _slotWaiters.add(completer);
    await completer.future;
  }

  /// Hands the slot to the next waiter or gives it back.
  void _releaseSlot() {
    if (_slotWaiters.isNotEmpty) {
      _slotWaiters.removeAt(0).complete();
      return;
    }
    _inFlight--;
  }

  /// Enforces the configured minimum interval between request starts.
  Future<void> _awaitInterval() async {
    if (_intervalMs <= 0) {
      _lastRequestStart = DateTime.now();
      return;
    }
    final wait =
        _intervalMs -
        DateTime.now().difference(_lastRequestStart).inMilliseconds;
    if (wait > 0) {
      await Future<void>.delayed(Duration(milliseconds: wait));
    }
    _lastRequestStart = DateTime.now();
  }

  // --- public API -------------------------------------------------------------

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

    final result = await _runProfile(text, config, null);

    if (_cache.length >= _cacheLimit) {
      _cache.remove(_cache.keys.first);
    }
    _cache[cacheKey] = result;
    return (text: result, providerLabel: _providerLabel(config));
  }

  /// Lists model ids from an OpenAI-compatible `/models` endpoint.
  Future<List<String>> fetchModels(TranslationConfig config) async {
    if (config.apiKey.trim().isEmpty) {
      throw const TranslationException('no API key configured');
    }
    final headers = {
      'Authorization': 'Bearer ${config.apiKey}',
      'Accept': 'application/json',
    };
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

  /// Runs one request exactly like [translate] would, but captures the
  /// rendered request, the raw response and the parse outcome instead of
  /// throwing. Used by the request configurator's test panel.
  Future<TranslationProbe> probe(TranslationConfig config, String text) async {
    final log = _ProbeLog();
    final watch = Stopwatch()..start();
    try {
      final parsed = await _runProfile(text, config, log);
      watch.stop();
      return TranslationProbe(
        status: log.status,
        elapsedMs: watch.elapsedMilliseconds,
        parsed: parsed,
        rawBody: log.rawBody,
        requestUrl: log.requestUrl,
        requestHeaders: log.requestHeaders ?? const {},
        requestBody: log.requestBody,
      );
    } on TranslationException catch (error) {
      watch.stop();
      return TranslationProbe(
        status: log.status ?? error.code,
        elapsedMs: watch.elapsedMilliseconds,
        rawBody: log.rawBody,
        error: error.message,
        errorDetail: error.detail,
        requestUrl: log.requestUrl,
        requestHeaders: log.requestHeaders ?? const {},
        requestBody: log.requestBody,
      );
    } on Object catch (error) {
      watch.stop();
      return TranslationProbe(
        status: log.status,
        elapsedMs: watch.elapsedMilliseconds,
        rawBody: log.rawBody,
        error: '$error',
        requestUrl: log.requestUrl,
        requestHeaders: log.requestHeaders ?? const {},
        requestBody: log.requestBody,
      );
    }
  }

  String _providerLabel(TranslationConfig config) => switch (config.provider) {
    TranslationProvider.google => TranslationProvider.google.label,
    TranslationProvider.googleChrome => TranslationProvider.googleChrome.label,
    TranslationProvider.microsoft => TranslationProvider.microsoft.label,
    TranslationProvider.azure => TranslationProvider.azure.label,
    TranslationProvider.openai => config.model,
  };

  // ---------------------------------------------------------------------------
  // Generic profile executor
  // ---------------------------------------------------------------------------

  void _checkProviderKey(TranslationConfig config) {
    final missing = switch (config.provider) {
      TranslationProvider.openai => config.apiKey.trim().isEmpty,
      TranslationProvider.azure => config.azureApiKey.trim().isEmpty,
      _ => false,
    };
    if (missing) {
      throw const TranslationException('no API key configured');
    }
  }

  Map<String, String> _baseVars(TranslationConfig config, String text) =>
      translationTemplateVars(config, text);

  /// Executes the provider profile: renders the request exactly as
  /// configured, performs it (chunked for long GET texts) and extracts the
  /// translation with the configured parse rule.
  Future<String> _runProfile(
    String text,
    TranslationConfig config,
    _ProbeLog? log,
  ) async {
    _checkProviderKey(config);
    final profile = config.profile;
    final vars = _baseVars(config, text);
    final headers = {
      for (final entry in profile.headers)
        if (entry.key.trim().isNotEmpty)
          entry.key.trim(): renderPlainTemplate(entry.value, vars),
    };
    final contentType = profile.effectiveContentType();
    if (contentType != null) headers['Content-Type'] = contentType;

    // GET URLs are length limited; long texts are split on line/sentence
    // boundaries and translated chunk by chunk.
    final chunks = profile.isGet ? splitForUrl(text, 1200) : [text];
    final parts = <String>[];
    try {
      for (final chunk in chunks) {
        final chunkVars = {...vars, 'text': chunk};
        final url = buildRequestUrl(profile, chunkVars);
        final body = profile.isGet
            ? null
            : renderJsonTemplate(profile.body, chunkVars);
        if (log != null) {
          log.requestUrl = url;
          log.requestHeaders = Map.of(headers);
          log.requestBody = body;
        }
        await _acquireSlot();
        try {
          await _awaitInterval();
          final response = await _dio.request<dynamic>(
            url,
            data: body,
            options: Options(
              method: profile.isGet ? 'GET' : 'POST',
              headers: headers,
              connectTimeout: _timeout,
              sendTimeout: _timeout,
              receiveTimeout: _timeout,
            ),
          );
          if (log != null) {
            log.status = response.statusCode;
            log.rawBody = _responseBody(response);
          }
          _validateStatus(response);
          parts.add(_extractTranslation(response, profile));
        } finally {
          _releaseSlot();
        }
      }
    } on TranslationException {
      rethrow;
    } on DioException catch (error) {
      throw _dioError(error);
    } on FormatException catch (error) {
      throw TranslationException(
        'unexpected response format',
        detail: error.message,
      );
    } on Object catch (error) {
      throw TranslationException('$error');
    }
    return parts.join();
  }

  /// Applies the parse rule to the response and returns the translation.
  String _extractTranslation(
    Response response,
    TranslationRequestProfile profile,
  ) {
    final rule = profile.parsePath.trim();
    if (rule.isEmpty) {
      // No parse rule: the raw body is the translation (plain-text APIs).
      final body = _responseBody(response);
      final result = _postProcess(body, profile);
      if (result.trim().isEmpty) {
        throw const TranslationException('empty translation');
      }
      return result;
    }
    var data = response.data;
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) {
        throw const TranslationException('unexpected response format');
      }
      try {
        data = jsonDecode(trimmed);
      } on FormatException {
        throw const TranslationException('unexpected response format');
      }
    }
    final value = resolveJsonPath(data, rule);
    final result = _postProcess('$value', profile);
    if (result.trim().isEmpty) {
      throw const TranslationException('empty translation');
    }
    return result;
  }

  /// Strips reasoning blocks and code fences (AI chat APIs).
  String _postProcess(String content, TranslationRequestProfile profile) {
    var result = content;
    if (profile.stripThink) {
      result = result
          .replaceAll(RegExp(r'<think>[\s\S]*?</think>', multiLine: true), '')
          .trim();
      final fence = RegExp(r'^```[a-zA-Z]*\n([\s\S]*)\n```$');
      final match = fence.firstMatch(result);
      if (match != null) result = match.group(1)!.trim();
    }
    return result;
  }

  /// Raw response body as text, for the probe and error details.
  String _responseBody(Response response) {
    final data = response.data;
    if (data is String) return data;
    if (data == null) return '';
    try {
      return jsonEncode(data);
    } on Object {
      return '$data';
    }
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
    final body = _responseBody(response).trim();
    if (body.isEmpty) return null;
    return body.length <= 200 ? body : '${body.substring(0, 200)}…';
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

/// Mutable capture buffer filled while a probe request runs.
class _ProbeLog {
  int? status;
  String? rawBody;
  String? requestUrl;
  Map<String, String>? requestHeaders;
  String? requestBody;
}
