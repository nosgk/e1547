import 'dart:convert';

import 'package:e1547/settings/settings.dart';
import 'package:e1547/shared/shared.dart';
import 'package:e1547/translate/translate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full request configurator ("lightweight Postman") for one translation
/// provider: method, URL, query, headers, body, response parsing rule,
/// live request preview and a diagnostic test panel. Every edit persists
/// immediately and takes effect at once.
class AdvancedRequestSettingsPage extends StatefulWidget {
  const AdvancedRequestSettingsPage({super.key, required this.provider});

  final TranslationProvider provider;

  @override
  State<AdvancedRequestSettingsPage> createState() =>
      _AdvancedRequestSettingsPageState();
}

class _AdvancedRequestSettingsPageState
    extends State<AdvancedRequestSettingsPage> {
  static const List<String> _contentTypes = [
    'application/json',
    'application/json+protobuf',
    'application/x-www-form-urlencoded',
    'text/plain',
  ];
  static const String _sampleText = 'Hello, world!';

  late TranslationRequestProfile _profile;
  late final TextEditingController _url;
  late final TextEditingController _body;
  late final TextEditingController _parse;
  final TextEditingController _testText = TextEditingController(
    text: _sampleText,
  );
  TextEditingController? _lastFocused;

  bool _testing = false;
  TranslationProbe? _probe;

  @override
  void initState() {
    super.initState();
    _profile = profileFromSettings(context.read<Settings>(), widget.provider);
    _url = TextEditingController(text: _profile.url);
    _body = TextEditingController(text: _profile.body);
    _parse = TextEditingController(text: _profile.parsePath);
  }

  @override
  void dispose() {
    _url.dispose();
    _body.dispose();
    _parse.dispose();
    _testText.dispose();
    super.dispose();
  }

  // --- profile plumbing ------------------------------------------------------

  void _update(TranslationRequestProfile profile) {
    setState(() => _profile = profile);
    _persist(profile);
  }

  void _persist(TranslationRequestProfile profile) {
    final settings = context.read<Settings>();
    final encoded = profile.encode();
    switch (widget.provider) {
      case TranslationProvider.google:
        settings.translateProfileGoogle.value = encoded;
      case TranslationProvider.googleChrome:
        settings.translateProfileGoogleChrome.value = encoded;
      case TranslationProvider.microsoft:
        settings.translateProfileMicrosoft.value = encoded;
      case TranslationProvider.azure:
        settings.translateProfileAzure.value = encoded;
      case TranslationProvider.openai:
        settings.translateProfileOpenai.value = encoded;
    }
  }

  void _restorePreset() {
    final settings = context.read<Settings>();
    switch (widget.provider) {
      case TranslationProvider.google:
        settings.translateProfileGoogle.value = '';
      case TranslationProvider.googleChrome:
        settings.translateProfileGoogleChrome.value = '';
      case TranslationProvider.microsoft:
        settings.translateProfileMicrosoft.value = '';
      case TranslationProvider.azure:
        settings.translateProfileAzure.value = '';
      case TranslationProvider.openai:
        settings.translateProfileOpenai.value = '';
    }
    final preset = defaultRequestProfile(widget.provider);
    setState(() {
      _profile = preset;
      _url.text = preset.url;
      _body.text = preset.body;
      _parse.text = preset.parsePath;
    });
  }

  TranslationConfig _buildConfig() {
    final settings = context.read<Settings>();
    return TranslationConfig(
      provider: widget.provider,
      targetLanguage: settings.translateTargetLanguage.value,
      apiKey: settings.translateApiKey.value,
      baseUrl: settings.translateBaseUrl.value,
      model: settings.translateModel.value,
      systemPrompt: settings.translateSystemPrompt.value,
      userPrompt: settings.translateUserPrompt.value,
      azureApiKey: settings.translateAzureKey.value,
      profile: _profile,
    );
  }

  /// Opens a plain-text (JSON) editor for the whole request profile.
  /// Saving parses the text back into a profile and applies it.
  Future<void> _editAsText() async {
    final initial = const JsonEncoder.withIndent(
      '  ',
    ).convert(_profile.toJson());
    final controller = TextEditingController(text: initial);
    final result = await showDialog<TranslationRequestProfile>(
      context: context,
      builder: (context) => _PlainTextProfileDialog(controller: controller),
    );
    controller.dispose();
    if (result == null) return;
    _url.text = result.url;
    _body.text = result.body;
    _parse.text = result.parsePath;
    _update(result);
  }

  TextEditingController? get focusedController => _lastFocused;

  set focusedController(TextEditingController controller) {
    _lastFocused = controller;
  }

  void _insertVariable(String name) {
    final controller = _lastFocused;
    if (controller == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text('Tap a text field first'.tr),
        ),
      );
      return;
    }
    final token = '@$name';
    final value = controller.value;
    var start = value.selection.start;
    var end = value.selection.end;
    if (start < 0 || end < 0) {
      start = end = value.text.length;
    }
    if (end < start) {
      final swap = start;
      start = end;
      end = swap;
    }
    final newText = value.text.replaceRange(start, end, token);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  // --- test ------------------------------------------------------------------

  Future<void> _runTest() async {
    if (_testing) return;
    setState(() => _testing = true);
    final probe = await TranslationService.instance.probe(
      _buildConfig(),
      _testText.text.trim().isEmpty ? _sampleText : _testText.text,
    );
    if (!mounted) return;
    setState(() {
      _probe = probe;
      _testing = false;
    });
  }

  // --- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TransparentAppBar(
        child: DefaultAppBar(
          leading: const CloseButton(),
          title: Text('API Request Configuration'.tr),
          actions: [
            IconButton(
              tooltip: 'Edit as plain text'.tr,
              icon: const Icon(Icons.data_object),
              onPressed: _editAsText,
            ),
            IconButton(
              tooltip: 'Restore defaults'.tr,
              icon: const Icon(Icons.restore),
              onPressed: _restorePreset,
            ),
          ],
        ),
      ),
      body: LimitedWidthLayout.builder(
        builder: (context) => ListView(
          primary: true,
          padding: defaultActionListPadding.add(
            LimitedWidthLayout.of(context).padding,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Sent exactly as configured — no hidden headers or '
                        'transformations'
                    .tr,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: dimTextColor(context)),
              ),
            ),
            _sectionHeader('Performance & Rate Limiting'.tr),
            NumberSettingTile(
              label: 'Max concurrent requests'.tr,
              value: context.read<Settings>().translateConcurrency.value,
              onChanged: (value) =>
                  context.read<Settings>().translateConcurrency.value = value,
            ),
            NumberSettingTile(
              label: 'Request interval (ms)'.tr,
              value: context.read<Settings>().translateIntervalMs.value,
              onChanged: (value) =>
                  context.read<Settings>().translateIntervalMs.value = value,
            ),
            NumberSettingTile(
              label: 'Request timeout (s)'.tr,
              value: context.read<Settings>().translateTimeoutSeconds.value,
              onChanged: (value) =>
                  context.read<Settings>().translateTimeoutSeconds.value =
                      value,
            ),
            NumberSettingTile(
              label: 'Retry count'.tr,
              subtitle:
                  'Automatic retries after failures '
                  '(timeout, empty response, API errors)'.tr,
              value: context.read<Settings>().translateRetryCount.value,
              onChanged: (value) =>
                  context.read<Settings>().translateRetryCount.value = value,
            ),
            NumberSettingTile(
              label: 'Max text length per request'.tr,
              subtitle: 'Characters sent in one request; 0 = unlimited'.tr,
              value: context.read<Settings>().translateMaxTextLength.value,
              onChanged: (value) =>
                  context.read<Settings>().translateMaxTextLength.value = value,
            ),
            NumberSettingTile(
              label: 'Max paragraphs per request'.tr,
              subtitle:
                  'Newline-separated paragraphs per request; 0 = unlimited'.tr,
              value: context.read<Settings>().translateMaxParagraphs.value,
              onChanged: (value) =>
                  context.read<Settings>().translateMaxParagraphs.value = value,
            ),
            const Divider(),
            _sectionHeader('Request'.tr),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: DropdownButtonFormField<String>(
                      initialValue: _profile.isGet ? 'GET' : 'POST',
                      decoration: InputDecoration(
                        labelText: 'Method'.tr,
                        border: const OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'GET', child: Text('GET')),
                        DropdownMenuItem(value: 'POST', child: Text('POST')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        _update(_profile.copyWith(method: value));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _url,
                      onTap: () => focusedController = _url,
                      onChanged: (_) =>
                          _update(_profile.copyWith(url: _url.text)),
                      minLines: 1,
                      maxLines: 3,
                      style: _monoStyle(context),
                      decoration: InputDecoration(
                        labelText: 'URL'.tr,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _KvEditor(
              title: 'Query parameters'.tr,
              initialRows: _profile.query,
              onChanged: (rows) => _update(_profile.copyWith(query: rows)),
              onControllerFocused: (controller) =>
                  focusedController = controller,
            ),
            _KvEditor(
              title: 'Headers'.tr,
              initialRows: _profile.headers,
              onChanged: (rows) => _update(_profile.copyWith(headers: rows)),
              onControllerFocused: (controller) =>
                  focusedController = controller,
            ),
            AnimatedSize(
              duration: defaultAnimationDuration,
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: _profile.isGet
                  ? const SizedBox(width: double.infinity)
                  : _buildBodySection(context),
            ),
            _sectionHeader('Response parsing'.tr),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _parse,
                    onTap: () => focusedController = _parse,
                    onChanged: (_) =>
                        _update(_profile.copyWith(parsePath: _parse.text)),
                    style: _monoStyle(context),
                    decoration: InputDecoration(
                      labelText: 'Parse rule'.tr,
                      hintText: r'$.data.translations[0].text',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      '[n] index, [*] join all elements, .key object member; '
                              'empty = raw response as result'
                          .tr,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: dimTextColor(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildVariablesTile(context),
            const Divider(),
            _sectionHeader('Request preview'.tr),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Preview uses the sample text and the current target language'
                    .tr,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: dimTextColor(context)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _CodeBox(child: SelectableText(_buildPreviewText())),
            ),
            const Divider(),
            _sectionHeader('Test request'.tr),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _testText,
                      decoration: InputDecoration(
                        labelText: 'Text to translate'.tr,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: FilledButton.icon(
                      onPressed: _testing ? null : _runTest,
                      icon: _testing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow, size: 18),
                      label: Text('Send'.tr),
                    ),
                  ),
                ],
              ),
            ),
            if (_probe != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ProbeCard(probe: _probe!),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) =>
      SectionHeader(indent: SectionHeader.listTileIndent, title: title);

  TextStyle _monoStyle(BuildContext context) => Theme.of(
    context,
  ).textTheme.bodyMedium!.copyWith(fontFamily: 'monospace', fontSize: 13);

  Widget _buildBodySection(BuildContext context) {
    final contentType = _profile.contentType;
    final isJson = contentType.contains('json');
    final lint = isJson ? validateJsonBody(_profile.body) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Request body'.tr),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButtonFormField<String>(
            initialValue: contentType.isEmpty ? null : contentType,
            hint: const Text('application/json'),
            decoration: InputDecoration(
              labelText: 'Content-Type'.tr,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final type in _contentTypes)
                DropdownMenuItem(value: type, child: Text(type)),
            ],
            onChanged: (value) {
              if (value == null) return;
              _update(_profile.copyWith(contentType: value));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _body,
            onTap: () => focusedController = _body,
            onChanged: (_) => _update(_profile.copyWith(body: _body.text)),
            minLines: 5,
            maxLines: 12,
            style: _monoStyle(context),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        if (isJson)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(
                  lint == null ? Icons.check_circle : Icons.error_outline,
                  size: 16,
                  color: lint == null
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    lint ?? 'JSON valid'.tr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: lint == null
                          ? dimTextColor(context)
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                if (lint == null && _profile.body.trim().isNotEmpty)
                  TextButton(
                    onPressed: () {
                      final formatted = formatJsonBody(_profile.body);
                      _body.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                      _update(_profile.copyWith(body: formatted));
                    },
                    child: Text('Format'.tr),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildVariablesTile(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text('Variables reference'.tr),
      subtitle: Text('Tap to insert into the focused field'.tr),
      children: [
        for (final variable in kTranslationVariables)
          ListTile(
            dense: true,
            onTap: () => _insertVariable(variable.name),
            title: Text(
              '@${variable.name}',
              style: _monoStyle(
                context,
              ).copyWith(color: Theme.of(context).colorScheme.primary),
            ),
            subtitle: Text(
              variable.description.tr,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: dimTextColor(context)),
            ),
            trailing: const Icon(Icons.keyboard_tab, size: 16),
          ),
      ],
    );
  }

  String _buildPreviewText() {
    final vars = translationTemplateVars(_buildConfig(), _sampleText);
    final method = _profile.method.toUpperCase();
    final url = buildRequestUrl(_profile, vars);
    final headers = <String, String>{
      for (final entry in _profile.headers)
        if (entry.key.trim().isNotEmpty)
          entry.key.trim(): renderPlainTemplate(entry.value, vars),
    };
    final contentType = _profile.effectiveContentType();
    if (contentType != null) headers['Content-Type'] = contentType;
    final body = _profile.isGet
        ? null
        : renderJsonTemplate(_profile.body, vars);
    return [
      '$method $url',
      for (final entry in headers.entries) '${entry.key}: ${entry.value}',
      if (body != null) ...['', body],
    ].join('\n');
  }
}

