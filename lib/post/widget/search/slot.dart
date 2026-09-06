import 'dart:math';

import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';

/// Curated species tags for the slot machine, in flicker order.
const List<String> kPlaySpecies = [
  'canine',
  'feline',
  'dragon',
  'equine',
  'avian',
  'reptile',
  'amphibian',
  'marsupial',
  'rodent',
  'lagomorph',
  'mustelid',
  'ursid',
  'bovid',
  'cervid',
  'cetacean',
  'insect',
  'arachnid',
  'alien',
  'human',
];

/// The species slot machine: flickers through the curated species pool
/// with a decelerating spin and lands on a random species. Returns the
/// picked species tag, or null when dismissed.
Future<String?> showSpeciesSlotDialog(BuildContext context) => showDialog(
  context: context,
  builder: (context) => const _SpeciesSlotDialog(),
);

class _SpeciesSlotDialog extends StatefulWidget {
  const _SpeciesSlotDialog();

  @override
  State<_SpeciesSlotDialog> createState() => _SpeciesSlotDialogState();
}

class _SpeciesSlotDialogState extends State<_SpeciesSlotDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();

  int _resultIndex = Random().nextInt(kPlaySpecies.length);
  int _start = Random().nextInt(kPlaySpecies.length);
  // Enough laps for a proper flicker; the sequence ends exactly on the
  // picked result.
  late int _steps =
      kPlaySpecies.length * 10 + (_resultIndex - _start) % kPlaySpecies.length;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _at(double t) {
    final index =
        (_start + (Curves.easeOutQuart.transform(t.clamp(0, 1)) * _steps))
            .floor() %
        kPlaySpecies.length;
    return kPlaySpecies[index];
  }

  void _spin() {
    setState(() {
      _start = _resultIndex;
      _resultIndex = Random().nextInt(kPlaySpecies.length);
      _steps =
          kPlaySpecies.length * 10 +
          (_resultIndex - _start) % kPlaySpecies.length;
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
          Flexible(child: Text('Species slot'.tr)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              builder: (context, child) => Column(
                children: [
                  Text(
                    'species:${_at(_controller.value)}',
                    style: const TextStyle(fontFamily: 'monospace'),
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
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The feed will use the landed species tag'.tr,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: dimTextColor(context)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _spin, child: Text('Roll again'.tr)),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => FilledButton(
            onPressed: _controller.isCompleted
                ? () => Navigator.of(context).pop(kPlaySpecies[_resultIndex])
                : null,
            child: Text('Use it'.tr),
          ),
        ),
      ],
    );
  }
}
