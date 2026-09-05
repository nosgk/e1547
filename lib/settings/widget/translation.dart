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
                subtitle: Text(kTranslationLanguages[value] ?? value),
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
              builder: (context, provider, child) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (provider == TranslationProvider.openai) ...[
                    SectionHeader(
                      indent: SectionHeader.listTileIndent,
                      title: 'AI Configuration'.tr,
                    ),
                    _SettingTextField(
                      setting: context.read<Settings>().translateApiKey,
                      labelText: 'API key'.tr,
                      hintText: 'sk-…',
                    ),
                    _SettingTextField(
                      setting: context.read<Settings>().translateBaseUrl,
                      labelText: 'Base URL'.tr,
                      hintText: kDefaultOpenAiBaseUrl,
                    ),
                    const _ModelSettingTile(),
                    _SettingTextField(
                      setting: context.read<Settings>().translateSystemPrompt,
                      labelText: 'System prompt'.tr,
                      minLines: 2,
                      maxLines: 4,
                      onRestore: () =>
                          context.read<Settings>().translateSystemPrompt.value =
                              kDefaultTranslationSystemPrompt,
                    ),
                    _SettingTextField(
                      setting: context.read<Settings>().translateUserPrompt,
                      labelText: 'User prompt'.tr,
                      hintText: '@toLang, @text',
                      minLines: 4,
                      maxLines: 8,
                      onRestore: () =>
                          context.read<Settings>().translateUserPrompt.value =
                              kDefaultTranslationUserPrompt,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Text(
                        'Available variables: @toLang, @text'.tr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: dimTextColor(context),
                        ),
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
                  _AdvancedSettingTiles(provider: provider),
                  const Divider(),
                ],
              ),
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
    await showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Target language'.tr),
        children: [
          for (final entry in kTranslationLanguages.entries)
            ListTile(
              title: Text(entry.value),
              subtitle: Text(entry.key),
              trailing: entry.key == current ? const Icon(Icons.check) : null,
              onTap: () {
                settings.translateTargetLanguage.value = entry.key;
                Navigator.of(context).maybePop();
              },
            ),
        ],
      ),
    );
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

/// A text field bound to a persisted string setting.
class _SettingTextField extends StatefulWidget {
  const _SettingTextField({
    required this.setting,
    required this.labelText,
    this.hintText,
    this.minLines = 1,
    this.maxLines = 1,
    this.onRestore,
  });

  final ValueNotifier<String> setting;
  final String labelText;
  final String? hintText;
  final int minLines;
  final int maxLines;
  final VoidCallback? onRestore;

  @override
  State<_SettingTextField> createState() => _SettingTextFieldState();
}

class _SettingTextFieldState extends State<_SettingTextField> {
  late final TextEditingController controller = TextEditingController(
    text: widget.setting.value,
  );
  final FocusNode focusNode = FocusNode();
  bool focused = false;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onChanged);
    focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (controller.text != widget.setting.value) {
      widget.setting.value = controller.text;
    }
  }

  void _onFocusChanged() {
    focused = focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant _SettingTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync external changes (e.g. "restore defaults") while not editing.
    if (!focused && widget.setting.value != controller.text) {
      controller.text = widget.setting.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          border: const OutlineInputBorder(),
          suffixIcon: widget.onRestore != null
              ? IconButton(
                  tooltip: 'Restore defaults'.tr,
                  icon: const Icon(Icons.restore, size: 20),
                  onPressed: widget.onRestore,
                )
              : null,
        ),
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
        subtitle: Text(value),
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

/// Advanced per-provider URL/header/body overrides with restore buttons.
class _AdvancedSettingTiles extends StatelessWidget {
  const _AdvancedSettingTiles({required this.provider});

  final TranslationProvider provider;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<Settings>();
    final (:url, :headers, :body) = switch (provider) {
      TranslationProvider.google => (
        url: settings.translateGoogleUrl,
        headers: settings.translateGoogleHeaders,
        body: settings.translateGoogleBody,
      ),
      TranslationProvider.microsoft => (
        url: settings.translateMicrosoftUrl,
        headers: settings.translateMicrosoftHeaders,
        body: settings.translateMicrosoftBody,
      ),
      TranslationProvider.openai => (
        url: settings.translateOpenaiUrl,
        headers: settings.translateOpenaiHeaders,
        body: settings.translateOpenaiBody,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingTextField(
          setting: url,
          labelText: 'Custom URL'.tr,
          onRestore: () => url.value = '',
        ),
        _SettingTextField(
          setting: headers,
          labelText: 'Custom headers'.tr,
          hintText: '{"Header": "value"}',
          minLines: 2,
          maxLines: 4,
          onRestore: () => headers.value = '',
        ),
        _SettingTextField(
          setting: body,
          labelText: 'Custom body'.tr,
          hintText: '{"key": "@value"}',
          minLines: 2,
          maxLines: 6,
          onRestore: () => body.value = '',
        ),
      ],
    );
  }
}
