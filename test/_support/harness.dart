import 'dart:io';

import 'package:e1547/settings/settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Establishes the globals that `AppInit` sets up in production, and restores
/// real networking so tests can reach a local server.
Future<void> initializeTestApp() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The test binding's HttpOverrides fails every request, loopback included.
  HttpOverrides.global = null;
  PackageInfo.setMockInitialValues(
    appName: 'e1547',
    packageName: 'net.clynamic.e1547',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );
  await AppInfo.initializePlatform(
    developer: 'test',
    github: null,
    discord: null,
    website: null,
    kofi: null,
    email: null,
    forumTopicId: null,
  );
}

/// Query builders schedule their cache entry for deletion as they unmount, and
/// that timer has to run out while the test still owns the clock.
///
/// Widget tests that open a gallery also start real HTTP from `runAsync`.
/// Dio's connect timeout is a `Timer` created back in the test's fake clock,
/// and closing the client afterwards cannot cancel it. Tests opt out of that
/// timeout and drop the client before the binding checks for pending timers.
void displayTest(String description, WidgetTesterCallback body) =>
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

/// Stops a Dio instance from arming the 30s connect timer that widget tests
/// cannot drain. Pass this as `connectTimeout` to `createDefaultDio`.
const Duration noTestConnectTimeout = Duration.zero;
