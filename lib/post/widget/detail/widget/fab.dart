import 'dart:io';

import 'package:e1547/post/post.dart';
import 'package:e1547/settings/settings.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/tag/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// The post detail action bar: favorite (heart) plus tag export to
/// clipboard, tag export to a .txt file and an original-resolution
/// download, arranged as one pill-shaped FAB.
class PostDetailFab extends StatelessWidget {
  const PostDetailFab({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final divider = Theme.of(context).dividerColor;
    Widget divider1() => Container(width: 1, height: 22, color: divider);
    return FloatingActionButton(
      heroTag: null,
      clipBehavior: Clip.antiAlias,
      backgroundColor: Theme.of(context).cardColor,
      foregroundColor: Theme.of(context).iconTheme.color,
      shape: const StadiumBorder(),
      onPressed: () {},
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: FavoriteButton(post: post),
          ),
          divider1(),
          _FabAction(
            icon: Icons.copy_rounded,
            tooltip: 'Copy tags'.tr,
            onTap: () => _copyTags(context),
          ),
          divider1(),
          _FabAction(
            icon: Icons.save_alt_rounded,
            tooltip: 'Export tags to file'.tr,
            onTap: () => _exportTags(context),
          ),
          divider1(),
          _FabAction(
            icon: Icons.file_download_rounded,
            tooltip: 'Download'.tr,
            enabled: post.file != null,
            onTap: () => postDownloadingNotification(context, {post}),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// Every tag of the post, one per line, in display order.
  String get _tagsText =>
      [for (final tags in post.tags.values) ...tags].join('\n');

  Future<void> _copyTags(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _tagsText));
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('Tags copied to clipboard'.tr),
      ),
    );
  }

  /// Writes the tags to a .txt file next to the downloaded media
  /// (artist - id.txt), asking for a directory when none is configured.
  Future<void> _exportTags(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final settings = context.read<Settings>();
    try {
      final directory =
          settings.downloadPath.value ?? await getDefaultDownloadPath();
      final fileName = '${_downloadBase()}.txt';
      final temporary = File(
        join((await getTemporaryDirectory()).path, 'tag-export', fileName),
      );
      await temporary.create(recursive: true);
      await temporary.writeAsString('$_tagsText\n', flush: true);
      await FileDownloader.downloadFile(
        file: temporary,
        directory: directory,
        folderName: 'Tags',
        fileName: fileName,
        onDirectoryChanged: (dir) => settings.downloadPath.value = dir,
      );
      try {
        await temporary.parent.delete(recursive: true);
      } on FileSystemException {
        // Cleanup is best-effort.
      }
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text('Tags exported'.tr),
        ),
      );
    } on Object catch (error) {
      // Covers FileDownloadException (no directory picked) and platforms
      // without generic file downloading (iOS).
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(
            error is FileDownloadException
                ? '${error.message ?? error}'
                : '$error',
          ),
        ),
      );
    }
  }

  String _downloadBase() {
    String filename = '';
    final List<String> artists = filterArtists(post.tags['artist'] ?? const []);
    if (artists.isNotEmpty) {
      filename = '${artists.join(', ')} - ';
    }
    return '$filename${post.id}';
  }
}

/// One icon action of the detail FAB with a contained circular ripple and
/// a tooltip; [enabled] only dims the icon.
class _FabAction extends StatelessWidget {
  const _FabAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 44,
        height: 48,
        child: InkResponse(
          containedInkWell: true,
          customBorder: const CircleBorder(),
          radius: 22,
          onTap: enabled ? onTap : null,
          child: Icon(
            icon,
            size: 22,
            color: enabled
                ? IconTheme.of(context).color
                : dimTextColor(context),
          ),
        ),
      ),
    );
  }
}