// ---------------------------------------------------------------------------
// Building blocks
// ---------------------------------------------------------------------------

/// Dark code panel used for the request preview.
class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
        child: child,
      ),
    );
  }
}

/// Compact numeric setting row: label on the left, small field on the
/// right. Shared by the request configurator and the translation settings
/// cache section.
class NumberSettingTile extends StatefulWidget {
  const NumberSettingTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<NumberSettingTile> createState() => _NumberSettingTileState();
}

class _NumberSettingTileState extends State<NumberSettingTile> {
  late final TextEditingController controller = TextEditingController(
    text: '${widget.value}',
  );

  @override
  void didUpdateWidget(covariant NumberSettingTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final parsed = int.tryParse(controller.text);
    if (parsed == null || parsed != widget.value) {
      controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.label),
      subtitle: widget.subtitle == null
          ? null
          : Text(
              widget.subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: dimTextColor(context)),
            ),
      trailing: SizedBox(
        width: 110,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.end,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (text) =>
              widget.onChanged(int.tryParse(text) ?? (text.isEmpty ? 0 : 1)),
        ),
      ),
    );
  }
}

/// One editable key/value row of the [._KvEditor].
class _KvRow {
  _KvRow(String key, String value)
    : key = TextEditingController(text: key),
      value = TextEditingController(text: value);

