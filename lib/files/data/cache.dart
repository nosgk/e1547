import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:e1547/files/files.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

const String fileCacheKey = DefaultCacheManager.key;

CacheManager createFileCache({
  required Dio dio,
  required GeneratedDatabase database,
  Duration stalePeriod = const Duration(days: 7),
  int maxNrOfCacheObjects = 2000,
}) => CacheManager(
  Config(
    fileCacheKey,
    stalePeriod: stalePeriod,
    maxNrOfCacheObjects: maxNrOfCacheObjects,
    repo: DriftFileCacheStorage(
      repository: FileCacheRepository(database: database),
      cache: fileCacheKey,
    ),
    fileService: DioFileService(dio),
  ),
);

Future<void> discardLegacyFileCache() async {
  final File index = File(
    join((await getApplicationSupportDirectory()).path, '$fileCacheKey.json'),
  );
  if (!index.existsSync()) return;
  await index.delete();
  final Directory files = Directory(
    join((await getTemporaryDirectory()).path, fileCacheKey),
  );
  if (files.existsSync()) {
    await files.delete(recursive: true);
  }
}

/// Usage snapshot of the media file cache.
typedef MediaCacheStats = ({int count, int bytes});

/// Size-based management of the media file cache.
///
/// Usage is computed from the per-entry byte lengths recorded in the cache
/// database. [enforce] evicts the least recently touched entries until the
/// total is within the configured budget; it runs on startup, whenever the
/// budget changes, on a fixed schedule while the app runs, and on demand
/// from the settings.
class MediaCacheManager extends ChangeNotifier {
  MediaCacheManager({
    required BaseCacheManager manager,
    required FileCacheRepository repository,
    required ValueListenable<int> limitMb,
  }) : _manager = manager,
       _repository = repository,
       _limitMb = limitMb;

  final BaseCacheManager _manager;
  final FileCacheRepository _repository;
  final ValueListenable<int> _limitMb;

  Timer? _enforcementTimer;
  Timer? _startupTimer;
  bool _enforcing = false;
  bool _disposed = false;

  /// Last computed usage, or null until the first [refresh] finished.
  MediaCacheStats? stats;

  static const Duration enforcementInterval = Duration(minutes: 3);

  int get _limitBytes => _limitMb.value * 1024 * 1024;

  /// Starts the periodic enforcement schedule, reacts to budget changes and
  /// performs an initial (slightly delayed) pass so it never competes with
  /// app startup.
  void start() {
    _enforcementTimer ??= Timer.periodic(enforcementInterval, (_) {
      unawaited(_runEnforcement());
    });
    _limitMb.addListener(_runEnforcement);
    _startupTimer ??= Timer(
      const Duration(seconds: 10),
      () => unawaited(_runEnforcement()),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _enforcementTimer?.cancel();
    _enforcementTimer = null;
    _startupTimer?.cancel();
    _startupTimer = null;
    _limitMb.removeListener(_runEnforcement);
    super.dispose();
  }

  /// Recomputes the cache usage snapshot. Never throws: a database that was
  /// closed underneath (identity switch) keeps the previous snapshot.
  Future<MediaCacheStats> refresh() async {
    try {
      final objects = await _repository.all(fileCacheKey);
      var bytes = 0;
      for (final object in objects) {
        bytes += object.length ?? 0;
      }
      stats = (count: objects.length, bytes: bytes);
    } on Object {
      // Keep the previous snapshot; the next pass retries.
    }
    if (!_disposed) notifyListeners();
    return stats ?? (count: 0, bytes: 0);
  }

  /// Evicts the oldest entries until the cache fits within [limitBytes].
  /// [limitBytes] of zero or less means unlimited. Returns the number of
  /// removed entries.
  Future<int> enforce(int limitBytes) async {
    if (limitBytes <= 0) return 0;
    final objects = await _repository.all(fileCacheKey);
    var total = 0;
    for (final object in objects) {
      total += object.length ?? 0;
    }
    if (total <= limitBytes) return 0;

    final oldestFirst = [...objects]
      ..sort((a, b) => a.touched.compareTo(b.touched));
    var removed = 0;
    for (final object in oldestFirst) {
      if (total <= limitBytes) break;
      try {
        // Removes the file and its database entry in one step; a missing
        // entry is not an error.
        await _manager.removeFile(object.key);
      } on Object {
        // A failing entry must not stop the sweep; the next pass will
        // try again.
        continue;
      }
      total -= object.length ?? 0;
      removed++;
    }
    return removed;
  }

  /// Evicts everything and refreshes the usage snapshot.
  Future<void> clearAll() async {
    try {
      await _manager.emptyCache();
    } on Object {
      // Best-effort; refresh below reports what actually remains.
    }
    await refresh();
  }

  Future<void> _runEnforcement() async {
    if (_enforcing || _disposed) return;
    _enforcing = true;
    try {
      final removed = await enforce(_limitBytes);
      if (removed > 0 && !_disposed) await refresh();
    } on Object {
      // Maintenance is best-effort; the next scheduled pass retries.
    } finally {
      _enforcing = false;
    }
  }
}
