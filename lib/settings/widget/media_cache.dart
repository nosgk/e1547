import 'dart:async';

import 'package:e1547/files/files.dart';
import 'package:e1547/settings/settings.dart';
import 'package:e1547/shared/shared.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Settings tile for the media file cache: shows the current usage and
/// opens the [showMediaCacheDialog] management dialog.
class MediaCacheTile extends StatelessWidget {
  const MediaCacheTile({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.read<Settings>();
    return AnimatedBuilder(
      animation: Listenable.merge([
        context.read<MediaCacheManager>(),
        settings.mediaCacheLimitMb,
      ]),
      builder: (context, child) {
        final manager = context.read<MediaCacheManager>();
        final stats = manager.stats;
        return ListTile(
          title: Text('Media cache'.tr),
          subtitle: Text(
            stats == null
                ? '…'
                : [
                    '{size} · {count} items'.trArgs({
                      'size': filesize(stats.bytes),
                      'count': '${stats.count}',
                    }),
                    mediaCacheLimitLabel(settings.mediaCacheLimitMb.value),
                  ].join('\n'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: dimTextColor(context)),
          ),
          leading: const Icon(Icons.photo_library_outlined),
          onTap: () => showMediaCacheDialog(context),
        );
      },
    );
  }
}

/// User-facing label of a cache budget in megabytes (0 = unlimited).
String mediaCacheLimitLabel(int mb) {
  if (mb <= 0) return 'Unlimited'.tr;
  return filesize(mb * 1024 * 1024);
}

/// Management dialog for the media file cache: current usage with an
/// animated usage bar, the six budget tiers (250 MB / 500 MB / 1 GB /
/// 5 GB / unlimited / custom) and a clear-everything action.
Future<void> showMediaCacheDialog(BuildContext context) async {
  final settings = context.read<Settings>();
  final manager = context.read<MediaCacheManager>();
  unawaited(manager.refresh());
  await showDialog(
    context: context,
    builder: (context) => AnimatedBuilder(
      animation: Listenable.merge([manager, settings.mediaCacheLimitMb]),
      builder: (context, child) {
        final limitMb = settings.mediaCacheLimitMb.value;
        final stats = manager.stats;
        final bytes = stats?.bytes ?? 0;
        final limited = limitMb > 0;
        final fraction = limited && stats != null
            ? (bytes / (limitMb * 1024 * 1024)).clamp(0.0, 1.0)
            : null;
        return AlertDialog(
          title: Text('Media cache'.tr),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '{size} · {count} items'.trArgs({
                      'size': filesize(bytes),
                      'count': '${stats?.count ?? 0}',
                    }),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: limited ? (fraction ?? 0) : 0),
                    duration: defaultAnimationDuration,
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: limited ? value : 0,
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    limited
                        ? '{used} / {limit}'.trArgs({
                            'used': filesize(bytes),
                            'limit': mediaCacheLimitLabel(limitMb),
                          })
                        : 'Oldest entries are removed automatically when the '
                                  'limit is exceeded.'
                              .tr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: dimTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      'Cache limit'.tr,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final tier in _tiers)
                    _TierTile(
                      title: tier.label,
                      selected: _isTierSelected(tier, limitMb),
                      onTap: () {
                        settings.mediaCacheLimitMb.value = tier.mb;
                      },
                    ),
                  _TierTile(
                    title: 'Custom'.tr,
                    subtitle: _isCustom(limitMb)
                        ? mediaCacheLimitLabel(limitMb)
                        : null,
                    selected: _isCustom(limitMb),
                    onTap: () => _pickCustomLimit(context, limitMb),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _clearMediaCache(context),
              child: Text('Clear media cache'.tr),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Done'.tr),
            ),
          ],
        );
      },
    ),
  );
}

class _CacheTier {
  const _CacheTier(this.mb, this.label);

  /// Budget in megabytes; 0 = unlimited.
  final int mb;
  final String label;
}

const List<_CacheTier> _tiers = [
  _CacheTier(250, '250 MB'),
  _CacheTier(500, '500 MB'),
  _CacheTier(1024, '1 GB'),
  _CacheTier(5120, '5 GB'),
  _CacheTier(0, 'Unlimited'),
];

bool _isCustom(int mb) =>
    mb > 0 && !_tiers.any((tier) => tier.mb == mb && tier.mb > 0);

bool _isTierSelected(_CacheTier tier, int mb) =>
    tier.mb == 0 ? mb <= 0 : tier.mb == mb;

Future<void> _pickCustomLimit(BuildContext context, int current) async {
  final controller = TextEditingController(
    text: _isCustom(current) ? '$current' : '',
  );
  final result = await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Custom cache size'.tr),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'Size in megabytes'.tr,
          hintText: '1024',
          border: const OutlineInputBorder(),
          suffixText: 'MB',
        ),
        onSubmitted: (value) => Navigator.of(context).pop(int.tryParse(value)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('CANCEL'.tr),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(int.tryParse(controller.text)),
          child: Text('Done'.tr),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result != null && result > 0 && context.mounted) {
    context.read<Settings>().mediaCacheLimitMb.value = result;
  }
}

Future<void> _clearMediaCache(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final manager = context.read<MediaCacheManager>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Clear media cache'.tr),
      content: Text('Remove all cached media files? This cannot be undone.'.tr),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('CANCEL'.tr),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Clear'.tr),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await manager.clearAll();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 2),
      content: Text('Media cache cleared'.tr),
    ),
  );
}

/// One selectable budget row with an animated check indicator.
class _TierTile extends StatelessWidget {
  const _TierTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: defaultAnimationDuration,
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: selected
                    ? Icon(
                        Icons.check_circle,
                        key: const ValueKey(true),
                        size: 20,
                        color: theme.colorScheme.primary,
                      )
                    : Icon(
                        Icons.circle_outlined,
                        key: const ValueKey(false),
                        size: 20,
                        color: dimTextColor(context),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : null,
                    color: selected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: dimTextColor(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
