import 'dart:math';

import 'package:e1547/shared/shared.dart';
import 'package:e1547/tag/tag.dart';
import 'package:flutter/material.dart';

/// Tag categories the universal slot machine can roll, with the numeric
/// category ids the tags endpoint expects.
enum SlotCategory {
  general(0, 'General'),
  artist(1, 'Artist'),
  copyright(3, 'Copyright'),
  character(4, 'Character'),
  species(5, 'Species');

  const SlotCategory(this.id, this.labelKey);

  final int id;

  /// i18n key of the category name.
  final String labelKey;
}

/// The universal slot machine: picks a tag category, fetches that
/// category's most used tags and flickers through them with a
/// decelerating spin. Returns the picked tag (a plain tag name - no
/// category prefix), or null when dismissed.
Future<String?> showTagSlotDialog(
  BuildContext context, {
  required TagClient tags,
}) => showDialog(
  context: context,
  builder: (context) => _TagSlotDialog(tags: tags),
);

class _TagSlotDialog extends StatefulWidget {
  const _TagSlotDialog({required this.tags});

  final TagClient tags;

  @override
  State<_TagSlotDialog> createState() => _TagSlotDialogState();
}

class _TagSlotDialogState extends State<_TagSlotDialog>
    with SingleTickerProviderStateMixin {
  static const int _pages = 3;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  SlotCategory _category = SlotCategory.species;
  List<String> _pool = const [];
  String? _error;
  bool _loading = false;
  int _resultIndex = 0;
  int _start = 0;
  late int _steps;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _pool = const [];
    });
    try {
      final names = <String>[];
      for (var page = 1; page <= _pages; page++) {
        final tags = await widget.tags.page(
          page: page,
          query: {
            'search[category]': '${_category.id}',
            'search[order]': 'count',
            'search[hide_empty]': 'true',
            'limit': '320',
          },
        );
        names.addAll(tags.map((tag) => tag.name));
        if (tags.length < 320) break;
      }
      if (!mounted) return;
      if (names.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No tags found'.tr;
        });
        return;
      }
      setState(() {
        _pool = names;
        _loading = false;
        _resultIndex = Random().nextInt(names.length);
        _start = Random().nextInt(names.length);
        _steps = names.length * 10 + (_resultIndex - _start) % names.length;
      });
      _controller
        ..reset()
        ..forward();
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load'.tr;
      });
    }
  }

  String get _result => _pool[_resultIndex];

  String _at(double t) {
    if (_pool.isEmpty) return '…';
    final index =
        (_start + (Curves.easeOutQuart.transform(t.clamp(0, 1)) * _steps))
            .floor() %
        _pool.length;
    return _pool[index];
  }

  void _spin() {
    if (_pool.isEmpty) return;
    setState(() {
      _start = _resultIndex;
      _resultIndex = Random().nextInt(_pool.length);
      _steps = _pool.length * 10 + (_resultIndex - _start) % _pool.length;
    });
    _controller
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.casino_outlined),
          const SizedBox(width: 8),
          Flexible(child: Text('Universal slot'.tr)),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final category in SlotCategory.values)
                    ChoiceChip(
                      label: Text(category.labelKey.tr),
                      selected: _category == category,
                      onSelected: (_) {
                        setState(() => _category = category);
                        _load();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final label = _loading
                        ? 'Fetching tags...'.tr
                        : _error ??
                              (_controller.isCompleted
                                  ? _result
                                  : _at(_controller.value));
                    return Column(
                      children: [
                        Text(
                          label,
                          style: const TextStyle(fontFamily: 'monospace'),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Icon(
                          _controller.isCompleted
                              ? Icons.pause_presentation_outlined
                              : Icons.more_horiz,
                          size: 16,
                          color: dimTextColor(context),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The feed will use the rolled tag'.tr,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: dimTextColor(context)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _pool.isEmpty ? null : _spin,
          child: Text('Roll again'.tr),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => FilledButton(
            onPressed: _controller.isCompleted
                ? () => Navigator.of(context).pop(_result)
                : null,
            child: Text('Use it'.tr),
          ),
        ),
      ],
    );
  }
}
