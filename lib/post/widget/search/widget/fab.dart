import 'package:e1547/app/app.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/tag/tag.dart';
import 'package:flutter/material.dart';

class PostsPageFab extends StatelessWidget {
  const PostsPageFab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PostParamsController>();
    return SearchPromptFab(
      tags: controller.value.toQuery(),
      onSubmit: (value) {
        final String tags = value['tags'] ?? '';
        if (_openIfLink(context, tags)) return;
        controller.update((p) => p.copyWith(tags: tags));
      },
      filters: [
        PrimaryFilterConfig(
          filter: TagSearchFilterTag(tag: 'tags', name: 'Tags'.tr),
          filters: [PostParams.tagsFilter],
        ),
      ],
    );
  }

  /// A pasted e621/e926 URL jumps straight to that page instead of becoming
  /// a tag search. Other text is left for the caller.
  bool _openIfLink(BuildContext context, String value) {
    final String trimmed = value.trim();
    if (!trimmed.contains('://') && !trimmed.startsWith('/')) return false;
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null) return false;
    final bool site =
        uri.host.isEmpty || uri.host == 'e621.net' || uri.host == 'e926.net';
    if (!site) return false;
    return const E621LinkParser().open(context, trimmed);
  }
}
