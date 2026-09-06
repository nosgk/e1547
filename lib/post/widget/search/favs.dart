import 'package:e1547/client/client.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/query/query.dart';
import 'package:e1547/settings/settings.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/tag/tag.dart';
import 'package:e1547/traits/traits.dart';
import 'package:flutter/material.dart';

class FavPage extends StatelessWidget {
  const FavPage({super.key});

  @override
  Widget build(BuildContext context) {
    final client = context.watch<Client>();
    return RouterDrawerEntry<FavPage>(
      child: client.identity.username == null
          ? AdaptiveScaffold(
              appBar: DefaultAppBar(title: Text('Favorites'.tr)),
              body: IconMessage(
                icon: const Icon(Icons.person_search),
                title: Text('Favorites are unavailable for anonymous users'.tr),
              ),
            )
          : FilterControllerProvider<PostFilter, Post>(
              create: (_) => FavoritePostFilter(client),
              keys: (_) => [client],
              child: ChangeNotifierProvider(
                create: (_) => PostParamsController(
                  initial: PostParams(tags: 'fav:${client.identity.username}'),
                ),
                child: PostPageHistoryConnector(
                  child: PostPageQueryBuilder(
                    builder: (context, state, query) => SelectionLayout<Post>(
                      items: state.data?.pages.expand((p) => p).toList(),
                      child: AdaptiveScaffold(
                        appBar: const PostSelectionAppBar(
                          child: PostPageAppBar(),
                        ),
                        floatingActionButton: const PostsPageFab(),
                        drawer: const RouterDrawer(),
                        endDrawer: ContextDrawer(
                          title: Text('Posts'.tr),
                          children: [
                            const FavoriteOrderSwitch(),
                            const Divider(),
                            SearchPresetGroup(
                              title: 'Peeks'.tr,
                              presets: context.watch<Settings>().favoritePeeks,
                              addSubtitle:
                                  'Save other users favorites as searches'.tr,
                              onApply: (preset) => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => PostsPage(
                                    params: PostParams(tags: preset.tags),
                                  ),
                                ),
                              ),
                              onAdd: () => _addPeek(context),
                              onSave: (original, updated) =>
                                  _savePeek(context, original, updated),
                              onDelete: (preset) =>
                                  _deletePeek(context, preset),
                            ),
                            const Divider(),
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
    );
  }
}

class FavoriteOrderSwitch extends StatelessWidget {
  const FavoriteOrderSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PostParamsController>();
    final tags = TagMap(controller.value.tags);
    final order = tags['order'];
    final addedOrder = order == null || order == 'fav';
    return SwitchListTile(
      secondary: const Icon(Icons.sort),
      title: Text('Favorite order'.tr),
      subtitle: Text(addedOrder ? 'added order'.tr : 'id order'.tr),
      value: addedOrder,
      onChanged: (value) {
        final next = TagMap(controller.value.tags);
        if (value) {
          next.remove('order');
        } else {
          next['order'] = PostOrder.newest.value;
        }
        controller.update((p) => p.copyWith(tags: next.toString()));
      },
    );
  }
}

/// Opens a username prompt and stores `fav:<name>` as a peek preset.
Future<void> _addPeek(BuildContext context) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Peek'.tr),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Username'.tr,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('CANCEL'.tr),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text('Save'.tr),
        ),
      ],
    ),
  );
  if (name == null || !context.mounted) return;
  final username = name.trim();
  if (username.isEmpty) return;
  await _savePeek(
    context,
    const SearchPreset(name: '', tags: ''),
    SearchPreset(
      name: 'Saved {user} favorites'.trArgs({'user': username}),
      tags: 'fav:$username',
    ),
  );
}

Future<void> _savePeek(
  BuildContext context,
  SearchPreset original,
  SearchPreset updated,
) async {
  if (updated.tags.isEmpty) return;
  final settings = context.read<Settings>();
  final peeks = parseSearchPresets(settings.favoritePeeks.value);
  final index = peeks.indexOf(original);
  if (index >= 0) {
    peeks[index] = updated;
  } else {
    peeks.add(updated);
  }
  settings.favoritePeeks.value = encodeSearchPresets(peeks);
  if (index < 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('Peek saved'.tr),
      ),
    );
  }
}

Future<void> _deletePeek(BuildContext context, SearchPreset preset) async {
  final settings = context.read<Settings>();
  final peeks = parseSearchPresets(settings.favoritePeeks.value)
    ..remove(preset);
  settings.favoritePeeks.value = encodeSearchPresets(peeks);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 2),
      content: Text('Peek deleted'.tr),
    ),
  );
}
