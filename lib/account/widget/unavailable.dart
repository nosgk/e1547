import 'dart:io';

import 'package:e1547/account/account.dart';
import 'package:e1547/client/client.dart';
import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';

class HostUnavailablePage extends StatelessWidget {
  const HostUnavailablePage({super.key, this.offerResolve = false});

  final bool offerResolve;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TransparentAppBar(child: AppBar(leading: const CloseButton())),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 60),
              const SizedBox(height: 8),
              Text(
                'Host unavailable'.tr,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              Text(
                'It appears that {host} is not available!'.trArgs({
                  'host': linkToDisplay(context.watch<Client>().host),
                }),
              ),
              const SizedBox(height: 16),
              if (offerResolve && (Platform.isAndroid || Platform.isIOS)) ...[
                Text(
                  'Please resolve the issue in the following browser window. '
                  '\n\nCloudflare captcha cookies will be saved. '.tr,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const CookieCapturePage(),
                    ),
                  ),
                  child: Text('Resolve'.tr),
                ),
              ] else
                Dimmed(
                  child: Text(
                    '\nPlease wait for {host} to resolve the situation on their end.'.trArgs({
                      'host': linkToDisplay(context.watch<Client>().host),
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
