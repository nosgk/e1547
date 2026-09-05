import 'package:e1547/app/app.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';

class PostImageOverlay extends StatelessWidget {
  const PostImageOverlay({
    super.key,
    required this.post,
    required this.builder,
  });

  final Post post;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    if (post.file == null) {
      if (post.isDeleted) {
        return IconMessage(
          title: Text('Post was deleted'.tr),
          icon: const Icon(Icons.delete_outlined),
        );
      }

      return IconMessage(
        title: Text('Post is unavailable'.tr),
        icon: const Icon(Icons.no_adult_content),
      );
    }

    PostFilter? filter = context.watch<PostFilter?>();
    if ((filter?.denies(post) ?? false) && !post.isFavorited) {
      return IconMessage(
        title: Text('Post is blacklisted'.tr),
        icon: const Icon(Icons.block),
      );
    }

    if (post.type == PostType.unsupported) {
      return IconMessage(
        title: Text('{ext} files are not supported'.trArgs({'ext': post.ext})),
        icon: const Icon(Icons.image_not_supported_outlined),
        action: Padding(
          padding: const EdgeInsets.all(4),
          child: TextButton(
            onPressed: () async => launch(post.file!),
            child: Text('Open'.tr),
          ),
        ),
      );
    }

    return builder(context);
  }
}
