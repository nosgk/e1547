import 'package:e1547/client/client.dart';
import 'package:e1547/follow/follow.dart';
import 'package:e1547/pool/pool.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/query/query.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/tag/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sub/flutter_sub.dart';
import 'package:intl/intl.dart';

class PostPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PostPageAppBar({super.key, this.actions});

  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final map = TagMap(context.watch<PostParamsController>().value.tags);
    final showInfo =
        map.isNotEmpty && map['order'] != 'rank' && map['fav'] == null;

    return DefaultAppBar(
      title: const Row(
        children: [
          Flexible(child: _PostPageTitle()),
          _PostSearchCount(),
        ],
      ),
      actions: [
        if (showInfo) const _PostPageInfoButton(),
        ...?actions,
        const ContextDrawerButton(),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _PostPageInfoButton extends StatelessWidget {
  const _PostPageInfoButton();

  @override
  Widget build(BuildContext context) {
    final params = context.watch<PostParamsController>().value;
    final tags = params.tags ?? '';
    final poolId = params.poolId;

    Widget button({Pool? pool}) => IconButton(
      icon: const Icon(Icons.info_outline),
      onPressed: () => pool != null
          ? showPoolPrompt(context: context, pool: pool)
          : showTagSearchPrompt(context: context, tag: tags),
    );

    if (poolId == null) return button();

    return QueryBuilder(
      query: context.watch<Client>().pools.useGet(id: poolId, vendored: true),
      builder: (context, state) => button(pool: state.data),
    );
  }
}

class _PostPageTitle extends StatelessWidget {
  const _PostPageTitle();

  @override
  Widget build(BuildContext context) {
    final client = context.watch<Client>();
    final params = context.watch<PostParamsController>().value;
    final tags = params.tags ?? '';
    final map = TagMap(tags);

    if (map.isEmpty) return _title(context, 'Search'.tr);
    if (map['order'] == 'rank') return _title(context, 'Hot'.tr);
    final fav = map['fav'];
    if (fav != null) {
      return _title(
        context,
        fav == client.identity.username
            ? 'Favorites'.tr
            : "{fav}'s Favorites".trArgs({'fav': fav}),
      );
    }

    final fallback = tagToName(map.toString());

    final poolId = params.poolId;
    if (poolId != null) {
      return QueryBuilder(
        query: client.pools.useGet(id: poolId, vendored: true),
        builder: (context, state) => _title(
          context,
          state.data != null ? tagToName(state.data!.name) : fallback,
        ),
      );
    }

    return SubFuture<Follow?>(
      keys: [tags, client],
      create: () => client.follows.getByTags(tags: tags),
      builder: (context, snapshot) =>
          _title(context, snapshot.data?.name ?? fallback),
    );
  }

  Widget _title(BuildContext context, String text) =>
      Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
}

/// Total for the current search, beside the title. Bare tags resolve via
/// the tags index (exact at any size); every other query uses the posts
/// count endpoint, which truncates at ~240k — rendered as "{count}+".
class _PostSearchCount extends StatelessWidget {
  const _PostSearchCount();

  @override
  Widget build(BuildContext context) {
    final map = TagMap(context.watch<PostParamsController>().value.tags);
    // Nothing to count on an empty search, and order:rank (Hot) does not
    // filter, so its total would just be the whole site.
    if (map.isEmpty || map['order'] == 'rank') {
      return const SizedBox.shrink();
    }
    final bare =
        map.length == 1 &&
        map.values.single.isEmpty &&
        !map.keys.single.startsWith('-') &&
        !map.keys.single.startsWith('~') &&
        !map.keys.single.contains('(');
    final client = context.watch<Client>();
    return bare
        ? QueryBuilder(
            query: client.tags.useCount(tag: map.keys.single),
            builder: (context, state) => _count(context, state.data, false),
          )
        : QueryBuilder(
            query: client.posts.useCount(tags: map.toString()),
            builder: (context, state) {
              final data = state.data;
              return _count(context, data?.count, data?.capped ?? false);
            },
          );
  }

  Widget _count(BuildContext context, int? value, bool capped) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Text(
          '{count} results'.trArgs({
            'count':
                NumberFormat.decimalPattern().format(value) +
                (capped ? '+' : ''),
          }),
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: dimTextColor(context)),
        ),
      ),
    );
  }
}
