import 'package:e1547/post/post.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/translate/translate.dart';
import 'package:flutter/material.dart';

class PostDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PostDetailAppBar({super.key, required this.post});

  final Post post;

  @override
  Size get preferredSize => const Size.fromHeight(defaultAppBarHeight);

  @override
  Widget build(BuildContext context) {
    return TransparentAppBar(
      child: DefaultAppBar(
        actions: [
          // Scoped tag translation toggle, with a small "Translated by …"
          // caption naming the configured service while active.
          const TagTranslationToggle(),
          PopupMenuButton<VoidCallback>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => value(),
            itemBuilder: (context) => [
              ...postMenuPostActions(context, post),
              ...postMenuUserActions(context, post),
            ],
          ),
        ],
      ),
    );
  }
}
