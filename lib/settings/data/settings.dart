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

  /// Disk budget of the media file cache, in megabytes. 0 = unlimited.
  /// When the budget is exceeded the oldest cache entries are evicted.
  late final ValueNotifier<int> mediaCacheLimitMb = createSetting(
    key: 'mediaCacheLimitMb',
    initialValue: 0,
  );

  /// Saved post searches ("[{name, tags}]") with remarks, managed in the
  /// home page's settings drawer. The storage key predates the feature's
  /// move and is kept so saved entries survive updates.
  late final ValueNotifier<String> explorePresets = createSetting(
    key: 'explorePresets',
    initialValue: '[]',
  );

  /// Play modes over the home feed: gacha blurs thumbnails until tapped,
  /// the artist quiz hides the artist until revealed.
  late final ValueNotifier<bool> gameGacha = createSetting<bool>(
    key: 'gameGacha',
    initialValue: false,
  );
  late final ValueNotifier<bool> gameQuiz = createSetting<bool>(
    key: 'gameQuiz',
    initialValue: false,
  );

  /// Saved other-user favorite searches ("[{name, tags}]"), managed from
  /// the user menu and the favorites page drawer.
  late final ValueNotifier<String> favoritePeeks = createSetting(
    key: 'favoritePeeks',
    initialValue: '[]',
  );

  /// The tag currently applied by the universal slot machine, so a reroll
  /// can replace it in the query.
  late final ValueNotifier<String> slotTag = createSetting(
    key: 'slotTag',
    initialValue: '',
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

  /// Whether tag names are translated automatically wherever they show.
  late final ValueNotifier<bool> translateTagsAuto = createSetting<bool>(
    key: 'translateTagsAuto',
    initialValue: false,
  );

  /// Display mode per translation category ("description" → "bilingual" /
  /// "translationOnly"); missing entries mean bilingual.
  late final ValueNotifier<String> translateDisplayModes = createSetting(
    key: 'translateDisplayModes',
    initialValue: '{}',
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

  // Performance & rate limiting (edited in the request configurator).
  late final ValueNotifier<int> translateConcurrency = createSetting(
    key: 'translateConcurrency',
    initialValue: kDefaultTranslateConcurrency,
  );
  late final ValueNotifier<int> translateIntervalMs = createSetting(
    key: 'translateIntervalMs',
    initialValue: kDefaultTranslateIntervalMs,
  );
  late final ValueNotifier<int> translateTimeoutSeconds = createSetting(
    key: 'translateTimeoutSeconds',
    initialValue: kDefaultTranslateTimeoutSeconds,
  );
  late final ValueNotifier<int> translateMaxTextLength = createSetting(
    key: 'translateMaxTextLength',
    initialValue: kDefaultTranslateMaxTextLength,
  );
  late final ValueNotifier<int> translateMaxParagraphs = createSetting(
    key: 'translateMaxParagraphs',
    initialValue: kDefaultTranslateMaxParagraphs,
  );
  late final ValueNotifier<int> translateRetryCount = createSetting(
    key: 'translateRetryCount',
    initialValue: kDefaultTranslateRetryCount,
  );

  // Translation cache: maximum entry count (0 = unlimited), edited next to
  // the cache statistics & clear control in the translation settings.
  late final ValueNotifier<int> translateCacheLimit = createSetting(
    key: 'translateCacheLimit',
    initialValue: kDefaultTranslateCacheLimit,
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

  // Per-provider HTTP request profiles ("advanced customization"); empty
  // means "use the preset". Edited in the request configurator.
  late final ValueNotifier<String> translateProfileGoogle = createSetting(
    key: 'translateProfileGoogle',
    initialValue: '',
  );
  late final ValueNotifier<String> translateProfileGoogleChrome = createSetting(
    key: 'translateProfileGoogleChrome',
    initialValue: '',
  );
  late final ValueNotifier<String> translateProfileMicrosoft = createSetting(
    key: 'translateProfileMicrosoft',
    initialValue: '',
  );
  late final ValueNotifier<String> translateProfileAzure = createSetting(
    key: 'translateProfileAzure',
    initialValue: '',
  );
  late final ValueNotifier<String> translateProfileOpenai = createSetting(
    key: 'translateProfileOpenai',
    initialValue: '',
  );
}
