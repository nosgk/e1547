import 'dart:convert';

import 'package:e1547/markup/markup.dart';
import 'package:e1547/settings/settings.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/translate/translate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Builds a [TranslationConfig] from the current settings values, falling
/// back to defaults for empty optional fields. Also applies the configured
/// performance & rate limiting controls to the service.
TranslationConfig translationConfigFromSettings(
  Settings settings, {
  bool singleRequest = false,
}) {
  final service = TranslationService.instance;
  service.maxConcurrency = settings.translateConcurrency.value;
  service.requestIntervalMs = settings.translateIntervalMs.value;
  service.requestTimeoutSeconds = settings.translateTimeoutSeconds.value;
  service.maxTextLength = settings.translateMaxTextLength.value;
  service.maxParagraphs = settings.translateMaxParagraphs.value;
  service.retryCount = settings.translateRetryCount.value;
  TranslationCache.instance.limit = settings.translateCacheLimit.value;
  final provider = settings.translateProvider.value;
  return TranslationConfig(
    provider: provider,
    targetLanguage: settings.translateTargetLanguage.value,
    apiKey: settings.translateApiKey.value,
    baseUrl: settings.translateBaseUrl.value,
    model: settings.translateModel.value,
    systemPrompt: settings.translateSystemPrompt.value,
    userPrompt: settings.translateUserPrompt.value,
    azureApiKey: settings.translateAzureKey.value,
    singleRequest: singleRequest,
    profile: profileFromSettings(settings, provider),
  );
}

/// Reads the stored HTTP request profile of [provider], falling back to the
/// provider preset when nothing (valid) is stored.
TranslationRequestProfile profileFromSettings(
  Settings settings,
  TranslationProvider provider,
) {
  final stored = switch (provider) {
    TranslationProvider.google => settings.translateProfileGoogle.value,
    TranslationProvider.googleChrome =>
      settings.translateProfileGoogleChrome.value,
    TranslationProvider.microsoft => settings.translateProfileMicrosoft.value,
    TranslationProvider.azure => settings.translateProfileAzure.value,
    TranslationProvider.openai => settings.translateProfileOpenai.value,
  };
  return TranslationRequestProfile.tryDecode(stored) ??
      defaultRequestProfile(provider);
}

/// Parses a stored custom language list ("[{"code":"xx","name":"YY"},...]").
/// Malformed data yields an empty list.
List<MapEntry<String, String>> parseCustomLanguages(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    return [
      for (final entry in decoded)
        if (entry is Map &&
            entry['code'] is String &&
            (entry['code'] as String).trim().isNotEmpty)
          MapEntry(
            (entry['code'] as String).trim(),
            entry['name'] is String &&
                    (entry['name'] as String).trim().isNotEmpty
                ? (entry['name'] as String).trim()
                : (entry['code'] as String).trim(),
          ),
    ];
  } on FormatException {
    return const [];
  }
}

/// Serializes custom languages for storage.
String encodeCustomLanguages(List<MapEntry<String, String>> languages) {
  return jsonEncode([
    for (final language in languages)
      {'code': language.key, 'name': language.value},
  ]);
}

/// All languages selectable as translation targets: the built-in ones plus
/// the user's custom additions.
Map<String, String> availableTranslationLanguages(Settings settings) {
  return {
    ...kTranslationLanguages,
    ...Map.fromEntries(
      parseCustomLanguages(settings.translateCustomLanguages.value),
    ),
  };
}

/// Reads the online-translation master switch, or `null` when no Settings
/// provider is above this context (tests, standalone hosts). Call sites hide
/// their translation UI in that case, matching pre-feature behavior.
/// Returns the `translateEnabled` ValueListenable on success.
ValueListenable<bool>? tryTranslationEnabledOf(BuildContext context) {
  try {
    return context.read<Settings>().translateEnabled;
  } on Object {
    return null;
  }
}

/// Reads the Settings from the widget tree, or null when there is no
/// provider above this context (tests, standalone hosts).
Settings? trySettingsOf(BuildContext context) {
  try {
    return context.read<Settings>();
  } on Object {
    return null;
  }
}

/// Reads the display mode configured for [category]. Bilingual when no
/// settings are available or the category has no stored entry.
TranslationDisplayMode translationDisplayModeOf(
  Settings? settings,
  TranslationCategory category,
) {
  if (settings == null) return TranslationDisplayMode.bilingual;
  try {
    final decoded = jsonDecode(settings.translateDisplayModes.value);
    if (decoded is Map && decoded[category.name] == 'translationOnly') {
      return TranslationDisplayMode.translationOnly;
    }
  } on FormatException {
    // Fall through to the default.
  }
  return TranslationDisplayMode.bilingual;
}

