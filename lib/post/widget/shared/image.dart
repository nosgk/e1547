import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:e1547/files/files.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class PostImageWidget extends StatelessWidget {
  /// Displays the image of a post.
  ///
  /// Provides various preview options while loading.
  const PostImageWidget({
    super.key,
    required this.post,
    required this.size,
    this.showProgress = true,
    this.withLowRes = true,
    this.fit = BoxFit.contain,
    this.cacheSize,
    this.lowResCacheSize,
    this.load,
  });

  /// The post which provides the image.
  final PostSummary post;

  /// How the image should be fit.
  final BoxFit fit;

  /// The image size to be selected from that post (preview, sample, file).
  final PostImageSize size;

  /// Whether to display progress while the the image is loading.
  final bool showProgress;

  /// Whether an already loaded lower resolution image should be displayed while the image is loading.
  final bool withLowRes;

  /// The cache size for this image.
  final int? cacheSize;

  /// The cache size of a previously loaded lower resolution image.
  /// Used to bridge the gap between loading a downsized image and the full sized one.
  final int? lowResCacheSize;

  final ImageLoadController? load;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Builder(
        builder: (context) {
          double aspectRatio = post.width / post.height;

          switch (size) {
            case PostImageSize.preview:
              return RawPostImageWidget(
                post: post,
                size: PostImageSize.preview,
                showProgress: showProgress,
                fit: fit,
                cacheSize: cacheSize,
              );
            case PostImageSize.sample:
              return RawPostImageWidget(
                stacked: withLowRes,
                post: post,
                size: PostImageSize.sample,
                showProgress: showProgress,
                fit: fit,
                cacheSize: cacheSize,
                load: load,
                progressIndicatorBuilder: withLowRes
                    ? (context, url, progress) => ImageProgressWrapper(
                        aspectRatio: aspectRatio,
                        progress: load == null ? progress.progress : null,
                        child: lowResCacheSize != null
                            ? RawPostImageWidget(
                                post: post,
                                size: PostImageSize.sample,
                                fit: fit,
                                cacheSize: lowResCacheSize,
                              )
                            : RawPostImageWidget(
                                post: post,
                                size: PostImageSize.preview,
                                fit: fit,
                              ),
                      )
                    : null,
              );
            case PostImageSize.file:
              return RawPostImageWidget(
                stacked: true,
                post: post,
                size: PostImageSize.file,
                showProgress: showProgress,
                fit: fit,
                cacheSize: cacheSize,
                load: load,
                progressIndicatorBuilder: (context, url, progress) =>
                    ImageProgressWrapper(
                      progress: load == null ? progress.progress : null,
                      aspectRatio: aspectRatio,
                      child: RawPostImageWidget(
                        post: post,
                        size: PostImageSize.sample,
                        showProgress: showProgress,
                        fit: fit,
                        cacheSize: lowResCacheSize,
                      ),
                    ),
              );
          }
        },
      ),
    );
  }
}

/// Cancels one image download after the tile stays outside the scroll
/// viewport, then starts a fresh request if it comes back. The shared Dio
/// client is not touched, so API calls keep running.
class ViewportCachedImage extends StatefulWidget {
  const ViewportCachedImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.fadeInDuration = Duration.zero,
    this.fadeOutDuration = Duration.zero,
    this.errorWidget,
    this.progressIndicatorBuilder,
    this.imageBuilder,
    this.memCacheWidth,
    this.memCacheHeight,
    required this.cacheManager,
    this.cancelWhenOffscreen = false,
  });

  final String imageUrl;
  final BoxFit? fit;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;
  final LoadingErrorWidgetBuilder? errorWidget;
  final ProgressIndicatorBuilder? progressIndicatorBuilder;
  final ImageWidgetBuilder? imageBuilder;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final BaseCacheManager cacheManager;

  /// When false, the download is never cancelled. Detail and fullscreen
  /// images stay on this path so a zoomed or paged view is not dropped.
  final bool cancelWhenOffscreen;

  /// How long a tile must stay off screen before its download is dropped.
  /// A short flick past the tile does not cancel anything.
  static const Duration cancelDelay = Duration(milliseconds: 350);

  @override
  State<ViewportCachedImage> createState() => _ViewportCachedImageState();
}

class _ViewportCachedImageState extends State<ViewportCachedImage> {
  CancelToken? _token;
  late String _cancelKey;
  Timer? _cancelTimer;
  int _generation = 0;
  bool _onScreen = true;

