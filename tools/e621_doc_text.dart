import 'dart:convert';
import 'dart:io';

// Converts the saved e621 API help page (e621-api文档.htm) into plain text so
// it can be searched with rg. See docs/e621-api.md for when to use this.
//
// Usage: dart run tools/e621_doc_text.dart [input.htm] [output.txt]
// Defaults: e621-api文档.htm -> Temp/api_doc.txt

void main(List<String> args) {
  final input = File(args.isNotEmpty ? args[0] : 'e621-api文档.htm');
  if (!input.existsSync()) {
    stderr.writeln('input not found: ${input.path}');
    stderr.writeln('re-download it from https://e621.net/help/api');
    exitCode = 1;
    return;
  }

  final raw = utf8.decode(input.readAsBytesSync(), allowMalformed: true);

  final text = raw
      .replaceAllMapped(
        RegExp(
          r'<(script|style)[^>]*>.*?</\1>',
          caseSensitive: false,
          dotAll: true,
        ),
        (match) => ' ',
      )
      .replaceAllMapped(RegExp(r'<[^>]+>'), (match) => ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'[ \t]+'), ' ');

  final output = File(args.length > 1 ? args[1] : 'Temp/api_doc.txt');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(text);
  stdout.writeln('wrote ${output.path} (${text.length} chars)');
}
