import 'dart:async';
import 'dart:io';

import 'package:e1547/app/app.dart';
import 'package:e1547/app/widget/initialize.dart';
import 'package:e1547/client/client.dart';
import 'package:e1547/follow/follow.dart';
import 'package:e1547/identity/identity.dart';
import 'package:e1547/logs/logs.dart';
import 'package:e1547/settings/settings.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/translate/translate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sub/flutter_sub.dart';
import 'package:local_auth/local_auth.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<Settings>(
      builder: (context, settings, child) => Scaffold(
        appBar: DefaultAppBar(title: Text('Settings'.tr)),
        body: LimitedWidthLayout.builder(
          builder: (context) => ListView(
            primary: true,
            padding: defaultActionListPadding.add(
              LimitedWidthLayout.of(context).padding,
            ),
            children: [
              SectionHeader(
                indent: SectionHeader.listTileIndent,
                title: 'Account'.tr,
              ),
              Consumer<IdentityClient>(
                builder: (context, client, child) => IdentityTile(
                  identity: client.identity,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const IdentitiesPage(),
                    ),
                  ),
                  trailing: const Icon(Icons.swap_horiz),
                ),
              ),
              const Divider(),
              const SectionHeader(
                indent: SectionHeader.listTileIndent,
                title: 'User',
              ),
              Consumer<Client>(
                builder: (context, client, child) => ValueListenableBuilder(
                  valueListenable: client.traits,
                  builder: (context, traits, child) => ListTile(
                    title: Text('Blacklist'.tr),
                    leading: const Icon(Icons.block),
                    subtitle: traits.denylist.isNotEmpty
                        ? Text(
                            '{count} tags blocked'.trArgs({
                              'count': traits.denylist
                                  .join(' ')
                                  .split(' ')
                                  .trim()
                                  .where((e) => e[0] != '-')
                                  .length,
                            }),
                          )
                        : null,
                    onTap: () => Navigator.pushNamed(context, '/blacklist'),
                  ),
                ),
              ),
              Consumer<Client>(
                builder: (context, client, child) => SubStream<int>(
                  create: () => client.follows.count().streamed,
                  keys: [client],
                  builder: (context, snapshot) => ListTile(
                    title: Text('Follows'.tr),
                    subtitle: snapshot.data != null && snapshot.data != 0
                        ? Text(
                            '{count} searches followed'.trArgs({
                              'count': snapshot.data.toString(),
                            }),
                          )
                        : null,
                    leading: const Icon(Icons.person_add),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FollowEditor(),
                      ),
                    ),
                  ),
                ),
              ),
              Consumer<Client>(
                builder: (context, client, child) => SubStream<int>(
                  create: () => client.histories.count().streamed,
                  keys: [client],
                  builder: (context, countSnapshot) {
                    int? count = countSnapshot.data;
                    return ValueListenableBuilder(
                      valueListenable: client.traits,
                      builder: (context, traits, child) {
                        bool enabled = traits.writeHistory ?? true;
                        return DividerListTile(
                          title: Text('History'.tr),
                          subtitle: enabled && count != null
                              ? Text(
                                  '{count} pages visited'.trArgs({
                                    'count': count.toString(),
                                  }),
                                )
                              : null,
                          leading: const Icon(Icons.history),
                          onTap: () => Navigator.pushNamed(context, '/history'),
                          onTapSeparated: () => client.traits.value = client
                              .traits
                              .value
                              .copyWith(writeHistory: !enabled),
                          separated: Switch(
                            value: enabled,
                            onChanged: (value) => client.traits.value = client
                                .traits
                                .value
                                .copyWith(writeHistory: value),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(),
              const SectionHeader(
                indent: SectionHeader.listTileIndent,
                title: 'Appearance',
              ),
              ValueListenableBuilder<AppTheme>(
                valueListenable: settings.theme,
                builder: (context, value, child) => ListTile(
                  title: Text('Theme'.tr),
                  subtitle: Text(value.title),
                  leading: const Icon(Icons.brightness_6),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: Text('Theme'.tr),
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: AppTheme.values
                                .map(
                                  (theme) => ListTile(
                                    title: Text(theme.title),
                                    trailing: Container(
                                      height: 28,
                                      width: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: theme.data.cardColor,
                                        border: Border.all(
                                          color: Theme.of(
                                            context,
                                          ).iconTheme.color!,
                                        ),
                                      ),
                                    ),
                                    onTap: () {
                                      settings.theme.value = theme;
                                      Navigator.of(context).maybePop();
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              ValueListenableBuilder<bool?>(
                valueListenable: settings.language,
                builder: (context, value, child) => ListTile(
                  title: Text('Language'.tr),
                  subtitle: Text(switch (value) {
                    null => 'follow system'.tr,
                    true => '中文',
                    false => 'English',
                  }),
                  leading: const Icon(Icons.language),
                  onTap: () => showDialog(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: Text('Language'.tr),
                      children: [
                        ListTile(
                          title: Text('follow system'.tr),
                          trailing: value == null
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () {
                            settings.language.value = null;
                            I18n.instance.load();
                            AppInit.of(context).reinitialize();
                            Navigator.of(context).maybePop();
                          },
                        ),
                        ListTile(
                          title: const Text('中文'),
                          trailing: value == true
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () {
                            settings.language.value = true;
                            I18n.instance.setEnabled(true);
                            AppInit.of(context).reinitialize();
                            Navigator.of(context).maybePop();
                          },
                        ),
                        ListTile(
                          title: const Text('English'),
                          trailing: value == false
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () {
                            settings.language.value = false;
                            I18n.instance.setEnabled(false);
                            AppInit.of(context).reinitialize();
                            Navigator.of(context).maybePop();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: settings.tileSize,
                    builder: (context, value, child) => ListTile(
                      title: Text('Tile size'.tr),
                      subtitle: Text(value.toString()),
                      leading: const Icon(Icons.crop),
                      onTap: () => showDialog(
                        context: context,
                        builder: (context) => RangeDialog(
                          title: Text('Tile size'.tr),
                          value: NumberRange(value),
                          initialMode: RangeDialogMode.exact,
                          enforceMax: false,
                          canChangeMode: false,
                          division: (300 / 50).round(),
                          min: 100,
                          max: 400,
                          onSubmit: (value) {
                            if (value == null || value.value <= 0) {
                              return;
                            }
                            settings.tileSize.value = value.value;
                          },
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<GridQuilt>(
                    valueListenable: settings.quilt,
                    builder: (context, value, child) => GridSettingsTile(
                      state: value,
                      onChange: (value) => settings.quilt.value = value,
                    ),
                  ),
                ],
              ),
              ValueListenableBuilder<bool>(
                valueListenable: settings.showPostInfo,
                builder: (context, value, child) => SwitchListTile(
                  title: Text('Post info'.tr),
                  subtitle: Text(
                    value ? 'info on post tiles'.tr : 'image tiles only'.tr,
                  ),
                  secondary: const Icon(Icons.subtitles),
                  value: value,
                  onChanged: (value) => settings.showPostInfo.value = value,
                ),
              ),
              const Divider(),
              SectionHeader(
                indent: SectionHeader.listTileIndent,
                title: 'Interactions'.tr,
              ),
              if (!Platform.isIOS)
                ValueListenableBuilder<String?>(
                  valueListenable: settings.downloadPath,
                  builder: (context, value, child) => ListTile(
                    title: Text('Download location'.tr),
                    subtitle: value != null
                        ? Text(Uri.decodeComponent(Uri.parse(value).path))
                        : null,
                    leading: const Icon(Icons.folder),
                    onTap: () async {
                      String? result = await FileDownloader.pickDirectory(
                        initial: value,
                      );
                      if (result != null) {
                        unawaited(FileDownloader.forgetDirectory(value));
                        settings.downloadPath.value = result;
                      }
                    },
                  ),
                ),
              ValueListenableBuilder<bool>(
                valueListenable: settings.upvoteFavs,
                builder: (context, value, child) => SwitchListTile(
                  title: Text('Upvote favorites'.tr),
                  subtitle: Text(
                    value ? 'upvote and favorite'.tr : 'favorite only'.tr,
                  ),
                  secondary: const Icon(Icons.arrow_upward),
                  value: value,
                  onChanged: (value) => settings.upvoteFavs.value = value,
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: settings.muteVideos,
                builder: (context, value, child) => SwitchListTile(
                  title: Text('Video volume'.tr),
                  subtitle: Text(value ? 'muted'.tr : 'with sound'.tr),
                  secondary: Icon(value ? Icons.volume_off : Icons.volume_up),
                  value: value,
                  onChanged: (value) => settings.muteVideos.value = value,
                ),
              ),
              ValueListenableBuilder<VideoResolution>(
                valueListenable: settings.videoResolution,
                builder: (context, value, child) => ListTile(
                  title: Text('Video resolution'.tr),
                  subtitle: Text(value.title),
                  leading: const Icon(Icons.video_settings),
                  onTap: () => showDialog(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: Text('Video resolution'.tr),
                      children: VideoResolution.values
                          .map(
                            (resolution) => ListTile(
                              title: Text(resolution.title),
                              onTap: () {
                                settings.videoResolution.value = resolution;
                                Navigator.of(context).maybePop();
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
              const Divider(),
              SectionHeader(
                indent: SectionHeader.listTileIndent,
                title: 'Translation'.tr,
              ),
              ValueListenableBuilder<bool>(
                valueListenable: settings.translateEnabled,
                builder: (context, value, child) => SwitchListTile(
                  title: Text('Online translation'.tr),
                  subtitle: Text('Translate posts and comments'.tr),
                  secondary: const Icon(Icons.translate),
                  value: value,
                  onChanged: (value) => settings.translateEnabled.value = value,
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: settings.translateEnabled,
                builder: (context, value, child) => ListTile(
                  title: Text('Translation Settings'.tr),
                  subtitle: Text(
                    '${settings.translateProvider.value.label.tr}'
                    ' · '
                    '${kTranslationLanguages[settings.translateTargetLanguage.value] ?? settings.translateTargetLanguage.value}',
                  ),
                  leading: const Icon(Icons.settings_suggest),
                  enabled: value,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const TranslationSettingsPage(),
                    ),
                  ),
                ),
              ),
              const Divider(),
              SectionHeader(
                indent: SectionHeader.listTileIndent,
                title: 'Security'.tr,
              ),
              if (PlatformCapabilities.hasSecureDisplay)
                ValueListenableBuilder<bool>(
                  valueListenable: settings.secureDisplay,
                  builder: (context, value, child) => SwitchListTile(
                    title: Text('Secure display'.tr),
                    subtitle: Text(
                      value ? 'screen protected'.tr : 'screen visible'.tr,
                    ),
                    secondary: const Icon(Icons.stop_screen_share_outlined),
                    value: value,
                    onChanged: (value) => settings.secureDisplay.value = value,
                  ),
                ),
              if (Platform.isAndroid)
                ValueListenableBuilder<bool>(
                  valueListenable: settings.incognitoKeyboard,
                  builder: (context, value, child) => SwitchListTile(
                    title: Text('Incognito keyboard'.tr),
                    subtitle: Text(value ? 'enabled'.tr : 'disabled'.tr),
                    secondary: const Icon(Icons.keyboard),
                    value: value,
                    onChanged: (value) =>
                        settings.incognitoKeyboard.value = value,
                  ),
                ),
              ValueListenableBuilder<String?>(
                valueListenable: settings.appPin,
                builder: (context, value, child) => SwitchListTile(
                  title: Text('PIN lock'.tr),
                  subtitle: Text(
                    value != null ? 'PIN enabled'.tr : 'PIN disabled'.tr,
                  ),
                  secondary: const Icon(Icons.pin),
                  value: value != null,
                  onChanged: (value) async {
                    if (value) {
                      String? pin = await registerPin(context);
                      if (pin != null) {
                        settings.appPin.value = pin;
                      }
                    } else {
                      settings.appPin.value = null;
                    }
                  },
                ),
              ),
              SubFuture<bool>(
                create: () => LocalAuthentication()
                    .getAvailableBiometrics()
                    .then((e) => e.isNotEmpty),
                builder: (context, snapshot) => ValueListenableBuilder<bool>(
                  valueListenable: settings.biometricAuth,
                  builder: (context, value, child) => SwitchListTile(
                    title: Text('Biometric lock'.tr),
                    subtitle: Text(
                      value
                          ? 'biometrics enabled'.tr
                          : 'biometrics disabled'.tr,
                    ),
                    secondary: const Icon(Icons.fingerprint),
                    value: value,
                    onChanged: (snapshot.data ?? false)
                        ? (value) => settings.biometricAuth.value = value
                        : null,
                  ),
                ),
              ),
              const Divider(),
              SectionHeader(
                indent: SectionHeader.listTileIndent,
                title: 'Development'.tr,
              ),
              ValueListenableBuilder<bool>(
                valueListenable: settings.showDev,
                builder: (context, value, child) {
                  if (!value) return const SizedBox();
                  return SwitchListTile(
                    title: Text('Developer mode'.tr),
                    subtitle: Text(
                      value ? 'options shown'.tr : 'options hidden'.tr,
                    ),
                    secondary: const Icon(Icons.bug_report),
                    value: value,
                    onChanged: (value) => settings.showDev.value = value,
                  );
                },
              ),
              if (context.watch<Logs?>() != null) ...[
                Consumer<LogErrors>(
                  builder: (context, errors, child) => ListTile(
                    leading: const Icon(Icons.format_list_numbered),
                    title: Text('Logs'.tr),
                    subtitle: errors.isEmpty
                        ? null
                        : Text(
                            '{count} errors logged'.trArgs({
                              'count': errors.length,
                            }),
                          ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const LogsPage()),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: Text('Database'.tr),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const DatabaseManagementPage(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
