import 'package:e1547/post/post.dart';
import 'package:e1547/settings/settings.dart';
import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _DateComparison { on, before, after }

/// Quick sort and preset tools for a post search page's settings drawer.
/// Everything operates on the page's [PostParamsController]: the editable
/// tag string stays the single source of truth, and quick sort only
/// replaces tokens with a matching prefix ("order:", "date:").
class SearchTools {
  SearchTools(this.controller);

  final PostParamsController controller;

  String get tags => controller.value.tags ?? '';

  /// The first token starting with [prefix], or null.
  String? termOf(String prefix) {
    for (final token in tags.split(' ')) {
      if (token.startsWith(prefix)) return token;
    }
    return null;
  }

  /// Returns [tags] with every token starting with [prefix] replaced by
  /// [term] (removed when null).
  String withTerm(String prefix, String? term) {
    final tokens = tags
        .split(' ')
        .where((token) => token.isNotEmpty && !token.startsWith(prefix))
        .toList();
    if (term != null) tokens.add(term);
    return tokens.join(' ');
  }

  /// Replaces the page's tag query and notifies the feed.
  void applyTags(String tags) =>
      controller.update((p) => p.copyWith(tags: tags));

  String? orderLabel(String? term) => switch (term) {
    null => null,
    'order:favcount' => 'Most favorites'.tr,
    'order:favcount_asc' => 'Fewest favorites'.tr,
    'order:score' => 'Highest score'.tr,
    'order:score_asc' => 'Lowest score'.tr,
    'order:id_desc' => 'Newest posts'.tr,
    'order:id_asc' => 'Oldest posts'.tr,
    'order:random' => 'Random order'.tr,
    _ => term,
  };

  /// Date filter dialog: a comparison (on / before / after) plus a date,
  /// rendered as `date:…`, `date:<…` or `date:>…`.
  Future<void> pickDate(BuildContext context) async {
    final current = termOf('date:');
    var comparison = current == null
        ? _DateComparison.on
        : current.contains('<')
        ? _DateComparison.before
        : current.contains('>')
        ? _DateComparison.after
        : _DateComparison.on;
    DateTime date = DateTime.now();
    final match = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(current ?? '');
    if (match != null) {
      date = DateTime.tryParse(match.group(0)!) ?? date;
    }

    // The dialog resolves to the final date term: null = dismissed,
    // empty = clear the filter, otherwise the new `date:…` token.
    String? term;
    await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void closeWith(String? value) {
            term = value;
            Navigator.of(context).pop();
          }

          return AlertDialog(
            title: Text('Post date'.tr),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<_DateComparison>(
                  segments: [
                    ButtonSegment(
                      value: _DateComparison.on,
                      label: Text('On day'.tr),
                    ),
                    ButtonSegment(
                      value: _DateComparison.before,
                      label: Text('Before'.tr),
                    ),
                    ButtonSegment(
                      value: _DateComparison.after,
                      label: Text('After'.tr),
                    ),
                  ],
                  selected: {comparison},
                  onSelectionChanged: (selection) =>
                      setDialogState(() => comparison = selection.first),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text(DateFormat('yyyy-MM-dd').format(date)),
                  contentPadding: EdgeInsets.zero,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2005),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                ),
              ],
            ),
            actions: [
              if (current != null)
                TextButton(
                  onPressed: () => closeWith(''),
                  child: Text('Clear date filter'.tr),
                ),
              TextButton(
                onPressed: () => closeWith(null),
                child: Text('CANCEL'.tr),
              ),
              FilledButton(
                onPressed: () {
                  final formatted = DateFormat('yyyy-MM-dd').format(date);
                  closeWith(switch (comparison) {
                    _DateComparison.on => 'date:$formatted',
                    _DateComparison.before => 'date:<$formatted',
                    _DateComparison.after => 'date:>$formatted',
                  });
                },
                child: Text('Save'.tr),
              ),
            ],
          );
        },
      ),
    );
    if (term == null || !context.mounted) return;
    applyTags(withTerm('date:', term!.isEmpty ? null : term));
  }

  Future<void> pickOrder(BuildContext context) async {
    final options = {
      'order:favcount': 'Most favorites'.tr,
      'order:favcount_asc': 'Fewest favorites'.tr,
      'order:score': 'Highest score'.tr,
      'order:score_asc': 'Lowest score'.tr,
      'order:id_desc': 'Newest posts'.tr,
      'order:id_asc': 'Oldest posts'.tr,
      'order:random': 'Random order'.tr,
    };
    final current = termOf('order:');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Order'.tr),
        children: [
          for (final entry in options.entries)
            ListTile(
              title: Text(entry.value),
              subtitle: Text(
                entry.key,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              trailing: current == entry.key ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(entry.key),
            ),
          if (current != null)
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: Text('Clear order'.tr),
              onTap: () => Navigator.of(context).pop(''),
            ),
        ],
      ),
    );
    if (result == null || !context.mounted) return;
    applyTags(withTerm('order:', result.isEmpty ? null : result));
  }

  // --- presets ----------------------------------------------------------------

  List<SearchPreset> presets(Settings settings) =>
      parseSearchPresets(settings.explorePresets.value);

  Future<void> addPreset(BuildContext context) async {
    final settings = context.read<Settings>();
    final result = await _presetDialog(context, name: '', tags: tags);
    if (result == null || !context.mounted) return;
    final (name, presetTags) = result;
    if (presetTags.trim().isEmpty) return;
    final entries = [...presets(settings)];
    entries.add(SearchPreset(name: name.trim(), tags: presetTags.trim()));
    settings.explorePresets.value = encodeSearchPresets(entries);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('Preset saved'.tr),
      ),
    );
  }

  Future<void> editPreset(BuildContext context, int index) async {
    final settings = context.read<Settings>();
    final entries = presets(settings);
    if (index < 0 || index >= entries.length) return;
    final preset = entries[index];
    final result = await _presetDialog(
      context,
      name: preset.name,
      tags: preset.tags,
    );
    if (result == null || !context.mounted) return;
    final (name, presetTags) = result;
    entries[index] = SearchPreset(name: name.trim(), tags: presetTags.trim());
    settings.explorePresets.value = encodeSearchPresets(entries);
  }

  Future<void> deletePreset(BuildContext context, int index) async {
    final settings = context.read<Settings>();
    final entries = presets(settings);
    if (index < 0 || index >= entries.length) return;
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
    entries.removeAt(index);
    settings.explorePresets.value = encodeSearchPresets(entries);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('Preset deleted'.tr),
      ),
    );
  }

  void applyPreset(SearchPreset preset) {
    applyTags(preset.tags);
  }

  /// Name (remark) + tags editor of a preset; returns the entry or null.
  Future<(String, String)?> _presetDialog(
    BuildContext context, {
    required String name,
    required String tags,
  }) async {
    final nameController = TextEditingController(text: name);
    final tagsController = TextEditingController(text: tags);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          name.isEmpty ? 'Save current as preset'.tr : 'Edit preset'.tr,
        ),
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
              maxLines: 3,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Search parameters'.tr,
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
}
