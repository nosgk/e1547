import 'dart:convert';

import 'package:e1547/shared/shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A saved post search: a remark (name) plus the tag query it stands
/// for. Stored in the settings as a JSON array.
@immutable
class SearchPreset {
  const SearchPreset({required this.name, required this.tags});

  factory SearchPreset.fromJson(Map<String, dynamic> json) => SearchPreset(
    name: '${json['name'] ?? ''}',
    tags: '${json['tags'] ?? ''}',
  );

  final String name;
  final String tags;

  Map<String, Object?> toJson() => {'name': name, 'tags': tags};

  @override
  bool operator ==(Object other) =>
      other is SearchPreset && other.name == name && other.tags == tags;

  @override
  int get hashCode => Object.hash(name, tags);
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

/// Name (remark) + tags editor of a preset; returns the entry or null.
Future<(String, String)?> showSearchPresetDialog(
  BuildContext context, {
  required String title,
  required String name,
  required String tags,
  String? tagsLabel,
}) async {
  final nameController = TextEditingController(text: name);
  final tagsController = TextEditingController(text: tags);
  final result = await showDialog<(String, String)>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            autofocus: name.isEmpty,
            decoration: InputDecoration(
              labelText: 'Preset name'.tr,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: tagsController,
            minLines: 1,
            maxLines: 4,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              labelText: tagsLabel ?? 'Search parameters'.tr,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('CANCEL'.tr),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop((nameController.text.trim(), tagsController.text.trim())),
          child: Text('Save'.tr),
        ),
      ],
    ),
  );
  return result;
}

/// Collapsible saved-search group for a settings drawer.
///
/// The entries update live with the given settings listenable, wrap
/// instead of truncating, and expose edit/delete through a long-press
/// menu (the delete is confirmed here). The save callback persists an
/// added or edited entry; the delete callback removes one.
class SearchPresetGroup extends StatelessWidget {
  const SearchPresetGroup({
    super.key,
    required this.title,
    required this.presets,
    required this.onSave,
    required this.onDelete,
    required this.onApply,
    this.onAdd,
    this.addTags = '',
    this.addSubtitle,
  });

  final String title;
  final ValueListenable<String> presets;

  /// Persists the updated entry; when adding, the original is the empty
  /// preset.
  final Future<void> Function(SearchPreset original, SearchPreset updated)
  onSave;

  /// Removes the given entry.
  final Future<void> Function(SearchPreset preset) onDelete;

  /// Applies the entry to the current search.
  final void Function(SearchPreset preset) onApply;

  /// Custom add flow; when null, the shared preset dialog opens with
  /// [addTags] as the initial tags.
  final Future<void> Function()? onAdd;
  final String addTags;
  final String? addSubtitle;

  static const SearchPreset _empty = SearchPreset(name: '', tags: '');

  Future<void> _add(BuildContext context) async {
    if (onAdd != null) return onAdd!();
    final result = await showSearchPresetDialog(
      context,
      title: 'Save current as preset'.tr,
      name: '',
      tags: addTags,
    );
    if (result == null || !context.mounted) return;
    final (name, tags) = result;
    await onSave(_empty, SearchPreset(name: name, tags: tags));
  }

  Future<void> _edit(BuildContext context, SearchPreset preset) async {
    final result = await showSearchPresetDialog(
      context,
      title: 'Edit preset'.tr,
      name: preset.name,
      tags: preset.tags,
    );
    if (result == null || !context.mounted) return;
    final (name, tags) = result;
    await onSave(preset, SearchPreset(name: name, tags: tags));
  }

  Future<void> _delete(BuildContext context, SearchPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete preset'.tr),
        content: Text('Delete this preset?'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('CANCEL'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await onDelete(preset);
  }

  Future<void> _menu(BuildContext context, SearchPreset preset) =>
      showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text('Edit'.tr),
                onTap: () {
                  Navigator.of(context).pop();
                  _edit(context, preset);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text('Delete'.tr),
                onTap: () {
                  Navigator.of(context).pop();
                  _delete(context, preset);
                },
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(bottom: 4),
      title: Text(title),
      subtitle: addSubtitle == null ? null : Text(addSubtitle!),
      children: [
        ListTile(
          leading: const Icon(Icons.bookmark_add_outlined),
          title: Text('Save current as preset'.tr),
          onTap: () => _add(context),
        ),
        ValueListenableBuilder<String>(
          valueListenable: presets,
          builder: (context, stored, child) {
            final entries = parseSearchPresets(stored);
            if (entries.isEmpty) {
              return ListTile(
                enabled: false,
                leading: const Icon(Icons.bookmark_border),
                title: Text('No presets yet'.tr),
              );
            }
            return Column(
              children: [
                for (final preset in entries)
                  ListTile(
                    leading: const Icon(Icons.bookmark_outline),
                    title: Text(
                      preset.name.isEmpty ? 'Preset'.tr : preset.name,
                    ),
                    subtitle: Text(
                      preset.tags,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    onTap: () => onApply(preset),
                    onLongPress: () => _menu(context, preset),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
