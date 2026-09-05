import 'package:e1547/post/post.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/tag/tag.dart';
import 'package:e1547/translate/translate.dart';
import 'package:flutter/material.dart';

class TagCard extends StatelessWidget {
  const TagCard({super.key, required this.tag, this.category});

  final String tag;
  final String? category;

  @override
  Widget build(BuildContext context) {
    return ColoredCard(
      color:
          (category != null ? TagCategory.byName(category!)?.color : null) ??
          Colors.grey,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PostsPage(params: PostParams(tags: tag)),
        ),
      ),
      onLongPress: () => showTagSearchPrompt(context: context, tag: tag),
      onSecondaryTap: () => showTagSearchPrompt(context: context, tag: tag),
      child: TranslatedTagText(tag: tag),
    );
  }
}

class TagCounterCard extends StatelessWidget {
  const TagCounterCard({
    super.key,
    required this.tag,
    required this.count,
    this.category,
  });

  final String tag;
  final int count;
  final String? category;

  @override
  Widget build(BuildContext context) {
    return ColoredCard(
      onTap: () => showTagSearchPrompt(context: context, tag: tag),
      onLongPress: () => showTagSearchPrompt(context: context, tag: tag),
      onSecondaryTap: () => showTagSearchPrompt(context: context, tag: tag),
      color: (category != null ? TagCategory.byName(category!)?.color : null),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 2,
            height: 18,
            color: Theme.of(context).dividerColor,
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(count.toString()),
            ),
          ),
        ],
      ),
      child: TranslatedTagText(tag: tag),
    );
  }
}

class DenyListTagCard extends StatelessWidget {
  const DenyListTagCard(this.tag, {super.key});

  final String tag;

  Color? getTagColor(String tag) {
    String prefix = tag[0];
    switch (prefix) {
      case '-':
        return Colors.green[300];
      case '~':
        return Colors.orange[300];
      case '#':
        return Colors.blue[300];
      default:
        return Colors.red[300];
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredCard(
      color: getTagColor(tag),
      onTap: () => showTagSearchPrompt(context: context, tag: tag),
      onLongPress: () => showTagSearchPrompt(context: context, tag: tag),
      onSecondaryTap: () => showTagSearchPrompt(context: context, tag: tag),
      child: Text(tagToTitle(tag), overflow: TextOverflow.ellipsis),
    );
  }
}

/// Tag name text with its translation, when tag translation is active:
/// either the surrounding [TagTranslationScope] toggle is on (gallery page
/// toolbar) or the global tag auto-translate setting. Each tag is translated
/// with a single request; failures fall back to the plain name.
class TranslatedTagText extends StatelessWidget {
  const TranslatedTagText({super.key, required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final settings = trySettingsOf(context);
    if (settings == null) return _plain(context);
    final scope = TagTranslationScope.maybeOf(context);
    return AnimatedBuilder(
      animation: Listenable.merge([
        settings.translateEnabled,
        settings.translateTagsAuto,
        settings.translateDisplayModes,
        if (scope != null) scope,
      ]),
      builder: (context, _) {
        final active =
            settings.translateEnabled.value &&
            ((scope?.value ?? false) || settings.translateTagsAuto.value);
        if (!active) return _plain(context);
        return TranslatableHost(
          text: tagToName(tag),
          auto: true,
          singleRequest: true,
          builder: (context, entry) => AnimatedBuilder(
            animation: entry,
            builder: (context, _) => _content(context, entry),
          ),
        );
      },
    );
  }

  Widget _plain(BuildContext context) =>
      Text(tagToTitle(tag), maxLines: 1, overflow: TextOverflow.ellipsis);

  Widget _content(BuildContext context, TranslationEntry entry) {
    final plain = _plain(context);
    final translation = entry.translation;
    final settings = trySettingsOf(context);
    if (entry.status != TranslationStatus.success ||
        translation == null ||
        !entry.expanded ||
        settings == null) {
      return plain;
    }
    if (translationDisplayModeOf(settings, TranslationCategory.tag) ==
        TranslationDisplayMode.translationOnly) {
      return Text(translation, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        plain,
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            translation,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: dimTextColor(context)),
          ),
        ),
      ],
    );
  }
}