/// Stores the display mode of [category]. Bilingual is stored as "absent"
/// (it is the default).
void setTranslationDisplayMode(
  Settings settings,
  TranslationCategory category,
  TranslationDisplayMode mode,
) {
  Map<String, dynamic> modes = {};
  try {
    final decoded = jsonDecode(settings.translateDisplayModes.value);
    if (decoded is Map) modes = decoded.cast<String, dynamic>();
  } on FormatException {
    // Start over with an empty map.
  }
  if (mode == TranslationDisplayMode.bilingual) {
    modes.remove(category.name);
  } else {
    modes[category.name] = mode.name;
  }
  settings.translateDisplayModes.value = jsonEncode(modes);
}

/// Whether the translation of [category] replaces its original text in this
/// context ("translation only" display mode).
bool translationReplacesOriginal(
  BuildContext context,
  TranslationCategory? category,
) {
  if (category == null) return false;
  return translationDisplayModeOf(trySettingsOf(context), category) ==
      TranslationDisplayMode.translationOnly;
}

void translateEntry(BuildContext context, TranslationEntry entry) {
  final ValueListenable<bool>? enabledListenable = tryTranslationEnabledOf(
    context,
  );
  if (enabledListenable == null || !enabledListenable.value) {
    // Make the silent gate visible: users tapping a translation affordance
    // while the feature is off get explicit feedback instead of nothing.
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('Online translation is disabled'.tr),
      ),
    );
    return;
  }
  if (entry.translation != null) {
    entry.expand();
    return;
  }
  entry.translate(translationConfigFromSettings(context.read<Settings>()));
}

/// Maps internal translation errors to localized messages.
String localizedTranslationError(String error) {
  return switch (error) {
    'connection timed out' => 'Translation timed out'.tr,
    'connection failed' => 'Translation connection failed'.tr,
    'network error' => 'Translation network error'.tr,
    'invalid API key' => 'Invalid API key'.tr,
    'rate limited' => 'Translation rate limited'.tr,
    'no API key configured' => 'No API key configured'.tr,
    'request cancelled' => 'Translation cancelled'.tr,
    'empty translation' => 'Translation returned nothing'.tr,
    'unexpected response format' => 'Unexpected translation response'.tr,
    'nothing to translate' => 'Nothing to translate'.tr,
    _ =>
      error.startsWith('server error') ? 'Translation server error'.tr : error,
  };
}

/// Name shown in "Translated by {name}" captions: the AI model for the
/// OpenAI-compatible provider, a compact provider name otherwise.
String translationProviderName(Settings settings) {
  if (settings.translateProvider.value == TranslationProvider.openai) {
    final model = settings.translateModel.value.trim();
    return model.isEmpty ? kDefaultOpenAiModel : model;
  }
  return settings.translateProvider.value.shortLabel;
}

/// Human-readable size of the translation cache ("12.3 KB", "1.2 MB").
String formatTranslationCacheSize(int bytes) {
  if (bytes <= 0) return '0 KB';
  if (bytes < 1024) return '<1 KB';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}

/// Creates a translation entry for [text], starting auto translation if the
/// settings ask for it. For custom multi-entry layouts; prefer
/// [TranslatableHost] for the common single-text case.
///
/// [auto] overrides the global auto-translation switch (tag translation
/// passes true when its page toggle is on). [singleRequest] sends the text
/// in one request without splitting.
TranslationEntry createTranslationEntry(
  BuildContext context,
  String text, {
  bool? auto,
  bool singleRequest = false,
}) {
  final entry = TranslationEntry(text: text);
  _maybeAutoTranslateEntry(
    context,
    entry,
    auto: auto,
    singleRequest: singleRequest,
  );
  return entry;
}

void _maybeAutoTranslateEntry(
  BuildContext context,
  TranslationEntry entry, {
  bool? auto,
  bool singleRequest = false,
}) {
  if (entry.autoAttempted) return;
  try {
    final settings = context.read<Settings>();
    if (!settings.translateEnabled.value) return;
    if (!(auto ?? settings.translateAuto.value)) return;
    if (settings.translateTargetLanguage.value.startsWith('zh') &&
        translationLooksChinese(entry.text)) {
      entry.skipAuto();
      return;
    }
    entry.translate(
      translationConfigFromSettings(settings, singleRequest: singleRequest),
    );
  } on Object {
    // Settings are not available in tests; auto translation is best-effort.
  }
}

/// Owns the [TranslationEntry] for [text] and hands it to [builder].
///
/// Place this around the original text and wherever the trigger button and
/// the translated text should appear. When auto translation is enabled (or
/// [auto] is true), the translation starts as soon as the host mounts (once,
/// skipping text that already looks like the target language).
class TranslatableHost extends StatefulWidget {
  const TranslatableHost({
    super.key,
    required this.text,
    required this.builder,
    this.auto,
    this.singleRequest = false,
  });

