import 'package:e1547/logs/logs.dart';
import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LogSelectionAppBar extends StatelessWidget with AppBarBuilderWidget {
  const LogSelectionAppBar({super.key, required this.child});

  @override
  final PreferredSizeWidget child;

  @override
  Widget build(BuildContext context) {
    return SelectionAppBar<LogEntry>(
      child: child,
      titleBuilder: (context, data) => data.selections.length == 1
          ? Text(data.selections.first.message, maxLines: 1)
          : Text('{count} logs'.trArgs({'count': data.selections.length})),
      actionBuilder: (context, data) => [
        IconButton(
          tooltip: 'Copy'.tr,
          icon: const Icon(Icons.copy),
          onPressed: () {
            Clipboard.setData(
              ClipboardData(
                text: data.selections.map(formatLogEntry).join('\n'),
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 1),
                content: Text('Copied to clipboard'.tr),
              ),
            );
            data.onChanged({});
          },
        ),
      ],
    );
  }
}

class LogFileSelectionAppBar extends StatelessWidget with AppBarBuilderWidget {
  const LogFileSelectionAppBar({super.key, required this.child, this.onDelete});

  @override
  final PreferredSizeWidget child;
  final ValueSetter<List<LogFileInfo>>? onDelete;

  @override
  Widget build(BuildContext context) {
    return SelectionAppBar<LogFileInfo>(
      child: child,
      titleBuilder: (context, data) => data.selections.length == 1
          ? Text('Logs - {date}'.trArgs({'date': data.selections.first.date}))
          : Text(
              '{count} log files'.trArgs({'count': data.selections.length}),
            ),
      actionBuilder: (context, data) => [
        if (onDelete != null)
          IconButton(
            tooltip: 'Delete'.tr,
            icon: const Icon(Icons.delete),
            onPressed: () => showDialog(
              context: context,
              builder: (context) => LogFileDeleteConfirmation(
                files: data.selections.toList(),
                onConfirm: () {
                  onDelete?.call(data.selections.toList());
                  data.onChanged({});
                },
              ),
            ),
          ),
      ],
    );
  }
}

class LogFileDeleteConfirmation extends StatelessWidget {
  const LogFileDeleteConfirmation({
    super.key,
    required this.files,
    required this.onConfirm,
  });

  final List<LogFileInfo> files;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Delete {count} log files?'.trArgs({'count': files.length}),
      ),
      content: Text('This action cannot be undone.'.tr),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'.tr),
        ),
        TextButton(
          onPressed: () {
            onConfirm?.call();
            Navigator.of(context).pop();
          },
          child: Text('Delete'.tr),
        ),
      ],
    );
  }
}
