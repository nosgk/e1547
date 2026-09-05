import 'package:e1547/logs/logs.dart';
import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';
import 'package:recase/recase.dart';

class LogsDrawer extends StatelessWidget {
  const LogsDrawer({
    super.key,
    required this.levels,
    required this.onChanged,
    this.recording,
    this.verbose = false,
    this.onVerbose,
  });

  final Set<LogLevel> levels;
  final ValueSetter<Set<LogLevel>> onChanged;

  final LogLevel? recording;
  final bool verbose;
  final ValueSetter<bool>? onVerbose;

  void _toggle(LogLevel level, bool enabled) {
    final Set<LogLevel> next = Set.of(levels);
    if (enabled) {
      next.add(level);
    } else {
      next.remove(level);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final LogLevel? recording = this.recording;
    final ValueSetter<bool>? onVerbose = this.onVerbose;
    return ContextDrawer(
      title: Text('Logs'.tr),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: SectionHeader(
            indent: SectionHeader.listTileIndent,
            title: 'Levels'.tr,
          ),
        ),
        for (final LogLevel level in LogLevel.values)
          if (recording == null || level.isAtLeast(recording))
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: CheckboxListTile(
                secondary: Icon(level.icon),
                title: Text(level.name.pascalCase.tr),
                value: levels.contains(level),
                onChanged: (value) {
                  if (value == null) return;
                  _toggle(level, value);
                },
              ),
            ),
        if (recording != null && onVerbose != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: SectionHeader(
              indent: SectionHeader.listTileIndent,
              title: 'Recording'.tr,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: SwitchListTile(
              secondary: const Icon(Icons.data_object),
              title: Text('Verbose'.tr),
              subtitle: Text(
                verbose
                    ? 'all levels recorded'.tr
                    : '{level} and above'.trArgs({
                        'level': recording.name.pascalCase.tr,
                      }),
              ),
              value: verbose,
              onChanged: onVerbose,
            ),
          ),
        ],
      ],
    );
  }
}
