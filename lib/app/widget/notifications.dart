import 'dart:async';
import 'dart:convert';

import 'package:e1547/app/app.dart';
import 'package:e1547/client/client.dart';
import 'package:e1547/follow/follow.dart';
import 'package:e1547/logs/logs.dart';
import 'package:e1547/pool/pool.dart';
import 'package:e1547/post/post.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/tag/tag.dart';
import 'package:e1547/task/task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_sub/flutter_sub.dart';

class NotificationHandler extends StatefulWidget {
  const NotificationHandler({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<NotificationHandler> createState() => _NotificationHandlerState();
}

class _NotificationHandlerState extends State<NotificationHandler> {
  late Future<FlutterLocalNotificationsPlugin> notifications =
      initializeNotifications(onDidReceiveNotificationResponse: handle);
  List<Follow>? previousFollows;
  Logger logger = Logger('NotificationRouter');

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    if (!PlatformCapabilities.hasNotifications) return;
    NotificationAppLaunchDetails? details = await (await notifications)
        .getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp) {
      NotificationResponse? response = details.notificationResponse;
      if (response != null) {
        handle(response);
      }
    }
  }

  Future<void> setupFollowBackground(List<Follow> follows) async {
    if (!PlatformCapabilities.hasNotifications) return;
    bool wasNotifying =
        previousFollows != null &&
        previousFollows!.where((e) => e.type == FollowType.notify).isNotEmpty;
    bool isNotifying = follows
        .where((e) => e.type == FollowType.notify)
        .isNotEmpty;
    if (wasNotifying == isNotifying) return;

    if (isNotifying) {
      bool? result;
      result = await (await notifications)
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      result = await (await notifications)
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      if (!(result ?? true)) return;
    }
    registerFollowBackgroundTask(follows);
  }

  Future<void> sendNotifications(List<Follow> follows, int identity) async {
    if (!PlatformCapabilities.hasNotifications) return;
    if (previousFollows != null) {
      final BaseCacheManager cache = context.read<BaseCacheManager>();
      await updateFollowNotifications(
        identity: identity,
        previous: previousFollows!,
        updated: follows,
        notifications: await notifications,
        cache: cache,
      );
    }
  }

  Future<void> handle(NotificationResponse response) async {
    if (!context.mounted) return;
    String? payload = response.payload;
    if (payload == null) return;
    NotificationPayload? notification;
    try {
      notification = NotificationPayload.fromJson(json.decode(payload));
    } on FormatException catch (e, s) {
      logger.error('Failed to parse notification payload', null, e, s);
      return;
    }

    switch (notification.type) {
      case 'follow':
        widget.navigatorKey.currentState!.pushNamedAndRemoveUntil(
          '/subscriptions',
          (_) => false,
        );
        if (notification.query != null) {
          final String? tags = notification.query!['tags'];
          final poolId = tags != null
              ? poolRegex().firstMatch(tags)?.namedGroup('id')
              : null;
          widget.navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (context) => poolId != null
                  ? PoolLoadingPage(int.parse(poolId), orderByOldest: false)
                  : PostsPage(params: PostParams(tags: tags)),
            ),
          );
        }
        if (notification.id != null) {
          widget.navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (context) => PostLoadingPage(notification!.id!),
            ),
          );
        }
        break;
      default:
        logger.warn('Unknown notification type {type}', {
          'type': notification.type,
        });
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = context.watch<Client>();
    return SubStream<List<Follow>>(
      create: () => client.follows
          .all(query: FollowsQuery(types: [FollowType.notify]))
          .streamed,
      keys: [client],
      listener: (event) async {
        await Future.wait([
          setupFollowBackground(event),
          sendNotifications(event, client.identity.id),
        ]);
        previousFollows = event;
      },
      builder: (context, stream) => DownloadProgressNotifier(
        notifications: notifications,
        child: widget.child,
      ),
    );
  }
}

