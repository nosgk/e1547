import 'dart:convert';

/// A saved post search: a remark (name) plus the tag query it stands
/// for. Stored in the settings as a JSON array.
class SearchPreset {
  const SearchPreset({required this.name, required this.tags});

  factory SearchPreset.fromJson(Map<String, dynamic> json) => SearchPreset(
    name: '${json['name'] ?? ''}',
    tags: '${json['tags'] ?? ''}',
  );

  final String name;
  final String tags;

  Map<String, Object?> toJson() => {'name': name, 'tags': tags};
}

/// Parses the stored presets; malformed data yields an empty list.
List<SearchPreset> parseSearchPresets(String stored) {
  try {
    final decoded = jsonDecode(stored);
    if (decoded is! List) return const [];
    return [
      for (final entry in decoded)
        if (entry is Map) SearchPreset.fromJson(entry.cast<String, dynamic>()),
    ];
  } on FormatException {
    return const [];
  }
}

String encodeSearchPresets(List<SearchPreset> presets) =>
    jsonEncode([for (final preset in presets) preset.toJson()]);
