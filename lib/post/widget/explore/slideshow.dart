import 'dart:async';

import 'package:e1547/client/client.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';

const List<int> _kIntervals = [5, 10, 30, 60];

/// Source picker of the zen slideshow: an editable tag query (prefilled
/// with the explore page's current parameters, so the blacklist injection
/// stays visible) plus a slide interval. Returns the chosen configuration
/// or null when dismissed.
Future<void> showExploreSlideshowPicker(
  BuildContext context, {
  required String initialTags,
}) async {
  final controller = TextEditingController(text: initialTags);
  int seconds = 10;
  final client = context.read<Client>();
  final result = await showDialog<(String, Duration)>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Zen slideshow'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Slideshow source'.tr,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: Text('Current parameters'.tr),
                  onPressed: () => controller.text = initialTags,
                ),
                if (client.hasLogin)
                  ActionChip(
                    label: Text('Favorites'.tr),
                    onPressed: () => controller.text = 'fav:me',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Interval'.tr, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                for (final value in _kIntervals)
                  ChoiceChip(
                    label: Text('$value s'),
                    selected: seconds == value,
                    onSelected: (_) => setState(() => seconds = value),
                  ),
              ],
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
            ).pop((controller.text.trim(), Duration(seconds: seconds))),
            child: Text('Start'.tr),
          ),
        ],
      ),
    ),
  );
  if (result == null) return;
  final (tags, interval) = result;
  if (tags.isEmpty || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) =>
          ExploreSlideshowPage(tags: tags, interval: interval),
    ),
  );
}

/// Fullscreen, auto-advancing slideshow. Pages are pulled from the posts
/// index as the show runs out of material; the display fades between
/// slides and every control hides itself until the screen is tapped.
class ExploreSlideshowPage extends StatefulWidget {
  const ExploreSlideshowPage({
    super.key,
    required this.tags,
    required this.interval,
  });

  final String tags;
  final Duration interval;

  @override
  State<ExploreSlideshowPage> createState() => _ExploreSlideshowPageState();
}

class _ExploreSlideshowPageState extends State<ExploreSlideshowPage> {
  final List<Post> _posts = [];
  int _index = 0;
  int _nextPage = 1;
  bool _loading = false;
  bool _exhausted = false;

  late Duration _interval = widget.interval;
  Timer? _timer;
  bool _paused = false;
  bool _controls = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMore());
    _startTimer();
    _hideControlsLater();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controlsTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _advance());
  }

  Future<void> _loadMore() async {
    if (_loading || _exhausted) return;
    _loading = true;
    try {
      final client = context.read<Client>();
      final posts = await client.posts.page(
        page: _nextPage,
        query: {'tags': widget.tags},
      );
      if (!mounted) return;
      if (posts.isEmpty) {
        setState(() => _exhausted = true);
      } else {
        setState(() {
          _posts.addAll(posts);
          _nextPage++;
        });
      }
    } on Object {
      if (!mounted) return;
      setState(() => _exhausted = true);
    } finally {
      _loading = false;
    }
  }

  void _advance() {
    if (_paused || _posts.isEmpty) return;
    // Keep two slides of material ready.
    if (_index + 2 >= _posts.length) unawaited(_loadMore());
    if (_index + 1 < _posts.length) {
      setState(() => _index++);
    } else if (_exhausted) {
      setState(() => _index = 0);
    }
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
  }

  void _setInterval(Duration interval) {
    setState(() => _interval = interval);
    _startTimer();
  }

  void _toggleControls() {
    setState(() => _controls = !_controls);
    if (_controls) _hideControlsLater();
  }

  void _hideControlsLater() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controls = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final post = _posts.isEmpty
        ? null
        : _posts[_index.clamp(0, _posts.length - 1)];
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (post == null)
              Center(
                child: _exhausted && _posts.isEmpty
                    ? Text(
                        'No posts'.tr,
                        style: const TextStyle(color: Colors.white70),
                      )
                    : const CircularProgressIndicator(color: Colors.white70),
              )
            else
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 800),
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                child: KeyedSubtree(
                  key: ValueKey(post.id),
                  child: Center(
                    child: ImageCacheSizeProvider(
                      size: 1600,
                      child: post.type == PostType.video
                          ? _VideoSlide(post: post)
                          : PostImageWidget(
                              post: post,
                              size: PostImageSize.file,
                            ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 8,
              right: 8,
              child: AnimatedOpacity(
                opacity: _controls ? 1 : 0,
                duration: defaultAnimationDuration,
                child: Row(
                  children: [
                    _SlideControl(
                      tooltip: 'Close'.tr,
                      icon: Icons.close,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: _controlDecoration(),
                        child: Text(
                          widget.tags,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SlideControl(
                      tooltip: _paused ? 'Resume'.tr : 'Pause'.tr,
                      icon: _paused ? Icons.play_arrow : Icons.pause,
                      onTap: _togglePause,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: MediaQuery.paddingOf(context).bottom + 12,
              left: 8,
              right: 8,
              child: AnimatedOpacity(
                opacity: _controls ? 1 : 0,
                duration: defaultAnimationDuration,
                child: Column(
                  children: [
                    Text(
                      '{current} / {total}'.trArgs({
                        'current': '${_index + 1}',
                        'total': _exhausted ? '${_posts.length}' : '∞',
                      }),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final value in _kIntervals)
                          ChoiceChip(
                            label: Text('$value s'),
                            selected: _interval.inSeconds == value,
                            selectedColor: Colors.white24,
                            labelStyle: const TextStyle(color: Colors.white),
                            onSelected: (_) =>
                                _setInterval(Duration(seconds: value)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _controlDecoration() => BoxDecoration(
    color: Colors.black45,
    borderRadius: BorderRadius.circular(999),
  );
}

/// Videos cannot loop inside the fade machinery; the slide shows a still
/// frame and opens the full player on tap.
class _VideoSlide extends StatelessWidget {
  const _VideoSlide({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => PostFullscreen(post: post)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PostImageWidget(
            post: post,
            size: PostImageSize.sample,
            showProgress: false,
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideControl extends StatelessWidget {
  const _SlideControl({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black45,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
