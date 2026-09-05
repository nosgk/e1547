import 'package:e1547/settings/settings.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/translate/translate.dart';
import 'package:flutter/material.dart';

/// Settings sub-page for the online translation feature.
class TranslationSettingsPage extends StatefulWidget {
  const TranslationSettingsPage({super.key});

  @override
  State<TranslationSettingsPage> createState() =>
      _TranslationSettingsPageState();
}

class _TranslationSettingsPageState extends State<TranslationSettingsPage> {
  final TextEditingController _testController = TextEditingController(
    text: 'Hello, world!',
  );

  @override
  void dispose() {
    _testController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final messenger = ScaffoldMessenger.of(context);
    final config = translationConfigFromSettings(context.read<Settings>());
    try {
      final result = await TranslationService.instance.testConnection(config);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Translation test succeeded: {result}'.trArgs({
              'result': result.length > 60
                  ? '${result.substring(0, 60)}…'
                  : result,
            }),
          ),
        ),
      );
    } on Object catch (error) {
      final message = error is TranslationException
          ? localizedTranslationError(error.message)
          : '$error';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TransparentAppBar(
        child: DefaultAppBar(
          leading: const CloseButton(),
          title: Text('Translation Settings'.tr),
        ),
      ),
      body: LimitedWidthLayout.builder(
        builder: (context) => ListView(
          primary: true,
          padding: defaultActionListPadding.add(
            LimitedWidthLayout.of(context).padding,
          ),
          children: [
            SectionHeader(
              indent: SectionHeader.listTileIndent,
              title: 'General'.tr,
            ),
            ValueListenableBuilder<bool>(
              valueListenable: context.read<Settings>().translateAuto,
              builder: (context, value, child) => SwitchListTile(
                title: Text('Automatic translation'.tr),
                subtitle: Text('Translate new content automatically'.tr),
                secondary: const Icon(Icons.auto_awesome),
                value: value,
                onChanged: (value) =>
                    context.read<Settings>().translateAuto.value = value,
              ),
            ),
            ValueListenableBuilder<String>(
              valueListenable: context.read<Settings>().translateTargetLanguage,
              builder: (context, value, child) => ListTile(
                title: Text('Target language'.tr),
                subtitle: Text(
                  availableTranslationLanguages(
                        context.read<Settings>(),
                      )[value] ??
                      value,
                ),
                leading: const Icon(Icons.translate),
                onTap: () => _pickLanguage(context, value),
              ),
            ),
            ValueListenableBuilder<TranslationProvider>(
              valueListenable: context.read<Settings>().translateProvider,
              builder: (context, value, child) => ListTile(
                title: Text('Translation service'.tr),
                subtitle: Text(value.label.tr),
                leading: const Icon(Icons.cloud_outlined),
                onTap: () => _pickProvider(context, value),
              ),
            ),
            const Divider(),
            ValueListenableBuilder<TranslationProvider>(
              valueListenable: context.read<Settings>().translateProvider,
              builder: (context, provider, child) {
                final settings = context.read<Settings>();
                final advancedDefaults = switch (provider) {
                  TranslationProvider.google => (
                    url: kGoogleUrlTemplate,
                    headers: kGoogleDefaultHeaders,
                    body: kGoogleDefaultBody,
                  ),
                  TranslationProvider.microsoft => (
                    url: kMicrosoftUrlTemplate,
                    headers: kMicrosoftDefaultHeaders,
                    body: kMicrosoftDefaultBody,
                  ),
                  TranslationProvider.openai => (
                    url: translationConfigFromSettings(settings).openaiChatUrl,
                    headers: kOpenAiDefaultHeaders,
                    body: kOpenAiBodyTemplate,
                  ),
                };
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (provider == TranslationProvider.openai) ...[
                      SectionHeader(
                        indent: SectionHeader.listTileIndent,
                        title: 'AI Configuration'.tr,
                      ),
                      _SettingTextField(
                        setting: settings.translateApiKey,
                        label: 'API key'.tr,
                        hintText: 'sk-…',
                      ),
                      _SettingTextField(
                        setting: settings.translateBaseUrl,
                        label: 'Base URL'.tr,
                        defaultValue: kDefaultOpenAiBaseUrl,
                      ),
                      const _ModelSettingTile(),
                      _SettingTextField(
                        setting: settings.translateSystemPrompt,
                        label: 'System prompt'.tr,
                        defaultValue: kDefaultTranslationSystemPrompt,
                        minLines: 2,
                        maxLines: 4,
                      ),
                      _SettingTextField(
                        setting: settings.translateUserPrompt,
                        label: 'User prompt'.tr,
                        defaultValue: kDefaultTranslationUserPrompt,
                        minLines: 4,
                        maxLines: 8,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Text(
                          'Available variables: @toLang, @text'.tr,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: dimTextColor(context)),
                        ),
                      ),
                      const Divider(),
                    ],
                    SectionHeader(
                      indent: SectionHeader.listTileIndent,
                      title: 'Advanced customization'.tr,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Text(
                        'Applies to the current service'.tr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: dimTextColor(context),
                        ),
                      ),
                    ),
                    _SettingTextField(
                      setting: switch (provider) {
                        TranslationProvider.google =>
                          settings.translateGoogleUrl,
                        TranslationProvider.microsoft =>
                          settings.translateMicrosoftUrl,
                        TranslationProvider.openai =>
                          settings.translateOpenaiUrl,
                      },
                      label: 'Custom URL'.tr,
                      defaultValue: advancedDefaults.url,
                      maxLines: 3,
                    ),
                    _SettingTextField(
                      setting: switch (provider) {
                        TranslationProvider.google =>
                          settings.translateGoogleHeaders,
                        TranslationProvider.microsoft =>
                          settings.translateMicrosoftHeaders,
                        TranslationProvider.openai =>
                          settings.translateOpenaiHeaders,
                      },
                      label: 'Custom headers'.tr,
                      defaultValue: advancedDefaults.headers,
                      minLines: 2,
                      maxLines: 4,
                    ),
                    _SettingTextField(
                      setting: switch (provider) {
                        TranslationProvider.google =>
                          settings.translateGoogleBody,
                        TranslationProvider.microsoft =>
                          settings.translateMicrosoftBody,
                        TranslationProvider.openai =>
                          settings.translateOpenaiBody,
                      },
                      label: 'Custom body'.tr,
                      defaultValue: advancedDefaults.body,
                      minLines: 2,
                      maxLines: 6,
                    ),
                    const Divider(),
                  ],
                );
              },
            ),
            SectionHeader(
              indent: SectionHeader.listTileIndent,
              title: 'Test connection'.tr,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _testController,
                decoration: InputDecoration(
                  labelText: 'Text to translate'.tr,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _testConnection,
                  icon: const Icon(Icons.wifi_tethering, size: 18),
                  label: Text('Test connection'.tr),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLanguage(BuildContext context, String current) async {
    final settings = context.read<Settings>();
    final languages = availableTranslationLanguages(settings);
    final custom = parseCustomLanguages(
      settings.translateCustomLanguages.value,
    );
    await showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Target language'.tr),
        children: [
          for (final entry in languages.entries)
            if (!custom.any((c) => c.key == entry.key))
              ListTile(
                title: Text(entry.value),
                subtitle: Text(entry.key),
                trailing: entry.key == current ? const Icon(Icons.check) : null,
                onTap: () {
                  settings.translateTargetLanguage.value = entry.key;
                  Navigator.of(context).maybePop();
                },
              ),
          for (final entry in custom)
            ListTile(
              title: Text(entry.value),
              subtitle: Text(entry.key),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (entry.key == current) const Icon(Icons.check),
                  IconButton(
                    tooltip: 'Delete'.tr,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () {
                      final remaining = custom
                          .where((c) => c.key != entry.key)
                          .toList();
                      settings.translateCustomLanguages.value =
                          encodeCustomLanguages(remaining);
                      if (settings.translateTargetLanguage.value == entry.key) {
                        settings.translateTargetLanguage.value = 'zh-CN';
                      }
                    },
                  ),
                ],
              ),
              onTap: () {
                settings.translateTargetLanguage.value = entry.key;
                Navigator.of(context).maybePop();
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add),
            title: Text('Add custom language'.tr),
            onTap: () {
              Navigator.of(context).maybePop();
              _addCustomLanguage(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addCustomLanguage(BuildContext context) async {
    final settings = context.read<Settings>();
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add custom language'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Language code'.tr,
                hintText: 'pt-BR',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Display name'.tr,
                hintText: 'Português (Brasil)',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text('CANCEL'.tr),
          ),
          TextButton(
            onPressed: () {
              final code = codeController.text.trim();
              if (code.isEmpty) return;
              final name = nameController.text.trim();
              final custom = parseCustomLanguages(
                settings.translateCustomLanguages.value,
              );
              if (custom.any((c) => c.key == code)) {
                Navigator.of(context).maybePop();
                return;
              }
              custom.add(MapEntry(code, name.isEmpty ? code : name));
              settings.translateCustomLanguages.value = encodeCustomLanguages(
                custom,
              );
              settings.translateTargetLanguage.value = code;
              Navigator.of(context).maybePop();
            },
            child: Text('Add'.tr),
          ),
        ],
      ),
    );
    codeController.dispose();
    nameController.dispose();
  }

  Future<void> _pickProvider(
    BuildContext context,
    TranslationProvider current,
  ) async {
    final settings = context.read<Settings>();
    await showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Translation service'.tr),
        children: [
          for (final provider in TranslationProvider.values)
            ListTile(
              title: Text(provider.label.tr),
              trailing: provider == current ? const Icon(Icons.check) : null,
              onTap: () {
                settings.translateProvider.value = provider;
                Navigator.of(context).maybePop();
              },
            ),
        ],
      ),
    );
  }
}

