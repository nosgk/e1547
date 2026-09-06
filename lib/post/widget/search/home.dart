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
                            title: 'Quick search presets'.tr,
                          ),
                          ListTile(
                            leading: const Icon(Icons.bookmark_add_outlined),
                            title: Text('Save current as preset'.tr),
                            subtitle: Text(
                              tools.tags,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                            onTap: () => tools.addPreset(context),
                          ),
                          for (final (index, preset)
                              in tools.presets(settings).indexed)
                            ListTile(
                              leading: const Icon(Icons.bookmark_outline),
                              title: Text(
                                preset.name.isEmpty ? 'Preset'.tr : preset.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                preset.tags,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                              onTap: () => tools.applyPreset(preset),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit preset'.tr,
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        tools.editPreset(context, index),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete preset'.tr,
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        tools.deletePreset(context, index),
                                  ),
                                ],
                              ),
                            ),
                          if (tools.presets(settings).isEmpty)
                            ListTile(
                              enabled: false,
                              leading: const Icon(Icons.bookmark_border),
                              title: Text('No presets yet'.tr),
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
