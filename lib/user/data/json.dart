import 'package:deep_pick/deep_pick.dart';
import 'package:e1547/user/user.dart';

abstract final class E621User {
  /// Parses a user from either the full `/users/<id>` endpoint or the
  /// `/users` index. The index omits profile about-fields and most stat
  /// counters; those parse to null there.
  static User fromJson(dynamic json) => pick(json).letOrThrow(
    (pick) => User(
      id: json['id'],
      name: json['name'],
      avatarId: json['avatar_id'],
      hasCroppedAvatar: json['has_cropped_avatar'] == true,
      about: UserAbout(
        bio: json['profile_about'],
        comission: json['profile_artinfo'],
      ),
      stats: UserStats(
        createdAt: pick('created_at').asDateTimeOrNull(),
        levelString: pick('level_string').asStringOrNull(),
        favoriteCount: pick('favorite_count').asIntOrNull(),
        postUpdateCount: pick('post_update_count').asIntOrNull(),
        postUploadCount: pick('post_upload_count').asIntOrNull(),
        forumPostCount: pick('forum_post_count').asIntOrNull(),
        commentCount: pick('comment_count').asIntOrNull(),
      ),
    ),
  );
}