  final String text;
  final Widget Function(BuildContext context, TranslationEntry entry) builder;

  /// Overrides the global auto-translation switch; null follows the setting.
  final bool? auto;
  final bool singleRequest;

  @override
  State<TranslatableHost> createState() => _TranslatableHostState();
}

class _TranslatableHostState extends State<TranslatableHost> {
  TranslationEntry? _entry;

  TranslationEntry _create() => createTranslationEntry(
    context,
    widget.text,
    auto: widget.auto,
    singleRequest: widget.singleRequest,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _entry ??= _create();
  }

  @override
  void didUpdateWidget(covariant TranslatableHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _entry?.dispose();
      _entry = _create();
    }
  }

  @override
  void dispose() {
    _entry?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entry!,
      builder: (context, child) => widget.builder(context, _entry!),
    );
  }
}

/// Lightweight trigger for a translation.
///
/// [compact] renders a small icon button that fits into action rows (e.g.
/// next to comment votes); the default renders a small text button suited
/// for the end of a description card. Hidden entirely while the translation
/// feature is switched off.
class TranslationButton extends StatelessWidget {
  const TranslationButton({
    super.key,
    required this.entry,
    this.compact = false,
    this.category,
  });

  final TranslationEntry entry;
  final bool compact;

  /// Category of the translated content, used to honor the per-category
  /// display mode ("translation only" shows a "show original" toggle).
  final TranslationCategory? category;

  @override
  Widget build(BuildContext context) {
    final enabledListenable = tryTranslationEnabledOf(context);
    if (enabledListenable == null) {
      // No Settings provider (tests, standalone hosts): hide the button.
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<bool>(
      valueListenable: enabledListenable,
      builder: (context, enabled, child) {
        if (!enabled) return const SizedBox.shrink();
        return AnimatedBuilder(
          animation: entry,
          builder: (context, child) {
            final loaded =
                entry.status == TranslationStatus.success &&
                entry.translation != null;
            if (loaded && entry.expanded && !compact) {
              if (translationReplacesOriginal(context, category)) {
                // The original is replaced by the translation, so the
                // button becomes the way back to the original text.
                return Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: entry.collapse,
                    icon: const Icon(Icons.keyboard_arrow_up, size: 16),
                    label: Text('Show original'.tr),
                  ),
                );
              }
              // The full display carries its own collapse control.
              return const SizedBox.shrink();
            }
            if (entry.status == TranslationStatus.loading) {
              if (compact) {
                return const SizedBox(
                  width: 32,
                  height: 24,
                  child: Center(
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              return TextButton.icon(
                onPressed: null,
                icon: const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                label: const Text(''),
              );
            }
            final failed = entry.status == TranslationStatus.error;
            if (compact) {
              return Dimmed(
                child: IconButton(
                  tooltip: failed
                      ? 'Retry'.tr
                      : loaded
                      ? (entry.expanded
                            ? 'Collapse translation'.tr
                            : 'Show translation'.tr)
                      : 'Translate'.tr,
                  icon: Icon(
                    loaded
                        ? (entry.expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.translate)
                        : (failed ? Icons.refresh : Icons.translate),
                    size: 16,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    if (loaded) {
                      entry.expanded ? entry.collapse() : entry.expand();
                    } else {
                      translateEntry(context, entry);
                    }
                  },
                ),
              );
            }
            final label = (loaded ? 'Show translation' : 'Translate').tr;
            return Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () => translateEntry(context, entry),
                icon: Icon(failed ? Icons.refresh : Icons.translate, size: 16),
                label: Text(failed ? 'Retry'.tr : label),
              ),
            );
          },
        );
      },
    );
  }
}

/// Shows the translated text below the original, with an attribution
/// caption and a collapse control. Renders nothing while idle or loading.
///
/// [compact] drops the caption and collapse row down to the dimmed text
/// alone, for dense layouts like tiles and app bars; pair it with a compact
/// [TranslationButton], which toggles the expansion.
class TranslationDisplay extends StatelessWidget {
  const TranslationDisplay({
    super.key,
    required this.entry,
    this.compact = false,
    this.category,
  });

  final TranslationEntry entry;
  final bool compact;

  /// Category of the translated content. In "translation only" display
  /// mode the expanded translation is hidden here, because
  /// [TranslationOriginal] already renders it in place of the original.
  final TranslationCategory? category;

  @override
  Widget build(BuildContext context) {
    final settings = trySettingsOf(context);
    return AnimatedBuilder(
      animation: settings == null
          ? entry
          : Listenable.merge([entry, settings.translateDisplayModes]),
      builder: (context, child) {
        return AnimatedSize(
          duration: defaultAnimationDuration,
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: switch (entry.status) {
            TranslationStatus.error => _error(context),
            TranslationStatus.success when entry.expanded => _content(context),
            _ => const SizedBox(width: double.infinity),
          },
        );
      },
    );
  }

