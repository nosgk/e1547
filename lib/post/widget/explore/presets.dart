import 'dart:convert';

/// A saved explore search: a remark (name) plus the tag query it stands
/// for. Stored in the settings as a JSON array.
class ExplorePreset {
  const ExplorePreset({required this.name, required this.tags});

  factory ExplorePreset.fromJson(Map<String, dynamic> json) => ExplorePreset(
    name: '${json['name'] ?? ''}',
    tags: '${json['tags'] ?? ''}',
  );

  final String name;
  final String tags;

  Map<String, Object?> toJson() => {'name': name, 'tags': tags};
}

/// Parses the stored presets; malformed data yields an empty list.
List<ExplorePreset> parseExplorePresets(String stored) {
  try {
    final decoded = jsonDecode(stored);
    if (decoded is! List) return const [];
    return [
      for (final entry in decoded)
        if (entry is Map) ExplorePreset.fromJson(entry.cast<String, dynamic>()),
    ];
  } on FormatException {
    return const [];
  }
}

String encodeExplorePresets(List<ExplorePreset> presets) =>
    jsonEncode([for (final preset in presets) preset.toJson()]);
