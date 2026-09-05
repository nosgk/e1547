import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:e1547/app/data/storage.dart';
import 'package:notified_preferences/notified_preferences.dart';

/// Name of the table that carries the app preferences inside an exported
/// database backup. It only exists in exported copies; the live database
/// keeps preferences in SharedPreferences.
const String kPreferencesBackupTable = 'app_settings';

/// Marker row written into [kPreferencesBackupTable] when the user chose to
/// exclude translation service settings from an export. On import it makes
/// the importer remove all stored translation settings, which falls back to
/// their defaults.
const String kTranslationDefaultsMarker = '__translationDefaults__';

const String _createTableStatement =
    'CREATE TABLE IF NOT EXISTS $kPreferencesBackupTable '
    '(key TEXT PRIMARY KEY, value TEXT NOT NULL)';

/// Writes every stored app preference into [db] (a temporary copy of the
/// app database opened for export), replacing any previous backup rows.
///
/// When [includeTranslationSettings] is false, all `translate*` keys are
/// omitted and [kTranslationDefaultsMarker] is written instead, so an
/// import resets the translation service to its defaults.
Future<void> writePreferencesBackup(
  AppDatabase db, {
  required bool includeTranslationSettings,
}) async {
  await db.customStatement(_createTableStatement);
  await db.customStatement('DELETE FROM $kPreferencesBackupTable');
  final prefs = await SharedPreferences.getInstance();
  for (final key in prefs.getKeys()) {
    if (!includeTranslationSettings && _isTranslationSetting(key)) continue;
    await db.customInsert(
      'INSERT OR REPLACE INTO $kPreferencesBackupTable (key, value) '
      'VALUES (?, ?)',
      variables: [
        Variable.withString(key),
        Variable.withString(_encodePreference(prefs.get(key))),
      ],
    );
  }
  if (!includeTranslationSettings) {
    await db.customInsert(
      'INSERT OR REPLACE INTO $kPreferencesBackupTable (key, value) '
      'VALUES (?, ?)',
      variables: [
        Variable.withString(kTranslationDefaultsMarker),
        Variable.withString('true'),
      ],
    );
  }
}

/// Reads the preferences backup from [db]. Returns null when the database
/// carries no backup table (pre-feature exports).
Future<Map<String, String>?> readPreferencesBackup(AppDatabase db) async {
  final tables = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name = '$kPreferencesBackupTable'",
      )
      .get();
  if (tables.isEmpty) return null;
  final rows = await db
      .customSelect('SELECT key, value FROM $kPreferencesBackupTable')
      .get();
  return {
    for (final row in rows) row.read<String>('key'): row.read<String>('value'),
  };
}

/// Applies a preferences backup (read by [readPreferencesBackup]) to the
/// stored preferences. The caller must restart the app afterwards for the
/// changes to take effect.
Future<void> applyPreferencesBackup(Map<String, String> backup) async {
  final prefs = await SharedPreferences.getInstance();
  for (final entry in backup.entries) {
    if (entry.key == kTranslationDefaultsMarker) continue;
    await _applyPreference(prefs, entry.key, entry.value);
  }
  if (backup.containsKey(kTranslationDefaultsMarker)) {
    // The backup was exported without translation settings: clear the
    // stored ones so they fall back to their defaults.
    final translationKeys = prefs
        .getKeys()
        .where(_isTranslationSetting)
        .toList();
    for (final key in translationKeys) {
      await prefs.remove(key);
    }
  }
}

bool _isTranslationSetting(String key) => key.startsWith('translate');

/// Serializes one preference value into a typed JSON wrapper so import can
/// call the matching SharedPreferences setter.
String _encodePreference(Object? value) {
  return jsonEncode({
    'type': value is List ? 'StringList' : value.runtimeType.toString(),
    'value': value,
  });
}

Future<void> _applyPreference(
  SharedPreferences prefs,
  String key,
  String encoded,
) async {
  try {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) return;
    final type = decoded['type'];
    final value = decoded['value'];
    // Type guards instead of casts: rows with mismatched types (e.g. from a
    // different app version) are skipped, the rest still applies.
    switch (type) {
      case 'String':
        if (value is String) await prefs.setString(key, value);
      case 'bool':
        if (value is bool) await prefs.setBool(key, value);
      case 'int':
        if (value is int) await prefs.setInt(key, value);
      case 'double':
        if (value is num) await prefs.setDouble(key, value.toDouble());
      case 'StringList':
        if (value is List && value.every((element) => element is String)) {
          await prefs.setStringList(key, value.cast<String>());
        }
    }
  } on FormatException {
    // Malformed rows are skipped; the rest of the backup still applies.
  }
}
