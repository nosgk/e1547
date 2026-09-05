import 'dart:math';

import 'package:e1547/client/client.dart';
import 'package:e1547/markup/markup.dart';
import 'package:e1547/pool/pool.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/query/query.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/tag/tag.dart';
import 'package:e1547/translate/translate.dart';
import 'package:flutter/material.dart';

class PoolTile extends StatelessWidget {
  const PoolTile({super.key, required this.pool, this.onPressed});

  final Pool pool;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    Widget? image;

    if (pool.postIds.isNotEmpty) {
      final client = context.watch<Client>();
      final thumbnailId = pool.postIds.first;
      image = QueryBuilder(
        query: client.posts.useGet(id: thumbnailId, vendored: true),
        builder: (context, state) {
          final post = state.data;
          if (post == null) return const SizedBox.shrink();
          final filter = context.watch<FilterController<Post>?>();
          if (filter != null && !filter.filter(post)) {
            return const SizedBox.shrink();
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: AspectRatio(
                aspectRatio: max(post.width / post.height, 0.9),
                child: PostImageTile(post: post),
              ),
            ),
          );
        },
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(4),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: AnimatedSize(
                  duration: defaultAnimationDuration,
                  child: _PoolTileText(pool: pool, image: image),
                ),
              ),
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: onPressed,
                    onLongPress: () =>
                        showPoolPrompt(context: context, pool: pool),
                    onSecondaryTap: () =>
                        showPoolPrompt(context: context, pool: pool),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(indent: 8, endIndent: 8),
      ],
    );
  }
}

/// Title and description of a pool tile, with a single control that
/// translates both at once. The description is never truncated.
class _PoolTileText extends StatefulWidget {
  const _PoolTileText({required this.pool, this.image});

  final Pool pool;
  final Widget? image;

  @override
  State<_PoolTileText> createState() => _PoolTileTextState();
}

class _PoolTileTextState extends State<_PoolTileText> {
  TranslationEntry? _title;
  TranslationEntry? _description;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _title ??= createTranslationEntry(context, tagToName(widget.pool.name));
    if (widget.pool.description.isNotEmpty) {
      _description ??= createTranslationEntry(context, widget.pool.description);
    }
  }

  @override
  void didUpdateWidget(covariant _PoolTileText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pool.name != widget.pool.name ||
        oldWidget.pool.description != widget.pool.description) {
      _title?.dispose();
      _description?.dispose();
      _title = createTranslationEntry(context, tagToName(widget.pool.name));
      _description = widget.pool.description.isNotEmpty
          ? createTranslationEntry(context, widget.pool.description)
          : null;
    }
  }

  @override
  void dispose() {
    _title?.dispose();
    _description?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _title!;
    final description = _description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TranslationOriginal(
                  category: TranslationCategory.pool,
                  entry: title,
                  original: Text(
                    tagToName(widget.pool.name),
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                  ),
                  replacementBuilder: (context, text) => Text(
                    text,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                widget.pool.postIds.length.toString(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              _PoolTileTranslateButton(title: title, description: description),
            ],
          ),
        ),
        TranslationDisplay(
          entry: title,
          compact: true,
          category: TranslationCategory.pool,
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Opacity(
              opacity: 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslationOriginal(
                    category: TranslationCategory.pool,
                    entry: description,
                    original: DText(widget.pool.description),
                  ),
                  TranslationDisplay(
                    entry: description,
                    compact: true,
                    category: TranslationCategory.pool,
                  ),
                ],
              ),
            ),
          ),
        if (widget.image != null) widget.image!,
      ],
    );
  }
}

/// One compact trigger translating (and toggling) a pool tile's title and
/// description together.
class _PoolTileTranslateButton extends StatelessWidget {
  const _PoolTileTranslateButton({
    required this.title,
    required this.description,
  });

  final TranslationEntry title;
  final TranslationEntry? description;

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
        final entries = [title, if (description != null) description!];
        return AnimatedBuilder(
          animation: Listenable.merge(entries),
          builder: (context, child) {
            final anyLoading = entries.any(
              (e) => e.status == TranslationStatus.loading,
            );
            if (anyLoading) {
              return const Dimmed(
                child: SizedBox(
                  width: 28,
                  height: 24,
                  child: Center(
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              );
            }
            final loaded = entries.where((e) => e.translation != null).toList();
            final failed = entries.any(
              (e) => e.status == TranslationStatus.error,
            );
            final expanded = entries.any((e) => e.expanded);
            return Dimmed(
              child: IconButton(
                tooltip: failed
                    ? 'Retry'.tr
                    : loaded.isEmpty
                    ? 'Translate'.tr
                    : (expanded
                          ? 'Collapse translation'.tr
                          : 'Show translation'.tr),
                icon: Icon(
                  loaded.isEmpty
                      ? (failed ? Icons.refresh : Icons.translate)
                      : (expanded ? Icons.keyboard_arrow_up : Icons.translate),
                  size: 16,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  if (loaded.isEmpty) {
                    for (final entry in entries) {
                      translateEntry(context, entry);
                    }
                  } else {
                    for (final entry in loaded) {
                      expanded ? entry.collapse() : entry.expand();
                    }
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