  @override
  void dispose() {
    _cancelTimer?.cancel();
    final CancelToken? token = _token;
    if (token != null) {
      if (!token.isCancelled) token.cancel();
      dropFileCacheCancelToken(token);
    }
    super.dispose();
  }

  /// Cancels now, but leaves the token in the map briefly so a GET that
  /// already copied the header can still pick it up. A cache hit never
  /// calls GET, so the delayed drop keeps the map from growing. The timer
  /// is tracked and cancelled in [dispose], otherwise widget tests fail.
  void _release(CancelToken token) {
    if (!token.isCancelled) token.cancel();
    _cancelTimer?.cancel();
    _cancelTimer = Timer(
      const Duration(seconds: 2),
      () => dropFileCacheCancelToken(token),
    );
  }

  void _ensureToken() {
    if (_token != null && !_token!.isCancelled) return;
    final CancelToken token = CancelToken();
    _token = token;
    _cancelKey = stashFileCacheCancelToken(token);
    _generation++;
  }

  void _onVisibility(bool visible) {
    if (visible == _onScreen) return;
    _onScreen = visible;
    _cancelTimer?.cancel();
    if (visible) {
      final bool restart = _token?.isCancelled ?? false;
      _ensureToken();
      if (restart && mounted) setState(() {});
      return;
    }
    final CancelToken? pending = _token;
    _cancelTimer = Timer(ViewportCachedImage.cancelDelay, () {
      if (!mounted || _onScreen || pending == null || pending.isCancelled) {
        return;
      }
      _release(pending);
    });
  }

  @override
  Widget build(BuildContext context) {
    _ensureToken();
    final String cancelKey = _cancelKey;
    Widget image = CachedNetworkImage(
      key: ValueKey(_generation),
      fit: widget.fit,
      fadeInDuration: widget.fadeInDuration,
      fadeOutDuration: widget.fadeOutDuration,
      imageUrl: widget.imageUrl,
      errorWidget: widget.errorWidget,
      progressIndicatorBuilder: widget.progressIndicatorBuilder,
      imageBuilder: widget.imageBuilder,
      memCacheWidth: widget.memCacheWidth,
      memCacheHeight: widget.memCacheHeight,
      cacheManager: widget.cacheManager,
      httpHeaders: {fileCacheCancelHeader: cancelKey},
    );
    if (!widget.cancelWhenOffscreen) return image;
    return _ViewportNotice(onVisibility: _onVisibility, child: image);
  }
}

class _ViewportNotice extends StatefulWidget {
  const _ViewportNotice({required this.onVisibility, required this.child});

  final ValueChanged<bool> onVisibility;
  final Widget child;

  @override
  State<_ViewportNotice> createState() => _ViewportNoticeState();
}

class _ViewportNoticeState extends State<_ViewportNotice> {
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind(Scrollable.maybeOf(context)?.position);
    _report();
  }

  @override
  void dispose() {
    _position?.removeListener(_report);
    super.dispose();
  }

  void _bind(ScrollPosition? next) {
    if (identical(_position, next)) return;
    _position?.removeListener(_report);
    _position = next;
    _position?.addListener(_report);
  }

  void _report() {
    final bool? revealed = _revealed();
    if (revealed == null) return;
    widget.onVisibility(revealed);
  }

  /// Null when this image is not inside a scroll view, so a detail page or
  /// fullscreen image is never cancelled for being "off screen".
  bool? _revealed() {
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize || !object.attached) {
      return null;
    }
    final RenderAbstractViewport? viewport = RenderAbstractViewport.maybeOf(
      object,
    );
    if (viewport is! RenderViewportBase || !viewport.hasSize) return null;
    if (object.size.height <= 0) return null;
    final RevealedOffset revealed = viewport.getOffsetToReveal(object, 0);
    final double pixels = viewport.offset.pixels;
    final double start = revealed.offset;
    final double end = start + object.size.height;
    return end > pixels && start < pixels + viewport.size.height;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class RawPostImageWidget extends StatefulWidget {
  const RawPostImageWidget({
    super.key,
    required this.post,
    required this.size,
    this.fit,
    this.progressIndicatorBuilder,
    this.stacked = false,
    this.showProgress = true,
    this.cacheSize,
    this.load,
  });

  final PostSummary post;
  final PostImageSize size;
  final BoxFit? fit;
  final ProgressIndicatorBuilder? progressIndicatorBuilder;
  final bool stacked;
  final bool showProgress;
  final int? cacheSize;
  final ImageLoadController? load;

  @override
  State<RawPostImageWidget> createState() => _RawPostImageWidgetState();
}

