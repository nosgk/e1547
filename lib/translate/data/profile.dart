import 'dart:convert';

import 'package:e1547/translate/data/translate.dart';

/// A fully transparent description of one HTTP translation request.
///
/// Everything the request needs — method, URL, query parameters, headers,
/// body and the response parsing rule — lives in this profile. There are no
/// hidden defaults: the service sends exactly what is configured here.
///
/// Templates may reference variables via `@token` placeholders, see
/// [kTranslationVariables]. Substitution rules:
///
/// - URL template & query values: percent-encoded, except `@baseUrl`
///   which is substituted verbatim (it is structural, not data).
/// - Header values: substituted verbatim.
/// - Body: a quoted token (`"@text"`) is replaced with the JSON-encoded
///   value so strings keep valid escaping; a bare token is replaced
///   verbatim (for numbers or raw JSON injection).
class TranslationRequestProfile {
  const TranslationRequestProfile({
    this.method = 'GET',
    required this.url,
    this.query = const [],
    this.headers = const [],
    this.contentType = '',
    this.body = '',
    this.parsePath = '',
    this.stripThink = false,
  });

  factory TranslationRequestProfile.fromJson(Map<String, dynamic> json) {
    List<MapEntry<String, String>> pairs(dynamic raw) => [
      if (raw is List)
        for (final row in raw)
          if (row is List && row.isNotEmpty)
            MapEntry('${row[0]}', row.length > 1 ? '${row[1]}' : ''),
    ];
    return TranslationRequestProfile(
      method: json['method'] == 'POST' ? 'POST' : 'GET',
      url: '${json['url'] ?? ''}',
      query: pairs(json['query']),
      headers: pairs(json['headers']),
      contentType: '${json['contentType'] ?? ''}',
      body: '${json['body'] ?? ''}',
      parsePath: '${json['parsePath'] ?? ''}',
      stripThink: json['stripThink'] == true,
    );
  }

  /// HTTP method, `GET` or `POST`.
  final String method;

  /// URL template; may contain its own inline query string.
  final String url;

  /// Query parameters appended to [url], as ordered key/value templates.
  final List<MapEntry<String, String>> query;

  /// Request headers, as ordered key/value templates.
  final List<MapEntry<String, String>> headers;

  /// Content-Type used for the body when no explicit Content-Type header
  /// row is present. Ignored for GET requests (no body).
  final String contentType;

  /// Body template; empty for GET requests.
  final String body;

  /// Rule to extract the translated text from the JSON response, e.g.
  /// `$[0][0]` or `$.choices[0].message.content`. `[n]` indexes arrays,
  /// `[*]` joins every element of an array, `.key` reads object keys and
  /// the leading `$` (root) is optional. Empty means "use the raw
  /// response body as the translation".
  final String parsePath;

  /// Strips `<think>…</think>` blocks and code fences from the result;
  /// used by AI chat APIs whose models leak reasoning into the content.
  final bool stripThink;

  bool get isGet => method.toUpperCase() == 'GET';

  Map<String, dynamic> toJson() => {
    'method': method,
    'url': url,
    'query': [
      for (final e in query) [e.key, e.value],
    ],
    'headers': [
      for (final e in headers) [e.key, e.value],
    ],
    if (contentType.isNotEmpty) 'contentType': contentType,
    if (body.isNotEmpty) 'body': body,
    'parsePath': parsePath,
    if (stripThink) 'stripThink': true,
  };

  /// Decodes a stored profile; returns null when empty or malformed so the
  /// caller falls back to the preset.
  static TranslationRequestProfile? tryDecode(String stored) {
    if (stored.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map) return null;
      return TranslationRequestProfile.fromJson(
        decoded.cast<String, dynamic>(),
      );
    } on FormatException {
      return null;
    }
  }

  String encode() => jsonEncode(toJson());

  /// Copy with individual fields replaced (used by the configurator UI).
  TranslationRequestProfile copyWith({
    String? method,
    String? url,
    List<MapEntry<String, String>>? query,
    List<MapEntry<String, String>>? headers,
    String? contentType,
    String? body,
    String? parsePath,
    bool? stripThink,
  }) => TranslationRequestProfile(
    method: method ?? this.method,
    url: url ?? this.url,
    query: query ?? this.query,
    headers: headers ?? this.headers,
    contentType: contentType ?? this.contentType,
    body: body ?? this.body,
    parsePath: parsePath ?? this.parsePath,
    stripThink: stripThink ?? this.stripThink,
  );

  /// The effective Content-Type of the request: an explicit header row wins,
  /// otherwise [contentType] applies when a body is present.
  String? effectiveContentType() {
    final explicit = headers.any(
      (header) => header.key.trim().toLowerCase() == 'content-type',
    );
    if (explicit || isGet || body.trim().isEmpty) return null;
    final type = contentType.trim();
    return type.isEmpty ? 'application/json' : type;
  }
}

