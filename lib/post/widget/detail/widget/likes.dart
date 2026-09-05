import 'package:e1547/client/client.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/query/query.dart';
import 'package:e1547/settings/settings.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/translate/translate.dart';
import 'package:flutter/material.dart';
import 'package:like_button/like_button.dart';

class LikeDisplay extends StatelessWidget {
  const LikeDisplay({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final client = context.watch<Client>();
    final messenger = ScaffoldMessenger.of(context);
    // Without a Settings provider (tests, standalone hosts) the favorite
    // action degrades to the plain display-only heart.
    final settings = trySettingsOf(context);

    return Column(
      children: [
        Row(
          children: [
            MutationBuilder(
              mutation: client.posts.useVote(id: post.id),
              builder: (context, state, mutate) {
                final bool enabled = client.hasLogin && !state.isLoading;
                return VoteDisplay(
                  vote: post.vote,
                  score: post.score,
                  onUpvote: enabled
                      ? (isLiked) async {
                          mutate((upvote: true, replace: !isLiked)).catchError((
                            error,
                          ) {
                            messenger.showSnackBar(
                              SnackBar(
                                duration: const Duration(seconds: 1),
                                content: Text(
                                  'Failed to upvote Post #${post.id}',
                                ),
                              ),
                            );
                            return error;
                          });
                          return !isLiked;
                        }
                      : null,
                  onDownvote: enabled
                      ? (isLiked) async {
                          mutate((upvote: false, replace: !isLiked)).catchError(
                            (error) {
                              messenger.showSnackBar(
                                SnackBar(
                                  duration: const Duration(seconds: 1),
                                  content: Text(
                                    'Failed to downvote Post #{id}'.trArgs({
                                      'id': post.id.toString(),
                                    }),
                                  ),
                                ),
                              );
                              return error;
                            },
                          );
                          return !isLiked;
                        }
                      : null,
                );
              },
            ),
            Expanded(
              // Scale down instead of overflowing on very narrow screens.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PostAction(
                      icon: Icons.copy_rounded,
                      tooltip: 'Copy tags'.tr,
                      onTap: () => copyPostTags(context, post),
                    ),
                    _PostAction(
                      icon: Icons.save_alt_rounded,
                      tooltip: 'Export tags to file'.tr,
                      onTap: () => exportPostTags(context, post),
                    ),
                    _PostAction(
                      icon: Icons.file_download_rounded,
                      tooltip: 'Download'.tr,
                      enabled: post.file != null,
                      onTap: () => postDownloadingNotification(context, {post}),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(post.favCount.toString()),
                    ),
                    if (settings != null)
                      FavoriteButton(post: post, enabled: client.hasLogin)
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.favorite,
                          color: post.isFavorited
                              ? Colors.pinkAccent
                              : IconTheme.of(context).color,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const Divider(),
      ],
    );
  }
}

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.post, this.enabled = true});

  final Post post;

  /// When false (not logged in), tapping explains why instead of firing a
  /// request that would only fail.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final client = context.watch<Client>();
    final settings = context.read<Settings>();
    final messenger = ScaffoldMessenger.of(context);

    final addMutation = client.posts.useAddFavorite();
    final removeMutation = client.posts.useRemoveFavorite();
    return MutationBuilder(
      mutation: post.isFavorited ? removeMutation : addMutation,
      builder: (context, state, mutate) {
        final active = enabled && !state.isLoading;
        return InkResponse(
          onTap: active ? () {} : null,
          child: LikeButton(
            isLiked: post.isFavorited,
            circleColor: const CircleColor(start: Colors.pink, end: Colors.red),
            bubblesColor: const BubblesColor(
              dotPrimaryColor: Colors.pink,
              dotSecondaryColor: Colors.red,
            ),
            likeBuilder: (isLiked) => Icon(
              Icons.favorite,
              color: isLiked ? Colors.pinkAccent : IconTheme.of(context).color,
            ),
            onTap: !active
                ? (isLiked) async {
                    messenger.showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 2),
                        content: Text('Log in to manage favorites'.tr),
                      ),
                    );
                    return isLiked;
                  }
                : (isLiked) async {
                    try {
                      await mutate(post.id);
                      if (!isLiked && settings.upvoteFavs.value) {
                        try {
                          await client.posts.useVote(id: post.id).mutate((
                            upvote: true,
                            replace: true,
                          ));
                        } on Exception {
                          // upvote is best-effort once the favorite succeeded
                        }
                      }
                    } on Exception {
                      messenger.showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 1),
                          content: Text(
                            isLiked
                                ? 'Failed to remove Post #{id} from favorites'
                                      .trArgs({'id': post.id.toString()})
                                : 'Failed to add Post #{id} to favorites'
                                      .trArgs({'id': post.id.toString()}),
                          ),
                        ),
                      );
                    }
                    return !isLiked;
                  },
          ),
        );
      },
    );
  }
}

/// One compact icon action of the post info row with a contained circular
/// ripple and a tooltip; [enabled] only dims the icon.
class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 40,
        height: 40,
        child: InkResponse(
          containedInkWell: true,
          customBorder: const CircleBorder(),
          radius: 20,
          onTap: enabled ? onTap : null,
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? IconTheme.of(context).color
                : dimTextColor(context),
          ),
        ),
      ),
    );
  }
}
