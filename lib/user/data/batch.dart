import 'dart:async';

import 'package:dio/dio.dart';
import 'package:e1547/query/query.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/user/user.dart';

/// Coalesces on-demand user lookups (comment avatars, forum avatars, …)
/// into single batched `/users.json` requests.
///
/// Call sites render their avatar from the vendored cache query and report
/// the ids they still miss via [request]. Reported ids are collected for a
/// short window and fetched in one call (the endpoint accepts up to 320
/// comma separated ids), then written back into the query cache so the
/// waiting widgets rebuild. Ids that never come back (deleted users) are
/// remembered for the session so they are not requested again.
class UserBatcher {
  UserBatcher({required this.dio});

  final Dio dio;

  static const Duration window = Duration(milliseconds: 250);

  final Set<int> _pending = {};
  final Set<int> _misses = {};
  Timer? _timer;
  bool _inFlight = false;

  /// Reports [id] as missing from the cache. Batched requests start at most
  /// twice a second, matching the API rate limit.
  void request(int id) {
    if (_misses.contains(id) || _pending.contains(id)) return;
    _pending.add(id);
    _timer ??= Timer(window, () => unawaited(_flush()));
  }

  Future<void> _flush() async {
    _timer = null;
    if (_inFlight || _pending.isEmpty) return;
    final cache = dio.queryCache;
    if (cache == null) return;
    final ids = _pending.toList();
    _pending.clear();
    _inFlight = true;
    try {
      final users = await UserClient(dio: dio).getMany(ids: ids);
      final bridge = cache.bridge(
        dio.identityQueryKey('users'),
        fromJson: User.fromJson,
      );
      bridge.savePage(users);
      final found = users.map((user) => user.id).toSet();
      _misses.addAll(ids.where((id) => !found.contains(id)));
    } on Object {
      // Network failure: the ids are neither pending nor missed, so the
      // next rebuild reports them again.
    } finally {
      _inFlight = false;
      if (_pending.isNotEmpty) {
        _timer = Timer(window, () => unawaited(_flush()));
      }
    }
  }
}

final Expando<UserBatcher> _batchers = Expando();

extension UserBatching on UserClient {
  /// The per-client request coalescer; lives as long as the client.
  UserBatcher get batcher => _batchers[this] ??= UserBatcher(dio: dio);
}
