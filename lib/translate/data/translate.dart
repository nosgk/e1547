/// Online translation providers supported by the app.
enum TranslationProvider {
  google,
  microsoft,
  openai;

  /// Display name used in UI and "translated by" captions.
  String get label => switch (this) {
    TranslationProvider.google => 'Google Translate',
    TranslationProvider.microsoft => 'Microsoft Translator',
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

/// Default request templates, shown pre-filled in the advanced settings and
/// used whenever the matching override is empty.
const String kGoogleUrlTemplate =
    'https://translate.googleapis.com/translate_a/single'
    '?client=gtx&sl=auto&tl=@toLang&dt=t&q=@text';
const String kGoogleDefaultHeaders = '{}';
const String kGoogleDefaultBody = '';

const String kMicrosoftUrlTemplate =
    'https://edge.microsoft.com/translate/translatetext?from=&to=@toLang';
const String kMicrosoftDefaultHeaders = '{"Accept": "application/json"}';
const String kMicrosoftDefaultBody = '["@text"]';

const String kOpenAiBodyTemplate =
    '{"model":"@model","temperature":0.3,"messages":'
    '[{"role":"system","content":"@systemPrompt"},'
    '{"role":"user","content":"@userPrompt"}]}';
const String kOpenAiDefaultHeaders =
    '{"Authorization": "Bearer @apiKey", "Accept": "application/json"}';

/// Immutable snapshot of everything the translation service needs to run.
class TranslationConfig {
  const TranslationConfig({
    required this.provider,
    required this.targetLanguage,
    this.apiKey = '',
    this.baseUrl = kDefaultOpenAiBaseUrl,
    this.model = kDefaultOpenAiModel,
    this.systemPrompt = kDefaultTranslationSystemPrompt,
    this.userPrompt = kDefaultTranslationUserPrompt,
    this.customUrl,
    this.customHeaders,
    this.customBody,
  });

  final TranslationProvider provider;

  /// Language code from [kTranslationLanguages].
  final String targetLanguage;

  // OpenAI-compatible settings.
  final String apiKey;
  final String baseUrl;
  final String model;
  final String systemPrompt;
  final String userPrompt;

  // Advanced per-provider overrides; null or empty means "use the default".
  final String? customUrl;
  final String? customHeaders;
  final String? customBody;

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

/// Error with a user-presentable message.
class TranslationException implements Exception {
  const TranslationException(this.message);

  final String message;

  @override
  String toString() => message;
}
