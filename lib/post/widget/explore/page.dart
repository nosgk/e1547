import 'package:e1547/client/client.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/query/query.dart';
import 'package:e1547/settings/settings.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/tag/tag.dart';
import 'package:e1547/traits/traits.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _DateComparison { on, before, after }

/// The explore feed ("随便看看"): an endless stream of randomly ordered
/// posts, assembled from repeated `order:random` requests. A mode picker
/// wraps the stream in themed play modes, the effective tag parameters are
/// always visible and editable, and the local blacklist can be injected
/// into the request as negated tags.
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  ExploreMode _mode = ExploreMode.random;
  String _tags = 'order:random';
  String? _species;
  bool _injectBlacklist = true;

  /// Captured when the provider creates the controller; the State's own
  /// context sits above the provider and cannot read it.
  PostParamsController? _params;

  @override
  void dispose() {
    // The cosmetics must not leak into regular browsing.
    ExploreCosmetics.instance.setMode(gacha: false, quiz: false);
    super.dispose();
  }

  /// The user-editable base query.
  String get _baseTags => _tags;

  /// Negated local blacklist terms; complex queries with spaces stay
  /// client-side (the post filter covers them).
  List<String> _denyTerms(Client client) => [
    for (final tag in client.traits.value.denylist)
      if (tag.trim().isNotEmpty && !tag.trim().contains(' ')) '-${tag.trim()}',
  ];

  String _effectiveTags(Client client, {String? base}) {
    final query = (base ?? _baseTags)
        .split(' ')
        .where((term) => term.isNotEmpty)
        .toList();
    if (_injectBlacklist) query.addAll(_denyTerms(client));
    final result = query.join(' ');
    return result.isEmpty ? 'order:random' : result;
  }

  void _sync() {
    final client = context.read<Client>();
    _params?.update((p) => p.copyWith(tags: _effectiveTags(client)));
  }

  // --- quick sort ------------------------------------------------------------

  /// The first token of [_tags] starting with [prefix] (e.g. "order:",
  /// "date:"). Single source of truth stays the editable tag string.
  String? _termOf(String prefix) {
    for (final token in _tags.split(' ')) {
      if (token.startsWith(prefix)) return token;
    }
    return null;
  }

  /// Returns [_tags] with every token starting with [prefix] replaced by
  /// [term] (removed when null).
  String _withTerm(String prefix, String? term) {
    final tokens = _tags
        .split(' ')
        .where((token) => token.isNotEmpty && !token.startsWith(prefix))
        .toList();
    if (term != null) tokens.add(term);
    return tokens.isEmpty ? 'order:random' : tokens.join(' ');
  }

  String? _orderLabel(String? term) => switch (term) {
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
  Future<void> _pickDate() async {
    final current = _termOf('date:');
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
    if (term == null || !mounted) return;
    setState(() {
      _tags = _withTerm('date:', term!.isEmpty ? null : term);
    });
    _sync();
  }

  Future<void> _pickOrder() async {
    final options = {
      'order:favcount': 'Most favorites'.tr,
      'order:favcount_asc': 'Fewest favorites'.tr,
      'order:score': 'Highest score'.tr,
      'order:score_asc': 'Lowest score'.tr,
      'order:id_desc': 'Newest posts'.tr,
      'order:id_asc': 'Oldest posts'.tr,
      'order:random': 'Random order'.tr,
    };
    final current = _termOf('order:');
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
    if (result == null || !mounted) return;
    setState(() => _tags = _withTerm('order:', result.isEmpty ? null : result));
    _sync();
  }

  // --- quick search presets ----------------------------------------------------

  List<ExplorePreset> _presets(Settings settings) =>
      parseExplorePresets(settings.explorePresets.value);

  Future<void> _addPreset() async {
    final settings = context.read<Settings>();
    final result = await _presetDialog(name: '', tags: _baseTags);
    if (result == null || !mounted) return;
    final (name, tags) = result;
    if (tags.trim().isEmpty) return;
    final presets = [
      ..._presets(settings),
      ExplorePreset(name: name.trim(), tags: tags.trim()),
    ];
    settings.explorePresets.value = encodeExplorePresets(presets);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('Preset saved'.tr),
      ),
    );
  }

  Future<void> _editPreset(int index) async {
    final settings = context.read<Settings>();
    final presets = _presets(settings);
    if (index < 0 || index >= presets.length) return;
    final preset = presets[index];
    final result = await _presetDialog(name: preset.name, tags: preset.tags);
    if (result == null || !mounted) return;
    final (name, tags) = result;
    presets[index] = ExplorePreset(name: name.trim(), tags: tags.trim());
    settings.explorePresets.value = encodeExplorePresets(presets);
  }

  Future<void> _deletePreset(int index) async {
    final settings = context.read<Settings>();
    final presets = _presets(settings);
    if (index < 0 || index >= presets.length) return;
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
    if (confirmed != true || !mounted) return;
    presets.removeAt(index);
    settings.explorePresets.value = encodeExplorePresets(presets);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('Preset deleted'.tr),
      ),
    );
  }

  /// Name (remark) + tags editor of a preset; returns the entry or null.
  Future<(String, String)?> _presetDialog({
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

  Future<void> _applyMode(ExploreMode mode) async {
    setState(() {
      _mode = mode;
      _tags = mode.tags(species: _species);
    });
    ExploreCosmetics.instance.setMode(
      gacha: mode == ExploreMode.gacha,
      quiz: mode == ExploreMode.quiz,
    );
    _sync();
    if (mode == ExploreMode.species && _species == null && mounted) {
      await _pickSpecies();
    }
  }

  Future<void> _pickSpecies() async {
    final species = await showSpeciesSlotDialog(context);
    if (species == null || !mounted) return;
    setState(() {
      _species = species;
      _mode = ExploreMode.species;
      _tags = ExploreMode.species.tags(species: species);
    });
    _sync();
  }

  Future<void> _editTags() async {
    final client = context.read<Client>();
    final controller = TextEditingController(text: _baseTags);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit parameters'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Search parameters'.tr,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
            const SizedBox(height: 8),
            // Live transparency: the dialog always shows the query that
            // will actually be sent, blacklist injection included.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                final effective = _effectiveTags(client, base: value.text);
                return Text(
                  effective,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: dimTextColor(context),
                    fontFamily: 'monospace',
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('CANCEL'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text('Save'.tr),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _tags = result.trim().isEmpty ? 'order:random' : result.trim();
    });
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final client = context.watch<Client>();
    return RouterDrawerEntry<ExplorePage>(
      child: FilterControllerProvider(
        create: (_) => PostFilter(client),
        keys: (_) => [client],
        child: ChangeNotifierProvider(
          create: (context) {
            final params = PostParamsController(
              initial: PostParams(tags: _effectiveTags(client)),
              canSearch: false,
            );
            _params = params;
            return params;
          },
          child: PostPageQueryBuilder(
            builder: (context, state, query) => SelectionLayout<Post>(
              items: state.data?.pages.expand((p) => p).toList(),
              child: AdaptiveScaffold(
                appBar: PostSelectionAppBar(
                  child: DefaultAppBar(
                    title: Text('Explore'.tr),
                    actions: [
                      IconButton(
                        tooltip: 'Shuffle'.tr,
                        icon: const Icon(Icons.casino_outlined),
                        onPressed: query.invalidate,
                      ),
                      const ContextDrawerButton(),
                    ],
                  ),
                ),
                endDrawer: _buildDrawer(context, client, state),
                body: Column(
                  children: [
                    _TagQueryBanner(
                      client: client,
                      base: _baseTags,
                      inject: _injectBlacklist,
                      mode: _mode,
                      onTap: _editTags,
                    ),
                    Expanded(
                      child: PullToRefresh(
                        onRefresh: query.invalidate,
                        child: CustomScrollView(
                          primary: true,
                          slivers: [
                            SliverPadding(
                              padding: defaultActionListPadding,
                              sliver: const SliverPostList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    Client client,
    InfiniteQueryStatus<List<Post>, int> state,
  ) {
    return ContextDrawer(
      title: Text('Explore play modes'.tr),
      children: [
        SectionHeader(
          indent: SectionHeader.listTileIndent,
          title: 'Play modes'.tr,
        ),
        for (final mode in ExploreMode.values)
          ListTile(
            leading: Icon(mode.icon),
            title: Text(mode.label),
            subtitle: Text(mode.description),
            trailing: _mode == mode ? const Icon(Icons.check) : null,
            onTap: () {
              Navigator.of(context).pop();
              _applyMode(mode);
            },
          ),
        const Divider(),
        SectionHeader(
          indent: SectionHeader.listTileIndent,
          title: 'Search parameters'.tr,
        ),
        ListTile(
          leading: const Icon(Icons.data_object),
          title: Text('Current parameters'.tr),
          subtitle: Text(
            _effectiveTags(client),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          onTap: () {
            Navigator.of(context).pop();
            _editTags();
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.block_outlined),
          title: Text('Inject local blacklist'.tr),
          subtitle: Text(
            '{count} tags appended as negated filters'.trArgs({
              'count': '${_denyTerms(client).length}',
            }),
          ),
          value: _injectBlacklist,
          onChanged: (value) {
            setState(() => _injectBlacklist = value);
            _sync();
          },
        ),
        ListTile(
          leading: const Icon(Icons.casino_outlined),
          title: Text('Roll the species slot'.tr),
          subtitle: _species == null
              ? null
              : Text(
                  'species:$_species',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
          onTap: () {
            Navigator.of(context).pop();
            _pickSpecies();
          },
        ),
        ListTile(
          leading: const Icon(Icons.slideshow_outlined),
          title: Text('Zen slideshow'.tr),
          subtitle: Text('Fullscreen auto-advancing show'.tr),
          onTap: () {
            Navigator.of(context).pop();
            showExploreSlideshowPicker(
              context,
              initialTags: _effectiveTags(client),
            );
          },
        ),
        const Divider(),
        SectionHeader(
          indent: SectionHeader.listTileIndent,
          title: 'Quick sort'.tr,
        ),
        Builder(
          builder: (context) {
            final dateTerm = _termOf('date:');
            return ListTile(
              leading: const Icon(Icons.event_outlined),
              title: Text('Post date'.tr),
              subtitle: Text(
                dateTerm ?? 'No date filter'.tr,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              trailing: dateTerm == null
                  ? null
                  : IconButton(
                      tooltip: 'Clear date filter'.tr,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        setState(() => _tags = _withTerm('date:', null));
                        _sync();
                      },
                    ),
              onTap: _pickDate,
            );
          },
        ),
        Builder(
          builder: (context) {
            final orderTerm = _termOf('order:');
            return ListTile(
              leading: const Icon(Icons.sort_outlined),
              title: Text('Order'.tr),
              subtitle: Text(
                orderTerm == null ? '—' : (_orderLabel(orderTerm) ?? orderTerm),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              onTap: _pickOrder,
            );
          },
        ),
        const Divider(),
        SectionHeader(
          indent: SectionHeader.listTileIndent,
          title: 'Quick search presets'.tr,
        ),
        ListTile(
          leading: const Icon(Icons.bookmark_add_outlined),
          title: Text('Save current as preset'.tr),
          subtitle: Text(
            _baseTags,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          onTap: () {
            Navigator.of(context).pop();
            _addPreset();
          },
        ),
        for (final (index, preset) in _presets(
          context.read<Settings>(),
        ).indexed)
          ListTile(
            leading: const Icon(Icons.bookmark_outline),
            title: Text(
              preset.name.isEmpty ? 'Preset'.tr : preset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              preset.tags,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _tags = preset.tags;
              });
              _sync();
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit preset'.tr,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _editPreset(index);
                  },
                ),
                IconButton(
                  tooltip: 'Delete preset'.tr,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _deletePreset(index);
                  },
                ),
              ],
            ),
          ),
        if (_presets(context.read<Settings>()).isEmpty)
          ListTile(
            enabled: false,
            leading: const Icon(Icons.bookmark_border),
            title: Text('No presets yet'.tr),
          ),
        const Divider(),
        const DrawerDenySwitch(),
        DrawerTagCounter(
          posts: state.data?.pages.expand((p) => p).toList(),
          error: state.error,
        ),
      ],
    );
  }
}

/// The always-visible, always-editable tag parameter strip under the app
/// bar: the base query in the normal color, the injected blacklist terms
/// dimmed. This is the transparency contract of the page.
class _TagQueryBanner extends StatelessWidget {
  const _TagQueryBanner({
    required this.client,
    required this.base,
    required this.inject,
    required this.mode,
    required this.onTap,
  });

  final Client client;
  final String base;
  final bool inject;
  final ExploreMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: client.traits,
      builder: (context, child) {
        final injected = inject
            ? [
                for (final tag in client.traits.value.denylist)
                  if (tag.trim().isNotEmpty && !tag.trim().contains(' '))
                    '-${tag.trim()}',
              ]
            : const <String>[];
        const style = TextStyle(fontFamily: 'monospace', fontSize: 12);
        final dimStyle = style.copyWith(color: dimTextColor(context));
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Icon(mode.icon, size: 14, color: dimTextColor(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: base, style: style),
                          if (injected.isNotEmpty)
                            TextSpan(
                              text: ' ${injected.join(' ')}',
                              style: dimStyle,
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: dimTextColor(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
