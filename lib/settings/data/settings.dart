import 'package:e1547/app/app.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/translate/data/translate.dart';
import 'package:flutter/foundation.dart';
import 'package:notified_preferences/notified_preferences.dart';

class Settings extends NotifiedSettings {
  Settings(super.preferences);

  static Future<Settings> getInstance() async =>
      Settings(await SharedPreferences.getInstance());

  late final ValueNotifier<int> identity = createSetting(
    key: 'identity',
    initialValue: 1,
  );

  late final ValueNotifier<bool> onboardingSeen = createSetting<bool>(
    key: 'onboardingSeen',
    initialValue: false,
  );

  late final ValueNotifier<AppTheme> theme = createEnumSetting(
    key: 'theme',
    initialValue: AppTheme.values.first,
    values: AppTheme.values,
  );

  /// App display language override: null = follow system locale,
  /// true = Chinese, false = English.
  late final ValueNotifier<bool?> language = createSetting<bool?>(
    key: 'language',
    initialValue: null,
  );

  late final ValueNotifier<int> tileSize = createSetting(
    key: 'tileSize',
    initialValue: 200,
  );
  late final ValueNotifier<GridQuilt> quilt = createEnumSetting(
    key: 'quilt',
    initialValue: GridQuilt.square,
    values: GridQuilt.values,
  );

  late final ValueNotifier<bool> filterUnseenFollows = createSetting(
    key: 'filterUnseenFollows',
    initialValue: false,
  );
  late final ValueNotifier<bool> showPostInfo = createSetting<bool>(
    key: 'showPostInfo',
    initialValue: false,
  );
  late final ValueNotifier<bool> upvoteFavs = createSetting<bool>(
    key: 'upvoteFavs',
    initialValue: false,
  );
  late final ValueNotifier<String?> downloadPath = createSetting<String?>(
    key: 'downloadPath',
    initialValue: null,
  );
  late final ValueNotifier<bool> muteVideos = createSetting<bool>(
    key: 'muteVideos',
    initialValue: true,
  );
  late final ValueNotifier<VideoResolution> videoResolution = createEnumSetting(
    key: 'videoResolution',
    initialValue: VideoResolution.source,
    values: VideoResolution.values,
  );

  /// Whether GIF posts play animated in grid/timeline previews.
  late final ValueNotifier<bool> previewAutoplayGifs = createSetting<bool>(
    key: 'previewAutoplayGifs',
    initialValue: false,
  );

  /// Whether video posts autoplay muted in grid/timeline previews.
  late final ValueNotifier<bool> previewAutoplayVideos = createSetting<bool>(
    key: 'previewAutoplayVideos',
    initialValue: false,
  );

  /// Video variant quality used for autoplaying previews.
  late final ValueNotifier<VideoResolution> previewVideoQuality =
      createEnumSetting(
        key: 'previewVideoQuality',
        initialValue: VideoResolution.standard,
        values: VideoResolution.values,
      );

  late final ValueNotifier<bool> secureDisplay = createSetting<bool>(
    key: 'secureDisplay',
    initialValue: false,
  );
  late final ValueNotifier<bool> incognitoKeyboard = createSetting<bool>(
    key: 'incognitoKeyboard',
    initialValue: false,
  );
  late final ValueNotifier<String?> appPin = createSetting(
    key: 'appPin',
    initialValue: null,
  );
  late final ValueNotifier<bool> biometricAuth = createSetting<bool>(
    key: 'biometricAuth',
    initialValue: false,
  );

  late final ValueNotifier<bool> showBeta = createSetting<bool>(
    key: 'showBeta',
    initialValue: false,
  );
  late final ValueNotifier<bool> verboseLogs = createSetting<bool>(
    key: 'verboseLogs',
    initialValue: false,
  );

  late final ValueNotifier<bool> showDev = createSetting<bool>(
    key: 'showDev',
    initialValue: false,
  );

  // -------------------------------------------------------------------------
  // Appearance
  // -------------------------------------------------------------------------

  /// Width of the navigation drawer in logical pixels.
  late final ValueNotifier<double> drawerWidth = createSetting<double>(
    key: 'drawerWidth',
    initialValue: 304,
  );

  /// Global font scale factor applied to all text themes.
  late final ValueNotifier<double> fontScale = createSetting<double>(
    key: 'fontScale',
    initialValue: 1,
  );

  /// When true, the platform default font is used and [customFontFamily] is
  /// ignored.
  late final ValueNotifier<bool> useSystemFont = createSetting<bool>(
    key: 'useSystemFont',
    initialValue: true,
  );

