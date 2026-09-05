import 'package:e1547/client/client.dart';
import 'package:e1547/follow/follow.dart';
import 'package:e1547/pool/pool.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/query/query.dart';
import 'package:e1547/settings/settings.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/tag/tag.dart';
import 'package:e1547/traits/traits.dart';
import 'package:e1547/translate/translate.dart';
import 'package:flutter/material.dart';

class PoolPage extends StatefulWidget {
  const PoolPage({super.key, required this.pool, this.orderByOldest});

  final Pool pool;
  final bool? orderByOldest;

  @override
  State<PoolPage> createState() => _PoolPageState();
}

class _PoolPageState extends State<PoolPage> {
  late final ValueNotifier<bool> _tagTranslation;

  @override
  void initState() {
    super.initState();
    // The toolbar toggle starts from the global tag auto-translate setting.
    _tagTranslation = ValueNotifier(
      context.read<Settings>().translateTagsAuto.value,
    );
  }

  @override
  void dispose() {
    _tagTranslation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pool = widget.pool;
    final orderByOldest = widget.orderByOldest ?? true;
    final client = context.watch<Client>();
    return TranslatableHost(
      text: tagToName(pool.name),
      builder: (context, translation) => TagTranslationScope(
        enabled: _tagTranslation,
        child: FilterControllerProvider(
          create: (_) => PostFilter(client),
          keys: (_) => [client],
          child: ChangeNotifierProvider(
            create: (_) => PostParamsController(
              initial: PostParams(
                tags: orderByOldest
                    ? 'pool:${pool.id} order:pool'
                    : 'pool:${pool.id} order:${PostOrder.newest.value}',
              ),
              canSearch: false,
            ),
            child: ChangeNotifierProvider(
              create: (_) => PostDisplayController(PostDisplayType.comic),
              child: PoolHistoryConnector(
                pool: pool,
                child: FollowSeenConnector(
                  child: PostPageQueryBuilder(
                    builder: (context, state, query) => SelectionLayout<Post>(
                      items: state.data?.pages.expand((p) => p).toList(),
                      child: AdaptiveScaffold(
                        appBar: PostSelectionAppBar(
                          child: DefaultAppBar(
                            title: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TranslationOriginal(
                                  category: TranslationCategory.pool,
                                  entry: translation,
                                  original: Text(
                                    tagToName(pool.name),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  replacementBuilder: (context, text) => Text(
                                    text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TranslationDisplay(
                                  entry: translation,
                                  compact: true,
                                  category: TranslationCategory.pool,
                                ),
                              ],
                            ),
                            actions: [
                              TranslationButton(
                                entry: translation,
                                compact: true,
                                category: TranslationCategory.pool,
                              ),
                              IconButton(
                                icon: const Icon(Icons.info_outline),
                                tooltip: 'Info'.tr,
                                onPressed: () => showPoolPrompt(
                                  context: context,
                                  pool: pool,
                                ),
                              ),
                              ValueListenableBuilder<bool>(
                                valueListenable: _tagTranslation,
                                builder: (context, value, child) {
                                  final button = IconButton(
                                    tooltip: 'Translate tags'.tr,
                                    icon: const Icon(Icons.sell_outlined),
                                    onPressed: () =>
                                        _tagTranslation.value = !value,
                                  );
                                  return value ? button : Dimmed(child: button);
                                },
                              ),
                              const ContextDrawerButton(),
                            ],
                          ),
                        ),
                        endDrawer: ContextDrawer(
                          title: Text('Pool'.tr),
                          children: [
                            const PoolReaderSwitch(),
                            const PoolOrderSwitch(),
                            const DrawerDenySwitch(),
                            DrawerTagCounter(
                              posts: state.data?.pages
                                  .expand((p) => p)
                                  .toList(),
                              error: state.error,
                            ),
                          ],
                        ),
                        body: LimitedWidthLayout(
                          child: ListenableBuilder(
                            listenable: context.watch<Settings>().tileSize,
                            builder: (context, child) => TileLayout(
                              tileSize: context
                                  .watch<Settings>()
                                  .tileSize
                                  .value,
                              child: const PostList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PoolOrderSwitch extends StatelessWidget {
  const PoolOrderSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PostParamsController>();
    final oldestFirst = controller.value.poolOldestFirst;
    return SwitchListTile(
      secondary: const Icon(Icons.sort),
      title: Text('Pool order'.tr),
      subtitle: Text(oldestFirst ? 'oldest first'.tr : 'newest first'.tr),
      value: oldestFirst,
      onChanged: (value) {
        final next = TagMap(controller.value.tags);
        if (value) {
          next['order'] = 'pool';
        } else {
          next['order'] = PostOrder.newest.value;
        }
        controller.update((p) => p.copyWith(tags: next.toString()));
      },
    );
  }
}

class PoolReaderSwitch extends StatelessWidget {
  const PoolReaderSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final display = context.watch<PostDisplayController>();
    final readerMode = display.value == PostDisplayType.comic;
    return SwitchListTile(
      secondary: const Icon(Icons.auto_stories),
      title: Text('Pool reader mode'.tr),
      subtitle: Text(readerMode ? 'large images'.tr : 'normal grid'.tr),
      value: readerMode,
      onChanged: (value) {
        display.value = value ? PostDisplayType.comic : PostDisplayType.grid;
        Scaffold.of(context).closeEndDrawer();
      },
    );
  }
}