class _RawPostImageWidgetState extends State<RawPostImageWidget> {
  ImageProvider? _held;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    (image, synchronousCall) => image.dispose(),
    onError: (error, stackTrace) {},
  );

  String? get _url =>
      switch (widget.size) {
        PostImageSize.preview => widget.post.preview,
        PostImageSize.sample => widget.post.sample,
        PostImageSize.file => widget.post.file,
      } ??
      widget.post.file;

  bool get _wide => widget.post.width > widget.post.height;

  void _hold() {
    final String? url = _url;
    if (url == null) {
      _stream?.removeListener(_listener);
      _stream = null;
      _held = null;
      return;
    }
    final ImageProvider image = ResizeImage.resizeIfNeeded(
      _wide ? null : widget.cacheSize,
      _wide ? widget.cacheSize : null,
      CachedNetworkImageProvider(
        url,
        cacheManager: context.read<BaseCacheManager>(),
      ),
    );
    if (image == _held) return;
    _held = image;
    _stream?.removeListener(_listener);
    _stream = image.resolve(createLocalImageConfiguration(context))
      ..addListener(_listener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _hold();
  }

  @override
  void didUpdateWidget(RawPostImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _hold();
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ImageLoadController? load = widget.load;
    final String? url = _url;
    if (url == null) return const SizedBox.shrink();
    final Duration fades = widget.stacked
        ? Duration.zero
        : const Duration(milliseconds: 500);

    Widget progressIndicator(
      BuildContext context,
      String url,
      DownloadProgress progress,
    ) {
      return Center(
        child: switch (progress.progress) {
          final double value => HexagonalLoadingIndicator(
            state: HexagonState.tracing,
            progress: value,
            size: 30,
          ),
          null => const HexagonalLoadingIndicator(size: 30),
        },
      );
    }

    return ViewportCachedImage(
      fit: widget.fit,
      fadeInDuration: fades,
      fadeOutDuration: fades,
      imageUrl: url,
      errorWidget: (context, url, error) {
        load?.report(url, ImageFailed(error));
        if (!widget.stacked) return const SizedBox.shrink();
        return defaultErrorBuilder(context, url, error);
      },
      progressIndicatorBuilder: widget.showProgress || widget.stacked
          ? (context, url, progress) {
              load?.report(url, ImageLoading(progress.progress));
              return (widget.progressIndicatorBuilder ?? progressIndicator)(
                context,
                url,
                progress,
              );
            }
          : null,
      imageBuilder: load != null
          ? (context, image) {
              load.report(url, const ImageLoaded());
              return Image(image: image, fit: widget.fit);
            }
          : null,
      memCacheWidth: _wide ? null : widget.cacheSize,
      memCacheHeight: _wide ? widget.cacheSize : null,
      cacheManager: context.read<BaseCacheManager>(),
      cancelWhenOffscreen: widget.size == PostImageSize.preview,
    );
  }
}

class ImageProgressWrapper extends StatefulWidget {
  const ImageProgressWrapper({
    super.key,
    required this.child,
    required this.aspectRatio,
    required this.progress,
  });

  /// The widget below this one in the tree.
  final Widget child;

  /// The aspect ratio of the image.
  final double aspectRatio;

  /// The download progress.
  final double? progress;

  @override
  State<ImageProgressWrapper> createState() => _ImageProgressWrapperState();
}

class _ImageProgressWrapperState extends State<ImageProgressWrapper> {
  bool visible = false;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Stack(
        fit: StackFit.passthrough,
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: widget.child),
          if (widget.progress != null)
            Positioned(
              top: 0,
              right: 0,
              left: 0,
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: defaultAnimationDuration,
                child: LinearProgressIndicator(
                  value: widget.progress,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A default error builder for cached network image.
/// Shows a centered icon.
Widget defaultErrorBuilder(BuildContext context, String url, dynamic error) =>
    const Center(child: Icon(Icons.warning_amber_outlined));

class ImageCacheSize {
  /// Configures the cache size for images.
  const ImageCacheSize(this.size);

  /// The cache size of the image.
  final int? size;
}

class ImageCacheSizeProvider extends SubProvider0<ImageCacheSize> {
  /// Provides the cache size for images to a subtree.
  ImageCacheSizeProvider({required int? size, super.child, super.builder})
    : super(
        create: (context) => ImageCacheSize(size),
        keys: (context) => [size],
      );

  /// Removes the cache size for images for a subtree.
  ImageCacheSizeProvider.none({super.child, super.builder})
    : super(create: (context) => const ImageCacheSize(null));
}