  /// Whether the original spot currently shows the translation already.
  bool _replacedByOriginal(BuildContext context) {
    return category != null &&
        entry.translation != null &&
        translationReplacesOriginal(context, category);
  }

  Widget _error(BuildContext context) {
    final code = entry.errorCode;
    final detail = entry.errorDetail;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 14,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  localizedTranslationError(entry.error ?? ''),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          if (code != null || detail != null)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 2),
              child: Text(
                [
                  if (code != null) 'HTTP $code',
                  if (detail != null) detail,
                ].join(' · '),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: dimTextColor(context)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    final translation = entry.translation!;
    if (_replacedByOriginal(context)) {
      // The original spot already renders the translation; showing it here
      // again would duplicate the text.
      return const SizedBox(width: double.infinity);
    }
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: DText(
          translation,
          style: TextStyle(
            color: dimTextColor(context, 0.8),
            fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DText(
            translation,
            style: TextStyle(color: dimTextColor(context, 0.8)),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Translated by {provider}'.trArgs({
                    'provider': entry.providerLabel ?? '',
                  }),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: dimTextColor(context)),
                ),
              ),
              GestureDetector(
                onTap: entry.collapse,
                child: Text(
                  'Collapse translation'.tr,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: dimTextColor(context)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Wraps the original content of a translatable text.
///
/// In "translation only" display mode, the original is replaced by the
/// translated text as soon as the translation is expanded; in bilingual
/// mode (and while loading / on errors) [original] renders unchanged. Pair
/// with a [TranslationDisplay] carrying the same [category].
class TranslationOriginal extends StatelessWidget {
  const TranslationOriginal({
    super.key,
    required this.category,
    required this.entry,
    required this.original,
    this.replacementBuilder,
  });

  final TranslationCategory category;
  final TranslationEntry entry;
  final Widget original;

  /// Builds the widget shown in place of [original] while the translation
  /// replaces it. Falls back to a [DText] rendering of the translation.
  final Widget Function(BuildContext context, String translation)?
  replacementBuilder;

  @override
  Widget build(BuildContext context) {
    final settings = trySettingsOf(context);
    if (settings == null) return original;
    return AnimatedBuilder(
      animation: Listenable.merge([entry, settings.translateDisplayModes]),
      builder: (context, child) {
        final translation = entry.translation;
        if (translationDisplayModeOf(settings, category) ==
                TranslationDisplayMode.translationOnly &&
            entry.status == TranslationStatus.success &&
            translation != null &&
            entry.expanded) {
          final builder = replacementBuilder;
          return builder != null
              ? builder(context, translation)
              : DText(translation);
        }
        return original;
      },
    );
  }
}

/// Scoped switch for tag translation (the gallery and post detail page
/// toolbar toggles). Tag widgets inside the scope translate their names
/// while [enabled] is true — independent of the global auto-translation
/// setting.
class TagTranslationScope extends InheritedWidget {
  const TagTranslationScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  final ValueNotifier<bool> enabled;

  /// The scoped tag-translation switch, or null when outside any scope.
  static ValueNotifier<bool>? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TagTranslationScope>()
      ?.enabled;

  @override
  bool updateShouldNotify(TagTranslationScope oldWidget) =>
      !identical(oldWidget.enabled, enabled);
}

/// App-bar toggle for tag translation on the post detail page, placed next
/// to the overflow menu. Reads the surrounding [TagTranslationScope] and
/// renders nothing outside one. While active, a small "Translated by …"
/// caption names the configured service (the AI model for AI translation).
class TagTranslationToggle extends StatelessWidget {
  const TagTranslationToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = TagTranslationScope.maybeOf(context);
    final settings = trySettingsOf(context);
    if (scope == null || settings == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: Listenable.merge([
        scope,
        settings.translateEnabled,
        settings.translateProvider,
        settings.translateModel,
      ]),
      builder: (context, child) {
        final enabled = scope.value;
        final button = IconButton(
          tooltip: 'Translate tags'.tr,
          icon: const Icon(Icons.sell_outlined),
          onPressed: () {
            if (!settings.translateEnabled.value) {
              // Make the silent gate visible instead of flipping a switch
              // that cannot do anything while translation is disabled.
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 2),
                  content: Text('Online translation is disabled'.tr),
                ),
              );
              return;
            }
            scope.value = !enabled;
          },
        );
        if (!enabled || !settings.translateEnabled.value) {
          return Dimmed(child: button);
        }
        final caption = 'Translated by {provider}'.trArgs({
          'provider': translationProviderName(settings),
        });
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: dimTextColor(context)),
                ),
              ),
            ),
            button,
          ],
        );
      },
    );
  }
}
