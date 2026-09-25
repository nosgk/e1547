import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:e1547/app/app.dart';
import 'package:e1547/settings/settings.dart';
import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef LinkCallback = FutureOr<void> Function(Uri? url);

class AppLinkHandler extends StatefulWidget {
  const AppLinkHandler({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<AppLinkHandler> createState() => _AppLinkHandlerState();
}

class _AppLinkHandlerState extends State<AppLinkHandler>
    with WidgetsBindingObserver {
  late AppLinks appLinks;
  StreamSubscription<Uri>? linkListener;
  String? _lastClipboard;
  bool _prompting = false;

  Future<void> onInitialLink(Uri? url) async {
    if (url != null) {
      VoidCallback? action = const E621LinkParser().parseOnTap(
        widget.navigatorKey.currentContext!,
        url.toString(),
      );
      if (action != null) {
        widget.navigatorKey.currentState!.popUntil((route) => false);
        action();
      } else {
        await launch(url.toString());
      }
    }
  }

  Future<void> onLink(Uri? url) async {
    if (url != null) {
      if (!const E621LinkParser().open(
        widget.navigatorKey.currentContext!,
        url.toString(),
      )) {
        await launch(url.toString());
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (PlatformCapabilities.hasDeepLinks) {
      appLinks = AppLinks();
      appLinks.getInitialLink().then(onInitialLink);
      linkListener = appLinks.uriLinkStream.listen(onLink);
    }
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    linkListener?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  bool _isSiteLink(Uri uri) =>
      uri.host.isEmpty || uri.host == 'e621.net' || uri.host == 'e926.net';

  Future<void> _checkClipboard() async {
    if (!mounted || _prompting) return;
    if (!context.read<Settings>().clipboardLinkPrompt.value) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || text == _lastClipboard || !mounted) {
      return;
    }
    final uri = Uri.tryParse(text);
    if (uri == null || !_isSiteLink(uri)) return;
    if (const E621LinkParser().parse(text) == null) return;
    _lastClipboard = text;
    final nav = widget.navigatorKey.currentContext;
    if (nav == null || !nav.mounted) return;
    _prompting = true;
    final open = await showDialog<bool>(
      context: nav,
      builder: (context) => AlertDialog(
        title: Text('Open this link?'.tr),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('CANCEL'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Open'.tr),
          ),
        ],
      ),
    );
    _prompting = false;
    if (open != true || !mounted) return;
    final target = widget.navigatorKey.currentContext;
    if (target == null || !target.mounted) return;
    if (!const E621LinkParser().open(target, text)) {
      await launch(text);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