/// The built-in request of every translation provider. Users can override
/// any part of it in the request configurator.
TranslationRequestProfile defaultRequestProfile(TranslationProvider provider) =>
    switch (provider) {
      // Unofficial free web endpoint; GET with URL-length-limited requests.
      TranslationProvider.google => const TranslationRequestProfile(
        url: 'https://translate.googleapis.com/translate_a/single',
        query: [
          MapEntry('client', 'gtx'),
          MapEntry('sl', 'auto'),
          MapEntry('tl', '@toLang'),
          MapEntry('dt', 't'),
          MapEntry('q', '@text'),
        ],
        parsePath: r'$[0][*][0]',
      ),
      // Endpoint used by YouTube/Chrome; JSON+protobuf body, no rate limit.
      TranslationProvider.googleChrome => const TranslationRequestProfile(
        method: 'POST',
        url: 'https://translate-pa.googleapis.com/v1/translateHtml',
        headers: [
          MapEntry('X-Goog-API-Key', 'AIzaSyATBXajvzQLTDHEQbcpq0Ihe0vWDHmO520'),
        ],
        contentType: 'application/json+protobuf',
        body: '[[["@text"],"@fromLang","@toLang"],"wt_lib"]',
        parsePath: r'$[0][0]',
      ),
      TranslationProvider.microsoft => const TranslationRequestProfile(
        method: 'POST',
        url: 'https://edge.microsoft.com/translate/translatetext',
        query: [MapEntry('from', ''), MapEntry('to', '@toLang')],
        headers: [MapEntry('Accept', 'application/json')],
        contentType: 'application/json',
        body: '["@text"]',
        parsePath: r'$[0].translations[0].text',
      ),
      TranslationProvider.azure => const TranslationRequestProfile(
        method: 'POST',
        url: 'https://api.cognitive.microsofttranslator.com/translate',
        query: [
          MapEntry('api-version', '3.0'),
          MapEntry('to', '@toLang'),
          MapEntry('textType', 'plain'),
        ],
        headers: [
          MapEntry('Ocp-Apim-Subscription-Key', '@azureKey'),
          MapEntry('Accept', 'application/json'),
        ],
        contentType: 'application/json',
        body: '[{"Text":"@text"}]',
        parsePath: r'$[0].translations[0].text',
      ),
      TranslationProvider.openai => const TranslationRequestProfile(
        method: 'POST',
        url: '@baseUrl/chat/completions',
        headers: [
          MapEntry('Authorization', 'Bearer @apiKey'),
          MapEntry('Accept', 'application/json'),
        ],
        contentType: 'application/json',
        body: kOpenAiBodyTemplate,
        parsePath: r'$.choices[0].message.content',
        stripThink: true,
      ),
    };

/// Documentation of every variable usable in request templates, shown (and
/// insertable) in the request configurator.
const List<TranslationVariableInfo> kTranslationVariables = [
  TranslationVariableInfo(
    name: 'text',
    description:
        'Text to translate; percent-encoded in URLs, JSON-escaped '
        'as "@text" in bodies',
  ),
  TranslationVariableInfo(
    name: 'toLang',
    description: 'Target language code, e.g. zh-CN',
  ),
  TranslationVariableInfo(
    name: 'toLangName',
    description: 'Target language native name, e.g. 简体中文',
  ),
  TranslationVariableInfo(
    name: 'fromLang',
    description: 'Source language code, always "auto"',
  ),
  TranslationVariableInfo(
    name: 'apiKey',
    description: 'API key of the AI translation service',
  ),
  TranslationVariableInfo(
    name: 'azureKey',
    description: 'Azure Translator key',
  ),
  TranslationVariableInfo(
    name: 'baseUrl',
    description: 'AI Base URL; substituted verbatim (never encoded)',
  ),
  TranslationVariableInfo(name: 'model', description: 'AI model name'),
  TranslationVariableInfo(
    name: 'systemPrompt',
    description: 'AI system prompt',
  ),
  TranslationVariableInfo(
    name: 'userPrompt',
    description: 'Rendered AI user prompt (already contains the text)',
  ),
];

class TranslationVariableInfo {
  const TranslationVariableInfo({
    required this.name,
    required this.description,
  });

  final String name;
  final String description;
}

// ---------------------------------------------------------------------------
// Template rendering
// ---------------------------------------------------------------------------

/// Builds the variable map available to request templates. The same map
/// drives the service and the configurator's live preview, so what users
/// see previewed is exactly what gets sent.
Map<String, String> translationTemplateVars(
  TranslationConfig config,
  String text,
) {
  final targetName =
      kTranslationLanguages[config.targetLanguage] ?? config.targetLanguage;
  return {
    'text': text,
    'toLang': config.targetLanguage,
    'fromLang': 'auto',
    'toLangName': targetName,
    'apiKey': config.apiKey,
    'azureKey': config.azureApiKey,
    'baseUrl': config.baseUrl,
    'model': config.model,
    'systemPrompt': config.systemPrompt,
    'userPrompt': config.userPrompt
        .replaceAll('@toLang', targetName)
        .replaceAll('@text', text),
  };
}