/// One ongoing notification for in-flight downloads: count, bytes and rate.
class DownloadProgressNotifier extends StatefulWidget {
  const DownloadProgressNotifier({
    super.key,
    required this.notifications,
    required this.child,
  });

  final Future<FlutterLocalNotificationsPlugin> notifications;
  final Widget child;

  @override
  State<DownloadProgressNotifier> createState() =>
      _DownloadProgressNotifierState();
}

class _DownloadProgressNotifierState extends State<DownloadProgressNotifier> {
  static final int _id = 'downloads'.hashCode;
  TasksController? _controller;
  final Map<int, VoidCallback> _transferListeners = {};
  Timer? _refresh;
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.read<TasksController>();
    if (!identical(next, _controller)) {
      _controller?.removeListener(_onTasks);
      _unbindTransfers();
      _controller = next;
      next.addListener(_onTasks);
      _onTasks();
    }
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _controller?.removeListener(_onTasks);
    _unbindTransfers();
    if (_visible) {
      widget.notifications.then((plugin) => plugin.cancel(id: _id));
    }
    super.dispose();
  }

  void _unbindTransfers() {
    final controller = _controller;
    if (controller == null) {
      _transferListeners.clear();
      return;
    }
    for (final entry in _transferListeners.entries) {
      controller.transferOf(entry.key)?.removeListener(entry.value);
    }
    _transferListeners.clear();
  }

  void _onTasks() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final running = controller.active
        .where(
          (task) =>
              task.action == TaskAction.download && controller.isRunning(task.id),
        )
        .map((task) => task.id)
        .toSet();
    for (final id in _transferListeners.keys.toList()) {
      if (running.contains(id)) continue;
      controller.transferOf(id)?.removeListener(_transferListeners[id]!);
      _transferListeners.remove(id);
    }
    for (final id in running) {
      if (_transferListeners.containsKey(id)) continue;
      void listener() => _schedule();
      controller.transferOf(id)?.addListener(listener);
      _transferListeners[id] = listener;
    }
    _schedule();
  }

  void _schedule() {
    _refresh ??= Timer(const Duration(milliseconds: 400), () {
      _refresh = null;
      _publish();
    });
  }

  Future<void> _publish() async {
    if (!mounted || !PlatformCapabilities.hasNotifications) return;
    final controller = _controller;
    if (controller == null) return;
    final ids = controller.active
        .where(
          (task) =>
              task.action == TaskAction.download && controller.isRunning(task.id),
        )
        .map((task) => task.id)
        .toList();
    final plugin = await widget.notifications;
    if (!mounted) return;
    if (ids.isEmpty) {
      if (_visible) {
        _visible = false;
        await plugin.cancel(id: _id);
      }
      return;
    }
    var received = 0;
    var total = 0;
    var known = true;
    var rate = 0.0;
    for (final id in ids) {
      final transfer =
          controller.transferOf(id)?.value ?? const DownloadTransfer();
      received += transfer.received;
      rate += transfer.bytesPerSecond;
      final expected = transfer.total;
      if (expected == null) {
        known = false;
      } else {
        total += expected;
      }
    }
    final progress = known && total > 0
        ? (received / total * 100).round().clamp(0, 100)
        : null;
    final count = ids.length == 1
        ? '1 download'.tr
        : '{count} downloads'.trArgs({'count': '${ids.length}'});
    await plugin.show(
      id: _id,
      title: 'Downloading'.tr,
      body: '$count · ${formatTransfer(DownloadTransfer(
        received: received,
        total: known ? total : null,
        bytesPerSecond: rate,
      ))}',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'downloads',
          'Downloads'.tr,
          channelDescription: 'Progress of file downloads'.tr,
          ongoing: true,
          onlyAlertOnce: true,
          showProgress: progress != null,
          maxProgress: 100,
          progress: progress ?? 0,
          category: AndroidNotificationCategory.progress,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentSound: false,
        ),
      ),
    );
    _visible = true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