  /// Custom font family used across the app while [useSystemFont] is false.
  late final ValueNotifier<String> customFontFamily = createSetting(
    key: 'customFontFamily',
    initialValue: '',
  );

  // -------------------------------------------------------------------------
  // Online translation
  // -------------------------------------------------------------------------

  /// Master switch for the online translation feature.
  late final ValueNotifier<bool> translateEnabled = createSetting<bool>(
    key: 'translateEnabled',
    initialValue: false,
  );

  /// Whether descriptions and comments are translated automatically.
  late final ValueNotifier<bool> translateAuto = createSetting<bool>(
    key: 'translateAuto',
    initialValue: false,
  );

  /// Target language code; see kTranslationLanguages in the translate module.
  late final ValueNotifier<String> translateTargetLanguage = createSetting(
    key: 'translateTargetLanguage',
    initialValue: 'zh-CN',
  );

  /// Custom target languages, stored as JSON ("[{"code":"xx","name":"YY"}]").
  late final ValueNotifier<String> translateCustomLanguages = createSetting(
    key: 'translateCustomLanguages',
    initialValue: '[]',
  );

  late final ValueNotifier<TranslationProvider> translateProvider =
      createEnumSetting(
        key: 'translateProvider',
        initialValue: TranslationProvider.google,
        values: TranslationProvider.values,
      );

  // Azure Cognitive settings.
  late final ValueNotifier<String> translateAzureKey = createSetting(
    key: 'translateAzureKey',
    initialValue: '',
  );
  late final ValueNotifier<String> translateAzureEndpoint = createSetting(
    key: 'translateAzureEndpoint',
    initialValue: '',
  );
  late final ValueNotifier<String> translateAzureHeaders = createSetting(
    key: 'translateAzureHeaders',
    initialValue: '',
  );
  late final ValueNotifier<String> translateAzureBody = createSetting(
    key: 'translateAzureBody',
    initialValue: '',
  );

  /// Client-side request quota in requests per minute; 0 disables limiting.
  late final ValueNotifier<int> translateRateLimit = createSetting(
    key: 'translateRateLimit',
    initialValue: kDefaultTranslationRateLimit,
  );

  // OpenAI-compatible provider settings.
  late final ValueNotifier<String> translateApiKey = createSetting(
    key: 'translateApiKey',
    initialValue: '',
  );
  late final ValueNotifier<String> translateBaseUrl = createSetting(
    key: 'translateBaseUrl',
    initialValue: kDefaultOpenAiBaseUrl,
  );
  late final ValueNotifier<String> translateModel = createSetting(
    key: 'translateModel',
    initialValue: kDefaultOpenAiModel,
  );
  late final ValueNotifier<String> translateSystemPrompt = createSetting(
    key: 'translateSystemPrompt',
    initialValue: kDefaultTranslationSystemPrompt,
  );
  late final ValueNotifier<String> translateUserPrompt = createSetting(
    key: 'translateUserPrompt',
    initialValue: kDefaultTranslationUserPrompt,
  );

  // Advanced per-provider overrides; empty strings mean "use the default".
  late final ValueNotifier<String> translateGoogleUrl = createSetting(
    key: 'translateGoogleUrl',
    initialValue: '',
  );
  late final ValueNotifier<String> translateGoogleHeaders = createSetting(
    key: 'translateGoogleHeaders',
    initialValue: '',
  );
  late final ValueNotifier<String> translateGoogleBody = createSetting(
    key: 'translateGoogleBody',
    initialValue: '',
  );
  late final ValueNotifier<String> translateMicrosoftUrl = createSetting(
    key: 'translateMicrosoftUrl',
    initialValue: '',
  );
  late final ValueNotifier<String> translateMicrosoftHeaders = createSetting(
    key: 'translateMicrosoftHeaders',
    initialValue: '',
  );
  late final ValueNotifier<String> translateMicrosoftBody = createSetting(
    key: 'translateMicrosoftBody',
    initialValue: '',
  );
  late final ValueNotifier<String> translateOpenaiUrl = createSetting(
    key: 'translateOpenaiUrl',
    initialValue: '',
  );
  late final ValueNotifier<String> translateOpenaiHeaders = createSetting(
    key: 'translateOpenaiHeaders',
    initialValue: '',
  );
  late final ValueNotifier<String> translateOpenaiBody = createSetting(
    key: 'translateOpenaiBody',
    initialValue: '',
  );
}
