// Standalone server CLI deliberately has no Flutter/package-runtime dependency.
// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:io';
import '../lib/features/resume/resume_document.dart';

/// Private server subprocess: JSON on stdin/stdout, never a listening service.
/// No public HTML input; callers supply authoritative database source only.
Future<void> main(List<String> args) async {
  try {
    if (args.length != 1 && !(args.length == 2 && args[1] == 'source')) {
      throw StateError('APP_UPDATE_REQUIRED');
    }
    final source = jsonDecode(await stdin.transform(utf8.decoder).join());
    final root = args.first;
    final render = args.length == 1;
    final result = ResumeDocument.prepare(
      Map<String, dynamic>.from(source as Map),
      render
          ? base64Encode(
              await File('$root/assets/fonts/Inter.ttf').readAsBytes(),
            )
          : '',
      render
          ? base64Encode(
              await File(
                '$root/assets/fonts/IBMPlexSansArabic-Regular.ttf',
              ).readAsBytes(),
            )
          : '',
      render: render,
    );
    stdout.write(jsonEncode(result));
  } catch (_) {
    // No exception/input snippets: source contains private career data.
    stderr.write('DOCUMENT_PREPARATION_FAILED');
    exitCode = 1;
  }
}
