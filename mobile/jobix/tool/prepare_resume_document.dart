import 'dart:convert';
import 'dart:io';
import '../lib/features/resume/resume_document.dart';

/// Private server subprocess: JSON on stdin/stdout, never a listening service.
/// No public HTML input; callers supply authoritative database source only.
Future<void> main(List<String> args) async {
  try {
    if (args.length != 1) throw StateError('APP_UPDATE_REQUIRED');
    final source = jsonDecode(await stdin.transform(utf8.decoder).join());
    final root = args.single;
    final result = ResumeDocument.prepare(
      Map<String, dynamic>.from(source as Map),
      base64Encode(await File('$root/assets/fonts/Inter.ttf').readAsBytes()),
      base64Encode(await File(
        '$root/assets/fonts/IBMPlexSansArabic-Regular.ttf').readAsBytes()));
    stdout.write(jsonEncode(result));
  } catch (_) {
    // No exception/input snippets: source contains private career data.
    stderr.write('DOCUMENT_PREPARATION_FAILED');
    exitCode = 1;
  }
}
