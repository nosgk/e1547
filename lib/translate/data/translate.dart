import 'package:e1547/translate/data/profile.dart';

/// Online translation providers supported by the app.
enum TranslationProvider {
  google,
  googleChrome,
  microsoft,
  azure,
  openai;

  /// Display name used in UI and "translated by" captions.
  String get label => switch (this) {
    TranslationProvider.google => 'Google Translate (YT Comments)',
    TranslationProvider.googleChrome => 'Google Translate (Chrome API)',
    TranslationProvider.microsoft => 'Microsoft Translator',
    TranslationProvider.azure => 'Azure Translator',
    TranslationProvider.openai => 'AI Translation',
  };
}

/// Common target languages for the translation feature.
///
/// Keys are language codes sent to providers, values are native names shown
/// in the picker (intentionally not translated).
const Map<String, String> kTranslationLanguages = {
  'zh-CN': '简体中文',
  'zh-TW': '繁體中文',
  'en': 'English',
  'ja': '日本語',
  'ko': '한국어',
  'ru': 'Русский',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'pt': 'Português',
  'it': 'Italiano',
  'th': 'ไทย',
  'vi': 'Tiếng Việt',
  'id': 'Bahasa Indonesia',
  'ar': 'العربية',
};

const String kDefaultTranslationSystemPrompt =
    'You are a professional, authentic machine translation engine.';

const String kDefaultTranslationUserPrompt =
    'Translate the following text into @toLang. '
    'Preserve the original formatting: markdown, DText markup, HTML tags and '
    'line breaks must remain intact. If the text is already in the target '
    'language, return it unchanged. Return only the translation, without any '
    'explanation:\n\n@text';

const String kDefaultOpenAiBaseUrl = 'https://api.openai.com/v1';

const String kDefaultOpenAiModel = 'gpt-4o-mini';

/// Body template of OpenAI-compatible chat requests, referenced by the
/// OpenAI request preset.
const String kOpenAiBodyTemplate =
    '{"model":"@model","temperature":0.3,"messages":'
    '[{"role":"system","content":"@systemPrompt"},'
    '{"role":"user","content":"@userPrompt"}]}';

// Default values of the performance & rate limiting controls (edited in the
// request configurator).
const int kDefaultTranslateConcurrency = 1;
const int kDefaultTranslateIntervalMs = 0;
const int kDefaultTranslateTimeoutSeconds = 30;

/// Maximum characters sent in one request; 0 = unlimited. GET requests are
/// additionally capped by the URL length limit.
const int kDefaultTranslateMaxTextLength = 1200;

/// Maximum newline-separated paragraphs per request; 0 = unlimited.
const int kDefaultTranslateMaxParagraphs = 0;

/// Kinds of content that can be translated; each kind has its own display
/// mode (bilingual vs translation-only).
enum TranslationCategory {
  description,
  tag,
  comment,
  topicTitle,
  topicBody,
  pool,
  userProfile;

  /// Display name used in the settings.
  String get label => switch (this) {
    TranslationCategory.description => 'Post description',
    TranslationCategory.tag => 'Tags',
    TranslationCategory.comment => 'Comments',
    TranslationCategory.topicTitle => 'Forum titles',
    TranslationCategory.topicBody => 'Forum posts & replies',
    TranslationCategory.pool => 'Gallery title & description',
    TranslationCategory.userProfile => 'User profile',
  };
}

/// How a translation is shown: next to its original text (bilingual) or
/// replacing the original text once available (translation-only).
enum TranslationDisplayMode { bilingual, translationOnly }

extension TranslationDisplayModeLabel on TranslationDisplayMode {
  String get label => switch (this) {
    TranslationDisplayMode.bilingual => 'Bilingual',
    TranslationDisplayMode.translationOnly => 'Translation only',
  };
}

/// Immutable snapshot of everything the translation service needs to run.
class TranslationConfig {
  TranslationConfig({
    required this.provider,
    required this.targetLanguage,
    this.apiKey = '',
    this.baseUrl = kDefaultOpenAiBaseUrl,
    this.model = kDefaultOpenAiModel,
    this.systemPrompt = kDefaultTranslationSystemPrompt,
    this.userPrompt = kDefaultTranslationUserPrompt,
    this.azureApiKey = '',
    this.singleRequest = false,
    TranslationRequestProfile? profile,
  }) : profile = profile ?? defaultRequestProfile(provider);

  /// Sends the text in a single request without splitting. Used by tag
  /// translation, which translates one tag per request.
  final bool singleRequest;

  final TranslationProvider provider;

  /// Language code from [kTranslationLanguages].
  final String targetLanguage;

  // OpenAI-compatible settings.
  final String apiKey;
  final String baseUrl;
  final String model;
  final String systemPrompt;
  final String userPrompt;

  // Azure Cognitive settings.
  final String azureApiKey;

  /// The complete HTTP request description, including the response parsing
  /// rule. Built-in providers ship a preset; users can override every part
  /// of it in the request configurator.
  final TranslationRequestProfile profile;

  String get openaiChatUrl => baseUrl.endsWith('/')
      ? '${baseUrl}chat/completions'
      : '$baseUrl/chat/completions';

  String get openaiModelsUrl =>
      baseUrl.endsWith('/') ? '${baseUrl}models' : '$baseUrl/models';
}

/// Roughly detects text that is already Chinese, so auto translation can
/// skip it. Kana or hangul disqualify (Japanese/Korean), only Han counts.
bool translationLooksChinese(String text) {
  int han = 0;
  int otherScripts = 0;
  int total = 0;
  for (final rune in text.runes) {
    if (rune <= 0x20) continue;
    total++;
    if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF)) {
      han++;
    } else if ((rune >= 0x3040 && rune <= 0x30FF) ||
        (rune >= 0xAC00 && rune <= 0xD7AF)) {
      otherScripts++;
    }
  }
  return otherScripts == 0 && total > 0 && han / total > 0.25;
}

/// Error with a user-presentable message, optionally carrying the HTTP
/// status code and a short server response excerpt for diagnostics.
class TranslationException implements Exception {
  const TranslationException(this.message, {this.code, this.detail});

  final String message;

  /// HTTP status code, when the failure came from a response.
  final int? code;

  /// Short excerpt of the server error body, when available.
  final String? detail;

  @override
  String toString() => message;
}
