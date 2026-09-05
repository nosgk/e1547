import 'dart:async';
import 'dart:convert';

import 'package:e1547/translate/data/translate.dart';
import 'package:flutter/foundation.dart';
import 'package:notified_preferences/notified_preferences.dart';

/// Persistent LRU cache of translation results.
///
/// Entries live in a single SharedPreferences key as a JSON object
/// ({"key": "translation", …} in least-recently-used order) so translations
/// survive app restarts and are shared by every translation surface. The
/// map is loaded once on first use; every change schedules a debounced
/// write-back. When [limit] is exceeded the oldest entries are evicted;
/// 0 means unlimited.
class TranslationCache extends ChangeNotifier {
  TranslationCache._();

  static final TranslationCache instance = TranslationCache._();

  static const String _prefKey = 'translateCache';
  static const Duration _saveDelay = Duration(milliseconds: 500);

  final Map<String, String> _entries = {};
  Future<void>? _loading;
  Timer? _saveTimer;
  int _limit = kDefaultTranslateCacheLimit;

  /// Waits for the stored entries to be loaded. Memoized, so repeated
  /// calls share one load.
  Future<void> get ready => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _entries.addEntries([
            for (final entry in decoded.entries)
              MapEntry('${entry.key}', '${entry.value}'),
          ]);
        }
      }
    } on Object {
      // A broken cache must never break translations; start over empty.
      _entries.clear();
    }
    // No eviction here: the user's configured limit is not known yet and
    // the default could wrongly drop stored entries. Every put() and every
    // limit change evicts as needed.
    notifyListeners();
  }

  /// Maximum number of cached entries; 0 = unlimited.
  int get limit => _limit;

  set limit(int value) {
    final next = value < 0 ? 0 : value;
    if (next == _limit) return;
    _limit = next;
    _evict();
    _scheduleSave();
    notifyListeners();
  }

  /// Number of cached translations.
  int get count => _entries.length;

  /// Approximate stored size: UTF-8 bytes of every key and translation.
  int get sizeBytes => _entries.entries.fold(
    0,
    (sum, entry) =>
        sum + utf8.encode(entry.key).length + utf8.encode(entry.value).length,
  );

  /// Returns the cached translation for [key], or null. A hit refreshes the
  /// entry's recency.
  String? get(String key) {
    final value = _entries[key];
    if (value == null) return null;
    // Re-inserting moves the entry to the end (most recently used).
    _entries.remove(key);
    _entries[key] = value;
    _scheduleSave();
    return value;
  }

  void put(String key, String value) {
    _entries.remove(key);
    _entries[key] = value;
    _evict();
    _scheduleSave();
    notifyListeners();
  }

  /// Removes every cached translation and persists immediately.
  Future<void> clear() async {
    if (_entries.isEmpty) return;
    _entries.clear();
    _saveTimer?.cancel();
    _saveTimer = null;
    notifyListeners();
    await _save();
  }

  void _evict() {
    if (_limit <= 0) return;
    while (_entries.length > _limit) {
      _entries.remove(_entries.keys.first);
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _save);
  }

  Future<void> _save() async {
    _saveTimer = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_entries.isEmpty) {
        await prefs.remove(_prefKey);
      } else {
        // Dart maps preserve insertion order, so the stored JSON keeps the
        // LRU order intact.
        await prefs.setString(_prefKey, jsonEncode(_entries));
      }
    } on Object {
      // Persisting the cache is best-effort.
    }
  }
}