  final TextEditingController key;
  final TextEditingController value;

  void dispose() {
    key.dispose();
    value.dispose();
  }
}

/// Ordered key/value table editor for query parameters and headers. Rows
/// persist immediately through [onChanged]; the add button appends an empty
/// row, the trash icon removes one.
class _KvEditor extends StatefulWidget {
  const _KvEditor({
    required this.title,
    required this.initialRows,
    required this.onChanged,
    required this.onControllerFocused,
  });

  final String title;
  final List<MapEntry<String, String>> initialRows;
  final ValueChanged<List<MapEntry<String, String>>> onChanged;
  final void Function(TextEditingController controller) onControllerFocused;

  @override
  State<_KvEditor> createState() => _KvEditorState();
}

class _KvEditorState extends State<_KvEditor> {
  late List<_KvRow> _rows = [
    for (final entry in widget.initialRows) _KvRow(entry.key, entry.value),
  ];
  bool _emitting = false;

  @override
  void didUpdateWidget(covariant _KvEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_emitting) return;
    // External change (e.g. preset restored): reload when it differs from
    // what this editor last emitted.
    final differs =
        widget.initialRows.length != _rows.length ||
        List.generate(
          _rows.length,
          (index) =>
              widget.initialRows[index].key != _rows[index].key.text ||
              widget.initialRows[index].value != _rows[index].value.text,
        ).any((changed) => changed);
    if (!differs) return;
    for (final row in _rows) {
      row.dispose();
    }
    _rows = [
      for (final entry in widget.initialRows) _KvRow(entry.key, entry.value),
    ];
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _emit() {
    _emitting = true;
    widget.onChanged([
      for (final row in _rows) MapEntry(row.key.text, row.value.text),
    ]);
    _emitting = false;
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Text(widget.title, style: labelStyle),
          ),
          if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                'No entries'.tr,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: dimTextColor(context)),
              ),
            ),
          for (var index = 0; index < _rows.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _rows[index].key,
                      onTap: () => widget.onControllerFocused(_rows[index].key),
                      onChanged: (_) => _emit(),
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Key'.tr,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _rows[index].value,
                      onTap: () =>
                          widget.onControllerFocused(_rows[index].value),
                      onChanged: (_) => _emit(),
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Value'.tr,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      tooltip: 'Delete'.tr,
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () {
                        setState(() {
                          _rows.removeAt(index).dispose();
                        });
                        _emit();
                      },
                    ),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: () {
              setState(() => _rows.add(_KvRow('', '')));
              _emit();
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text('Add'.tr),
          ),
        ],
      ),
    );
  }
}

