import 'dart:convert';

import 'package:e1547/translate/data/profile.dart';
import 'package:e1547/translate/data/translate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('multiline AI prompts stay valid JSON in the default request body', () {
    const profile = TranslationRequestProfile(
      method: 'POST',
      url: '@baseUrl/chat/completions',
      contentType: 'application/json',
      body: kOpenAiBodyTemplate,
    );
    const system = 'Line one.\nLine "two".';
    const user = 'Translate:\n@text';
    final rendered = renderJsonTemplate(profile.body, {
      'model': 'gpt-4o-mini',
      'systemPrompt': system,
      'userPrompt': user,
    });

    expect(validateJsonBody(rendered), isNull);
    final decoded = jsonDecode(rendered) as Map<String, dynamic>;
    final messages = decoded['messages'] as List<dynamic>;
    expect(messages[0]['content'], system);
    expect(messages[1]['content'], user);
  });
}
