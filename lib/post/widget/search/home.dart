import 'package:e1547/client/client.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/query/query.dart';
import 'package:e1547/settings/settings.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/tag/tag.dart';
import 'package:e1547/traits/traits.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sub/flutter_sub.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final client = context.watch<Client>();
    return RouterDrawerEntry<HomePage>(
      child: FilterControllerProvider(
        create: (_) => PostFilter(client),
        keys: (_) => [client],
        child: ChangeNotifierProvider(
          create: (_) => PostParamsController(
            initial: PostParams(tags: client.traits.value.homeTags),
          ),
          builder: (context, _) => SubValueListener(
            listenable: context.watch<PostParamsController>(),
            listener: (PostParams value) => client.traits.value = client
                .traits
                .value
                .copyWith(homeTags: value.tags ?? ''),
            builder: (context, _) => PostPageHistoryConnector(
              child: PostPageQueryBuilder(
                builder: (context, state, query) {
                  // Below the params controller provider, so the quick
                  // tools can read the live controller.
                  final tools = SearchTools(
                    context.watch<PostParamsController>(),
                  );
                  final settings = context.watch<Settings>();
                  return SelectionLayout<Post>(
                    items: state.data?.pages.expand((p) => p).toList(),
                    child: AdaptiveScaffold(
                      appBar: const PostSelectionAppBar(
                        child: DefaultAppBar(
                          title: Center(child: AppIcon()),
                          actions: [ContextDrawerButton()],
                        ),
                      ),
                      floatingActionButton: const PostsPageFab(),
                      drawer: const RouterDrawer(),
                      endDrawer: ContextDrawer(
                        title: Text('Posts'.tr),
                        children: [
                          SearchPresetGroup(
                            title: 'Quick search presets'.tr,
                            presets: settings.explorePresets,
                            addTags: tools.tags,
                            onSave: (original, updated) =>
                                tools.savePreset(context, original, updated),
                            onDelete: (preset) =>
                                tools.deletePreset(context, preset),
                            onApply: tools.applyPreset,
                          ),
                          const Divider(),
                          const DrawerDenySwitch(),
                          DrawerTagCounter(
                            posts: state.data?.pages.expand((p) => p).toList(),
                            error: state.error,
                          ),
                          const Divider(),
                          SectionHeader(
                            indent: SectionHeader.listTileIndent,
                            title: 'Quick sort'.tr,
                          ),
                          Builder(
                            builder: (context) {
                              final dateTerm = tools.termOf('date:');
                              return ListTile(
                                leading: const Icon(Icons.event_outlined),
                                title: Text('Post date'.tr),
                                subtitle: Text(
                                  dateTerm ?? 'No date filter'.tr,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: dateTerm == null
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear date filter'.tr,
                                        icon: const Icon(Icons.close, size: 18),
                                        onPressed: () => tools.applyTags(
                                          tools.withTerm('date:', null),
                                        ),
                                      ),
                                onTap: () => tools.pickDate(context),
                              );
                            },
                          ),
                          Builder(
                            builder: (context) {
                              final orderTerm = tools.termOf('order:');
                              return ListTile(
                                leading: const Icon(Icons.sort_outlined),
                                title: Text('Order'.tr),
                                subtitle: Text(
                                  orderTerm == null
                                      ? '—'
                                      : (tools.orderLabel(orderTerm) ??
                                            orderTerm),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () => tools.pickOrder(context),
                              );
                            },
                          ),
                          const Divider(),
                          SectionHeader(
                            indent: SectionHeader.listTileIndent,
                            title: 'Play modes'.tr,
                          ),
                          for (final game in kPlayGames)
                            SwitchListTile(
                              secondary: Icon(game.icon),
                              title: Text(game.name.tr),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    game.description.tr,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: dimTextColor(context),
                                        ),
                                  ),
                                  Text(
                                    game.terms.join(' '),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              value: tools.hasTokens(game.terms),
                              onChanged: (_) => tools.toggleTokens(game.terms),
                            ),
                          ValueListenableBuilder<bool>(
                            valueListenable: settings.gameGacha,
                            builder: (context, value, child) => SwitchListTile(
                              secondary: const Icon(Icons.blur_on_outlined),
                              title: Text('Gacha roll'.tr),
                              subtitle: Text(
                                'Every thumbnail stays blurred until revealed'
                                    .tr,
                              ),
                              value: value,
                              onChanged: (value) {
                                settings.gameGacha.value = value;
                                if (!value) GameReveals.instance.clearPosts();
                              },
                            ),
                          ),
                          ValueListenableBuilder<bool>(
                            valueListenable: settings.gameQuiz,
                            builder: (context, value, child) => SwitchListTile(
                              secondary: const Icon(Icons.quiz_outlined),
                              title: Text('Artist quiz'.tr),
                              subtitle: Text(
                                'The artist is hidden; can you tell?'.tr,
                              ),
                              value: value,
                              onChanged: (value) {
                                settings.gameQuiz.value = value;
                                if (!value) GameReveals.instance.clearArtists();
                              },
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              final slotTag = settings.slotTag.value;
                              return ListTile(
                                leading: const Icon(Icons.casino_outlined),
                                title: Text('Universal slot'.tr),
                                subtitle: slotTag.isEmpty
                                    ? Text(
                                        'Roll a random tag from a chosen '
                                                'category'
                                            .tr,
                                      )
                                    : Text(
                                        slotTag,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                        ),
                                      ),
                                trailing: slotTag.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear slot tag'.tr,
                                        icon: const Icon(Icons.close, size: 18),
                                        onPressed: () =>
                                            tools.clearSlotTag(settings),
                                      ),
                                onTap: () async {
                                  final tag = await showTagSlotDialog(
                                    context,
                                    tags: context.read<Client>().tags,
                                  );
                                  if (tag != null && context.mounted) {
                                    tools.swapSlotTag(tag, settings);
                                  }
                                },
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.slideshow_outlined),
                            title: Text('Zen slideshow'.tr),
                            subtitle: Text('Fullscreen auto-advancing show'.tr),
                            onTap: () {
                              Navigator.of(context).pop();
                              showSlideshowPicker(
                                context,
                                initialTags: tools.tags,
                              );
                            },
                          ),
                        ],
                      ),
                      body: LimitedWidthLayout(
                        child: ListenableBuilder(
                          listenable: context.watch<Settings>().tileSize,
                          builder: (context, child) => TileLayout(
                            tileSize: context.watch<Settings>().tileSize.value,
                            child: const PostList(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
