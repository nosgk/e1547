import 'dart:convert';
import 'dart:io';

// One-off i18n key extractor: finds `.tr` / `.trArgs(` bound to one or more
// adjacent string literals, concatenates adjacent literals, unescapes them,
// and compares against assets/i18n/zh-CN.json.

const String lit =
    r"""r?(?:'''(?:[^\\]|\\.)*?'''|\"\"\"(?:[^\\]|\\.)*?\"\"\"|'(?:[^'\\\n]|\\.)*'|\"(?:[^\"\\\n]|\\.)*\")""";
final RegExp adjTrRe = RegExp('(?:$lit)(?:\\s+(?:$lit))*\\s*\\.tr\\b');
final RegExp adjTrArgsRe = RegExp(
  '(?:$lit)(?:\\s+(?:$lit))*\\s*\\.trArgs\\s*\\(',
);
final RegExp litRe = RegExp(lit);

String unescape(String s) {
  if (s.startsWith('r')) {
    // raw string: strip prefix + quotes, no escapes
    final body = s.substring(1);
    for (final q in const ["'''", '"""', "'", '"']) {
      if (body.startsWith(q) &&
          body.endsWith(q) &&
          body.length >= q.length * 2) {
        return body.substring(q.length, body.length - q.length);
      }
    }
    return body;
  }
  final body = _stripQuotes(s);
  final sb = StringBuffer();
  for (var i = 0; i < body.length; i++) {
    final c = body[i];
    if (c == r'\' && i + 1 < body.length) {
      final n = body[++i];
      switch (n) {
        case 'n':
          sb.write('\n');
        case 't':
          sb.write('\t');
        case 'r':
          sb.write('\r');
        case 'b':
          sb.write('\b');
        case 'f':
          sb.write('\f');
        case 'v':
          sb.write('\v');
        case '0':
          sb.write('\x00'); // \0 not valid alone in Dart but harmless here
        case 'x' || 'u' || 'U':
          // Unicode escapes: \xHH \uXXXX \u{...} \UXXXXXXXX. Malformed
          // sequences (too short, unterminated braces, non-hex digits,
          // out-of-range values) are preserved verbatim so that a bad source
          // string never crashes the extraction and its key still matches
          // the original text.
          final len = switch (n) {
            'x' => 2,
            'u' => 4,
            _ => 8,
          };
          var j = i + 1;
          String? decoded;
          if (n != 'x' && j < body.length && body[j] == '{') {
            final hexBuf = StringBuffer();
            j++;
            while (j < body.length && body[j] != '}') {
              hexBuf.write(body[j++]);
            }
            if (j < body.length) {
              final value = int.tryParse(hexBuf.toString(), radix: 16);
              if (value != null && value >= 0 && value <= 0x10FFFF) {
                decoded = String.fromCharCode(value);
                i = j; // consumed through the closing brace
              }
            }
          } else if (i + len < body.length) {
            final value = int.tryParse(
              body.substring(i + 1, i + 1 + len),
              radix: 16,
            );
            if (value != null && value >= 0 && value <= 0x10FFFF) {
              decoded = String.fromCharCode(value);
              i += len; // consumed through the last hex digit
            }
          }
          if (decoded != null) {
            sb.write(decoded);
          } else {
            sb.write(r'\');
            sb.write(n);
          }
        default:
          sb.write(n); // \' \" \\ \$
      }
    } else {
      sb.write(c);
    }
  }
  return sb.toString();
}

String _stripQuotes(String s) {
  for (final q in const ["'''", '"""', "'", '"']) {
    if (s.startsWith(q) && s.endsWith(q) && s.length >= q.length * 2) {
      return s.substring(q.length, s.length - q.length);
    }
  }
  return s;
}

void main(List<String> args) {
  final root = Directory(args.isNotEmpty ? args[0] : 'lib');
  final jsonPath = args.length > 1 ? args[1] : 'assets/i18n/zh-CN.json';

  final keys = <String, List<String>>{}; // key -> [file:line]
  final dynamicFlags = <String, List<String>>{};
  final dynamicReceivers = <String>[]; // non-literal .tr receivers

  final dartFiles =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where(
            (f) =>
                !f.path.endsWith('.g.dart') &&
                !f.path.endsWith('.freezed.dart'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final f in dartFiles) {
    final text = f.readAsStringSync();
    final rel = f.path.replaceAll(r'\', '/');

    // static literal keys
    for (final re in [adjTrRe, adjTrArgsRe]) {
      for (final m in re.allMatches(text)) {
        final snippet = m.group(0)!;
        final line = text.substring(0, m.start).split('\n').length;
        final lits = litRe
            .allMatches(snippet)
            .map((e) => unescape(e.group(0)!))
            .toList();
        final key = lits.join();
        if (key.contains(RegExp(r'(?<!\\)\$'))) {
          dynamicFlags.putIfAbsent(key, () => []).add('$rel:$line');
        } else {
          keys.putIfAbsent(key, () => []).add('$rel:$line');
        }
      }
    }

    // dynamic receivers: .tr not preceded by a literal
    for (final m in RegExp(r'\.tr\b|\.trArgs\s*\(').allMatches(text)) {
      if (adjTrRe.matchAsPrefix(text, m.start - 1) != null ||
          adjTrArgsRe.matchAsPrefix(text, m.start - 1) != null) {
        continue;
      }
      final before = text.substring(
        (m.start - 60).clamp(0, text.length),
        m.start,
      );
      final line = text.substring(0, m.start).split('\n').length;
      dynamicReceivers.add('$rel:$line  ...${before.replaceAll('\n', '⏎')}');
    }
  }

  // existing JSON keys
  Map<String, dynamic> existing = {};
  try {
    existing = (jsonDecode(File(jsonPath).readAsStringSync()) as Map)
        .cast<String, dynamic>();
  } on Object catch (e) {
    stderr.writeln('WARN: cannot read $jsonPath: $e');
  }

  final sortedKeys = keys.keys.toList()..sort((a, b) => a.compareTo(b));
  final missing = sortedKeys.where((k) => !existing.containsKey(k)).toList();
  final stale = existing.keys.where((k) => !keys.containsKey(k)).toList()
    ..sort((a, b) => a.compareTo(b));

  final out = {
    'totalStaticKeys': sortedKeys.length,
    'jsonKeys': existing.length,
    'missingCount': missing.length,
    'staleCount': stale.length,
    'missing': missing,
    'missingLocations': {for (final k in missing) k: keys[k]},
    'staleKeys': stale,
    'dynamicFlaggedKeys': {
      for (final e in dynamicFlags.entries) e.key: e.value,
    },
    'dynamicReceivers': dynamicReceivers,
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(out));
}
