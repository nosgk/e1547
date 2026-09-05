import 'package:e1547/client/client.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/query/query.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'filter.freezed.dart';

class PostFilter extends FilterController<Post>
    implements ValueNotifier<PostFilterValue> {
  PostFilter(this.client, [PostFilterValue? value])
    : _value = value ?? const PostFilterValue() {
    _allowedPostsSet = {..._value.allowedPosts};
    client.traits.addListener(_updateDenyList);
  }

  final Client client;

  PostFilterValue _value;

  Set<int> _allowedPostsSet = const {};

  final Map<int, _PostFilterCache> _filterCache = {};

  void _updateDenyList() {
    _filterCache.clear();
    notifyListeners();
  }

  @override
  Object idOf(Post post) => post.id;

  @override
  bool filter(Post post) => !denies(post);

  @override
  PostFilterValue get value => _value;

  @override
  set value(PostFilterValue value) {
    if (_value == value) return;
    _value = value;
    notifyListeners();
  }

  bool get denying => value.denying;
  set denying(bool enabled) => value = value.copyWith(denying: enabled);

  List<String> get allowedEntries => value.allowedEntries;
  set allowedEntries(List<String> entries) {
    final newValue = value.copyWith(allowedEntries: entries);
    if (value == newValue) return;
    _filterCache.clear();
    value = newValue;
  }

  List<int> get allowedPosts => value.allowedPosts;
  set allowedPosts(List<int> posts) =>
      value = value.copyWith(allowedPosts: posts);

  void allow(int postId) {
    if (!allowedPosts.contains(postId)) {
      allowedPosts = [...allowedPosts, postId];
    }
  }

  void disallow(int postId) {
    allowedPosts = allowedPosts.where((id) => id != postId).toList();
  }

  void enable(String entry) {
    if (!allowedEntries.contains(entry)) {
      allowedEntries = [...allowedEntries, entry];
    }
  }

  void disable(String entry) {
    if (allowedEntries.contains(entry)) {
      allowedEntries = allowedEntries.where((e) => e != entry).toList();
    }
  }

  void toggle(String entry) {
    if (allowedEntries.contains(entry)) {
      disable(entry);
    } else {
      enable(entry);
    }
  }

  Map<String, int> get blockedCountsByEntry {
    if (!denying) return const {};
    final allowedPostIds = {...allowedPosts};
    final allowedEntryNames = {...allowedEntries};
    final counts = <String, int>{};
    for (final post in tracked) {
      if (allowedPostIds.contains(post.id)) continue;
      for (final entry in entriesFor(post)) {
        if (allowedEntryNames.contains(entry)) continue;
        counts[entry] = (counts[entry] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<String> entriesFor(Post post) {
    final cached = _filterCache[post.id];

    if (cached == null || cached.hash != post.hashCode) {
      // Bounded memory: drop the cache wholesale when it grows too large.
      // Denylist changes clear it via the traits listener, post changes are
      // detected through the hash, so a full clear is always safe.
      if (_filterCache.length > 4096) _filterCache.clear();
      final deniers = post.getDeniers(client.traits.value.denylist).toList();
      _filterCache[post.id] = (hash: post.hashCode, entries: deniers);
      return deniers;
    }

    return cached.entries;
  }

  bool denies(Post post) {
    if (!denying) return false;
    // An empty denylist can never deny anything; skip the cache machinery.
    if (client.traits.value.denylist.isEmpty) return false;
    if (_allowedPostsSet.contains(post.id)) return false;
    final entries = entriesFor(post);
    if (entries.isEmpty) return false;
    for (final entry in entries) {
      if (!allowedEntries.contains(entry)) return true;
    }
    return false;
  }

  @override
  void dispose() {
    client.traits.removeListener(_updateDenyList);
    super.dispose();
  }
}

class FavoritePostFilter extends PostFilter {
  FavoritePostFilter(super.client, [super.value]);

  @override
  bool filter(Post post) {
    if (post.isFavorited) return true;
    return super.filter(post);
  }
}

typedef _PostFilterCache = ({int hash, List<String> entries});

@freezed
abstract class PostFilterValue with _$PostFilterValue {
  const factory PostFilterValue({
    @Default(true) bool denying,
    @Default([]) List<String> allowedEntries,
    @Default([]) List<int> allowedPosts,
  }) = _PostFilterValue;
}
