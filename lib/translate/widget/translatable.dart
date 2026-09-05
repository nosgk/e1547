import 'package:e1547/markup/markup.dart';
import 'package:e1547/settings/settings.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/translate/translate.dart';
import 'package:flutter/material.dart';

/// Builds a [TranslationConfig] from the current settings values.
TranslationConfig translationConfigFromSettings(Settings settings) {
  final provider = settings.translateProvider.value;
  return TranslationConfig(
    provider: provider,
    targetLanguage: settings.translateTargetLanguage.value,
    apiKey: settings.translateApiKey.value,
    baseUrl: settings.translateBaseUrl.value,
    model: settings.translateModel.value,
    systemPrompt: settings.translateSystemPrompt.value,
    userPrompt: settings.translateUserPrompt.value,
    customUrl: switch (provider) {
      TranslationProvider.google => settings.translateGoogleUrl.value,
      TranslationProvider.microsoft => settings.translateMicrosoftUrl.value,
      TranslationProvider.openai => settings.translateOpenaiUrl.value,
    },
    customHeaders: switch (provider) {
      TranslationProvider.google => settings.translateGoogleHeaders.value,
      TranslationProvider.microsoft => settings.translateMicrosoftHeaders.value,
      TranslationProvider.openai => settings.translateOpenaiHeaders.value,
    },
    customBody: switch (provider) {
      TranslationProvider.google => settings.translateGoogleBody.value,
      TranslationProvider.microsoft => settings.translateMicrosoftBody.value,
      TranslationProvider.openai => settings.translateOpenaiBody.value,
    },
  );
}

/// Starts or re-runs the translation for [entry] using current settings.
void translateEntry(BuildContext context, TranslationEntry entry) {
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

/// Owns the [TranslationEntry] for [text] and hands it to [builder].
///
/// Place this around the original text and wherever the trigger button and
/// the translated text should appear. When auto translation is enabled, the
/// translation starts as soon as the host mounts (once, skipping text that
/// already looks like the target language).
class TranslatableHost extends StatefulWidget {
  const TranslatableHost({
    super.key,
    required this.text,
    required this.builder,
  });

  final String text;
  final Widget Function(BuildContext context, TranslationEntry entry) builder;

  @override
  State<TranslatableHost> createState() => _TranslatableHostState();
}

class _TranslatableHostState extends State<TranslatableHost> {
  late TranslationEntry entry;

  @override
  void initState() {
    super.initState();
    entry = TranslationEntry(text: widget.text);
    _maybeAutoTranslate();
  }

  @override
  void didUpdateWidget(covariant TranslatableHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      entry.dispose();
      entry = TranslationEntry(text: widget.text);
      _maybeAutoTranslate();
    }
  }

  @override
  void dispose() {
    entry.dispose();
    super.dispose();
  }

  void _maybeAutoTranslate() {
    try {
      final settings = context.read<Settings>();
      if (!settings.translateEnabled.value) return;
      if (!settings.translateAuto.value) return;
      if (entry.autoAttempted) return;
      if (settings.translateTargetLanguage.value.startsWith('zh') &&
          translationLooksChinese(entry.text)) {
        entry.skipAuto();
        return;
      }
      entry.translate(translationConfigFromSettings(settings));
    } on Object {
      // Settings are not available in tests; auto translation is optional.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: entry,
      builder: (context, child) => widget.builder(context, entry),
    );
  }
}

/// Lightweight trigger for a translation.
///
/// [compact] renders a small icon button that fits into action rows (e.g.
/// next to comment votes); the default renders a small text button suited
/// for the end of a description card.
class TranslationButton extends StatelessWidget {
  const TranslationButton({
    super.key,
    required this.entry,
    this.compact = false,
  });

  final TranslationEntry entry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: entry,
      builder: (context, child) {
        if (entry.status == TranslationStatus.success && entry.expanded) {
          // The translation display carries its own collapse control.
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
        final label =
            (entry.translation != null ? 'Show translation' : 'Translate').tr;
        if (compact) {
          return Dimmed(
            child: IconButton(
              tooltip: failed ? 'Retry'.tr : label,
              icon: Icon(failed ? Icons.refresh : Icons.translate, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: () => translateEntry(context, entry),
            ),
          );
        }
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
  }
}

/// Shows the translated text below the original, with an attribution
/// caption and a collapse control. Renders nothing while idle or loading.
class TranslationDisplay extends StatelessWidget {
  const TranslationDisplay({super.key, required this.entry});

  final TranslationEntry entry;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: entry,
      builder: (context, child) {
        if (entry.status == TranslationStatus.error) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
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
                TranslationButton(entry: entry, compact: true),
              ],
            ),
          );
        }
        if (entry.status != TranslationStatus.success || !entry.expanded) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DText(
                entry.translation!,
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: dimTextColor(context),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: entry.collapse,
                    child: Text(
                      'Collapse translation'.tr,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: dimTextColor(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