/// Renders a plain-text template (header values), substituting verbatim.
String renderPlainTemplate(String template, Map<String, String> vars) {
  var result = template;
  for (final entry in vars.entries) {
    result = result.replaceAll('@${entry.key}', entry.value);
  }
  return result;
}

/// Renders a URL template. Values are percent-encoded, except `@baseUrl`
/// which is substituted verbatim because it is part of the URL structure.
String renderUrlTemplate(String template, Map<String, String> vars) {
  final baseUrl = vars['baseUrl'];
  var result = template;
  if (baseUrl != null) {
    result = result.replaceAll('@baseUrl', baseUrl);
  }
  for (final entry in vars.entries) {
    if (entry.key == 'baseUrl') continue;
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
String renderJsonTemplate(String template, Map<String, String> vars) {
  var result = template;
  for (final entry in vars.entries) {
    result = result.replaceAll('"@${entry.key}"', jsonEncode(entry.value));
  }
  for (final entry in vars.entries) {
    result = result.replaceAll('@${entry.key}', entry.value);
  }
  return result;
}

/// Builds the full request URL: renders the URL template, then appends the
/// profile's query parameters (rendered and percent-encoded) with a proper
/// `?` / `&` separator.
String buildRequestUrl(
  TranslationRequestProfile profile,
  Map<String, String> vars,
) {
  var url = renderUrlTemplate(profile.url, vars);
  final params = profile.query
      .where((entry) => entry.key.trim().isNotEmpty)
      .toList();
  if (params.isEmpty) return url;
  final queryString = params
      .map(
        (entry) =>
            '${Uri.encodeComponent(renderPlainTemplate(entry.key, vars))}'
            '='
            '${Uri.encodeComponent(renderPlainTemplate(entry.value, vars))}',
      )
      .join('&');
  return url.contains('?') ? '$url&$queryString' : '$url?$queryString';
}

// ---------------------------------------------------------------------------
// Response parsing
// ---------------------------------------------------------------------------

final RegExp _pathTokenRe = RegExp(r'\.([A-Za-z0-9_\-]+)|\[(\*|-?\d+)\]');

/// Extracts a value from a decoded JSON response following a small
/// JSONPath-style syntax: `$` (optional root), `.key` for object keys,
/// `[n]` for array indices and `[*]` to join every array element.
/// Example: `$[0][*][0]` or `$.choices[0].message.content`.
Object? resolveJsonPath(Object? data, String path) {
  var input = path.trim();
  if (input.isEmpty || input == r'$') return data;
  if (input.startsWith(r'$')) input = input.substring(1);
  final match = _pathTokenRe.matchAsPrefix(input);
  if (match == null) {
    throw FormatException('invalid parse path: $path');
  }
  final rest = input.substring(match.end);
  if (match.group(1) != null) {
    final key = match.group(1)!;
    if (data is! Map) {
      throw FormatException('expected an object at "$key"');
    }
    if (!data.containsKey(key)) {
      throw FormatException('missing key "$key"');
    }
    return resolveJsonPath(data[key], rest);
  }
  final bracket = match.group(2)!;
  if (bracket == '*') {
    if (data is! List) {
      throw const FormatException('expected an array at [*]');
    }
    final buffer = StringBuffer();
    for (final element in data) {
      final value = resolveJsonPath(element, rest);
      if (value != null) buffer.write('$value');
    }
    return buffer.toString();
  }
  final index = int.tryParse(bracket);
  if (index == null) throw FormatException('invalid parse path: $path');
  if (data is! List) {
    throw FormatException('expected an array at [$index]');
  }
  if (index < 0 || index >= data.length) {
    throw FormatException('index [$index] out of range');
  }
  return resolveJsonPath(data[index], rest);
}

// ---------------------------------------------------------------------------
// Body helpers (validation / formatting for the configurator UI)
// ---------------------------------------------------------------------------

/// Validates [body] as JSON; returns null when valid, otherwise a short
/// error description. Bodies that are not JSON-shaped (e.g. form data)
/// should not use this.
String? validateJsonBody(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return null;
  try {
    jsonDecode(trimmed);
    return null;
  } on FormatException catch (error) {
    return error.message;
  }
}

/// Pretty-prints [body] as JSON (2-space indent). Throws [FormatException]
/// when the body is not valid JSON.
String formatJsonBody(String body) {
  final decoded = jsonDecode(body.trim());
  return const JsonEncoder.withIndent('  ').convert(decoded);
}
