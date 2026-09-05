import 'package:e1547/post/post.dart';
import 'package:e1547/settings/settings.dart';
import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';

/// Muted, looping, autoplaying inline preview for video posts in grids and
/// timelines. Falls back to a static sample image when no Settings provider
/// is available (tests) or the video cannot be loaded.
class PreviewVideoAutoplay extends StatefulWidget {
  const PreviewVideoAutoplay({super.key, required this.post, this.fit});

  final Post post;
  final BoxFit? fit;

  @override
  State<PreviewVideoAutoplay> createState() => _PreviewVideoAutoplayState();
}

class _PreviewVideoAutoplayState extends State<PreviewVideoAutoplay> {
  VideoPlayer? _player;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_player != null || _failed || !mounted) return;
    final VideoService service;
    final VideoResolution target;
    try {
      final settings = context.read<Settings>();
      service = context.read<VideoService>();
      target = settings.previewVideoQuality.value;
    } on Object {
      _failed = true;
      return;
    }

    final post = widget.post;
    if (post.type != PostType.video || post.file == null) {
      _failed = true;
      return;
    }

    // Pick the variant whose pixel size is closest to the target quality.
    String closestUrl = post.file!;
    int? closestDifference;
    if (post.variants != null && post.variants!.isNotEmpty) {
      for (final MapEntry(:key, :value) in post.variants!.entries) {
        if (value == null) continue;
        if (!value.endsWith('mp4') && !value.endsWith('webm')) continue;
        final dimensions = key.split('x').map(int.parse).toList();
        final pixelSize = dimensions[0] * dimensions[1];
        final difference = (target.pixels - pixelSize).abs();
        if (closestDifference == null || difference < closestDifference) {
          closestDifference = difference;
          closestUrl = value;
        }
      }
    }

    final player = service.getVideo(closestUrl);
    service.acquire(player);
    await player.setVolume(0);
    await player.play();
    if (!mounted) {
      service.release(player);
      return;
    }
    setState(() => _player = player);
  }

  @override
  void dispose() {
    final player = _player;
    if (player != null) {
      try {
        final service = context.read<VideoService>();
        player.pause();
        service.release(player);
      } on Object {
        // Provider already gone; the pool recycles unleased players.
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    if (player == null) {
      return PostImageWidget(
        post: widget.post,
        size: PostImageSize.sample,
        fit: widget.fit ?? BoxFit.cover,
      );
    }
    return AspectRatio(
      aspectRatio: widget.post.width <= 0 || widget.post.height <= 0
          ? 1
          : widget.post.width / widget.post.height,
      child: Video(controller: player.controller),
    );
  }
}