/// Result card of the test panel: HTTP status, elapsed time, parsed result,
/// plus expandable raw request and response for debugging.
class _ProbeCard extends StatelessWidget {
  const _ProbeCard({required this.probe});

  final TranslationProbe probe;

  @override
  Widget build(BuildContext context) {
    final status = probe.status;
    final ok = probe.error == null && status != null && status >= 200;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (status != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ok
                        ? Colors.green.withValues(alpha: 0.2)
                        : Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'HTTP $status',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: ok
                          ? Colors.green
                          : Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                '${probe.elapsedMs} ms',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: dimTextColor(context)),
              ),
            ],
          ),
          if (probe.error != null) ...[
            const SizedBox(height: 8),
            Text(
              localizedTranslationError(probe.error!),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            if (probe.errorDetail != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  probe.errorDetail!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: dimTextColor(context),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
          if (probe.parsed != null) ...[
            const SizedBox(height: 8),
            Text(
              'Parsed result'.tr,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: dimTextColor(context)),
            ),
            SelectableText(
              probe.parsed!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (probe.rawBody != null && probe.rawBody!.trim().isNotEmpty)
            _detailTile(
              context,
              title: 'Raw response body'.tr,
              content: probe.rawBody!,
            ),
          if (probe.responseHeaders != null &&
              probe.responseHeaders!.trim().isNotEmpty)
            _detailTile(
              context,
              title: 'Raw response headers'.tr,
              content: probe.responseHeaders!,
            ),
          _detailTile(
            context,
            title: 'Raw request headers'.tr,
            content: [
              if (probe.requestUrl != null)
                '${probe.requestMethod ?? ''} ${probe.requestUrl!}'.trim(),
              for (final entry in probe.requestHeaders.entries)
                '${entry.key}: ${entry.value}',
              if (probe.requestBody != null) ...['', probe.requestBody!],
            ].join('\n'),
          ),
        ],
      ),
    );
  }

  Widget _detailTile(
    BuildContext context, {
    required String title,
    required String content,
  }) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 8),
    dense: true,
    title: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: dimTextColor(context)),
    ),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: SelectableText(
          content,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            color: dimTextColor(context),
          ),
        ),
      ),
    ],
  );
}

