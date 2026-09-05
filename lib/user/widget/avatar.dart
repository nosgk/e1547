import 'package:cached_network_image/cached_network_image.dart';
import 'package:e1547/client/client.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/query/query.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/traits/data/client.dart';
import 'package:e1547/user/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_sub/flutter_sub.dart';

class IdentityAvatar extends StatelessWidget {
  const IdentityAvatar(this.id, {super.key, this.radius = 20});

  final int id;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Consumer<TraitsClient>(
      builder: (context, client, child) => SubStream(
        create: () => client.getOrNull(id).stream,
        builder: (context, snapshot) =>
            Avatar(snapshot.data?.avatar, radius: radius),
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.id,
    required this.userId,
    required this.hasCroppedAvatar,
    this.radius = 20,
    this.onTap,
  });

  final int? id;
  final int userId;
  final bool hasCroppedAvatar;
  final double radius;

  /// Custom tap behavior; defaults to opening the avatar post.
  final VoidCallback? onTap;

  String? _resolve(Post? post) {
    if (post == null) return null;
    if (hasCroppedAvatar && !post.isDeleted) {
      String? reference = post.sample ?? post.preview ?? post.file;
      if (reference != null) {
        String? url = croppedAvatarUrl(
          reference: reference,
          userId: userId,
          avatarId: post.id,
        );
        if (url != null) return url;
      }
    }
    return post.sample;
  }

  @override
  Widget build(BuildContext context) {
    final id = this.id;
    if (id == null) {
      return EmptyAvatar(radius: radius);
    }
    final client = context.watch<Client>();
    return QueryBuilder(
      query: client.posts.useGet(id: id),
      builder: (context, state) {
        final post = state.data;
        return Avatar(
          _resolve(post),
          radius: radius,
          onTap: onTap ?? _openPost(context, post),
        );
      },
    );
  }

  VoidCallback? _openPost(BuildContext context, Post? post) {
    if (post == null) return null;
    return () => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => PostDetail(post: post)));
  }
}

/// Avatar of the user with [userId], fetched on demand (cached by the query
/// layer). Falls back to the empty avatar while loading or when the user
/// has no avatar. Used wherever only a user id is known (comments, forum).
class UserIdAvatar extends StatelessWidget {
  const UserIdAvatar({
    super.key,
    required this.userId,
    this.radius = 20,
    this.onTap,
  });

  final int userId;
  final double radius;

  /// Custom tap behavior; defaults to opening the user's page.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final client = context.watch<Client>();
    return QueryBuilder(
      query: client.users.useGet(id: userId, vendored: true),
      builder: (context, state) {
        final user = state.data;
        return UserAvatar(
          id: user?.avatarId,
          userId: userId,
          hasCroppedAvatar: user?.hasCroppedAvatar ?? false,
          radius: radius,
          onTap:
              onTap ??
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => UserLoadingPage(userId),
                ),
              ),
        );
      },
    );
  }
}

class PostAvatar extends StatelessWidget {
  const PostAvatar({
    super.key,
    required this.id,
    required this.userId,
    required this.hasCroppedAvatar,
  });

  final int? id;
  final int userId;
  final bool hasCroppedAvatar;

  @override
  Widget build(BuildContext context) {
    if (id == null) {
      return const EmptyAvatar();
    }
    return UserAvatar(
      id: id,
      userId: userId,
      hasCroppedAvatar: hasCroppedAvatar,
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.url, {super.key, this.onTap, this.radius = 20});

  final String? url;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (url case final url?) {
      return MouseCursorRegion(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(shape: BoxShape.circle),
          clipBehavior: Clip.antiAlias,
          width: radius * 2,
          height: radius * 2,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            cacheManager: context.read<BaseCacheManager>(),
            placeholder: (context, url) => EmptyAvatar(radius: radius),
            errorWidget: (context, url, error) =>
                const Center(child: Icon(Icons.warning_amber)),
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
          ),
        ),
      );
    } else {
      return EmptyAvatar(radius: radius);
    }
  }
}

class EmptyAvatar extends StatelessWidget {
  const EmptyAvatar({super.key, this.radius = 20});

  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(shape: BoxShape.circle),
    clipBehavior: Clip.antiAlias,
    width: radius * 2,
    height: radius * 2,
    child: Image.asset('assets/icon/app/user.png'),
  );
}