/// A titled text field bound to a persisted string setting.
///
/// The label renders as a small heading above the field. While the setting
/// is empty, [defaultValue] is shown pre-filled; editing stores the typed
/// text, and the restore button returns to the default.
class _SettingTextField extends StatefulWidget {
  const _SettingTextField({
    required this.setting,
    required this.label,
    this.defaultValue,
    this.hintText,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final ValueNotifier<String> setting;
  final String label;
  final String? defaultValue;
  final String? hintText;
  final int minLines;
  final int maxLines;

  @override
  State<_SettingTextField> createState() => _SettingTextFieldState();
}

class _SettingTextFieldState extends State<_SettingTextField> {
  late final TextEditingController controller;
  final FocusNode focusNode = FocusNode();
  bool syncing = false;

  String _effective(String value) =>
      value.trim().isEmpty ? (widget.defaultValue ?? '') : value;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: _effective(widget.setting.value));
    widget.setting.addListener(_onSettingChanged);
    controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.setting.removeListener(_onSettingChanged);
    controller.removeListener(_onControllerChanged);
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (syncing) return;
    syncing = true;
    widget.setting.value = controller.text;
    syncing = false;
  }

  void _onSettingChanged() {
    if (syncing) return;
    final target = _effective(widget.setting.value);
    if (target != controller.text) {
      syncing = true;
      controller.text = target;
      syncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRestore =
        widget.defaultValue != null && widget.setting.value.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Text(
              widget.label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TextField(
            controller: controller,
            focusNode: focusNode,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            decoration: InputDecoration(
              hintText: widget.hintText,
              border: const OutlineInputBorder(),
              suffixIcon: canRestore
                  ? IconButton(
                      tooltip: 'Restore defaults'.tr,
                      icon: const Icon(Icons.restore, size: 20),
                      onPressed: () => widget.setting.value = '',
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tile that shows and picks the AI translation model.
class _ModelSettingTile extends StatelessWidget {
  const _ModelSettingTile();

  @override
  Widget build(BuildContext context) {
    final settings = context.read<Settings>();
    return ValueListenableBuilder<String>(
      valueListenable: settings.translateModel,
      builder: (context, value, child) => ListTile(
        title: Text('Model'.tr),
        subtitle: Text(value.trim().isEmpty ? kDefaultOpenAiModel : value),
        leading: const Icon(Icons.smart_toy_outlined),
        trailing: IconButton(
          tooltip: 'Fetch models'.tr,
          icon: const Icon(Icons.refresh),
          onPressed: () => _pickModel(context),
        ),
        onTap: () => _pickModel(context),
      ),
    );
  }

  Future<void> _pickModel(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final config = translationConfigFromSettings(context.read<Settings>());
    try {
      final models = await TranslationService.instance.fetchModels(config);
      if (!context.mounted) return;
      await _showModelDialog(context, models);
    } on Object catch (error) {
      final message = error is TranslationException
          ? localizedTranslationError(error.message)
          : '$error';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _showModelDialog(
    BuildContext context,
    List<String> models,
  ) async {
    final settings = context.read<Settings>();
    await showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Model'.tr),
        children: [
          for (final model in models)
            ListTile(
              title: Text(model),
              trailing: model == settings.translateModel.value
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                settings.translateModel.value = model;
                Navigator.of(context).maybePop();
              },
            ),
        ],
      ),
    );
  }
}
