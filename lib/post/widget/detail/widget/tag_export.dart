import 'dart:io';

import 'package:e1547/post/post.dart';
import 'package:e1547/settings/settings.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/tag/tag.dart';
import 'package:e1547/translate/translate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// Every tag of [post], one per line, in display order.
String postTagsText(Post post) =>
    [for (final tags in post.tags.values) ...tags].join('\n');

/// File name base of [post]'s media ("artist - 123"), shared by the media
/// download and the tag export.
String postDownloadBase(Post post) {
  String filename = '';
  final List<String> artists = filterArtists(post.tags['artist'] ?? const []);
  if (artists.isNotEmpty) {
    filename = '${artists.join(', ')} - ';
  }
  return '$filename${post.id}';
}

/// Copies every tag of [post] to the clipboard.
Future<void> copyPostTags(BuildContext context, Post post) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: postTagsText(post)));
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 2),
      content: Text('Tags copied to clipboard'.tr),
    ),
  );
}

/// Writes every tag of [post] to a .txt file ("artist - 123.txt") in the
/// download directory's "Tags" folder, asking for a directory when none is
/// configured.
Future<void> exportPostTags(BuildContext context, Post post) async {
  final messenger = ScaffoldMessenger.of(context);
  // Settings are absent in tests and standalone hosts; fall back to the
  // default download directory.
  final Settings? settings = trySettingsOf(context);
  try {
    final directory =
        settings?.downloadPath.value ?? await getDefaultDownloadPath();
    final fileName = '${postDownloadBase(post)}.txt';
    final temporary = File(
      join((await getTemporaryDirectory()).path, 'tag-export', fileName),
    );
    await temporary.create(recursive: true);
    await temporary.writeAsString('${postTagsText(post)}\n', flush: true);
    await FileDownloader.downloadFile(
      file: temporary,
      directory: directory,
      folderName: 'Tags',
      fileName: fileName,
      onDirectoryChanged: (dir) => settings?.downloadPath.value = dir,
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