/// Plain-text (JSON) editor for a [TranslationRequestProfile], used by the
/// configurator's "edit as plain text" action. Save stays disabled until
/// the text parses as a JSON object.
class _PlainTextProfileDialog extends StatelessWidget {
  const _PlainTextProfileDialog({required this.controller});

  final TextEditingController controller;

  (String?, TranslationRequestProfile?) _tryParse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return ('empty', null);
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        return ('not a JSON object', null);
      }
      return (
        null,
        TranslationRequestProfile.fromJson(decoded.cast<String, dynamic>()),
      );
    } on FormatException catch (error) {
      return (error.message, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit as plain text'.tr),
      scrollable: true,
      content: SizedBox(
        width: double.maxFinite,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            final (error, profile) = _tryParse(value.text);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  minLines: 12,
                  maxLines: 20,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(
                        error == null
                            ? Icons.check_circle
                            : Icons.error_outline,
                        size: 16,
                        color: error == null
                            ? Colors.green
                            : Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          error ?? 'JSON valid'.tr,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: error == null
                                    ? dimTextColor(context)
                                    : Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            final formatted = formatJsonBody(controller.text);
            controller.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
          },
          child: Text('Format'.tr),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('CANCEL'.tr),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            final (_, profile) = _tryParse(value.text);
            return FilledButton(
              onPressed: profile == null
                  ? null
                  : () => Navigator.of(context).pop(profile),
              child: Text('Save'.tr),
            );
          },
        ),
      ],
    );
  }
}
