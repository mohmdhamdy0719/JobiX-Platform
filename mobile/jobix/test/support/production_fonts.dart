import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

/// Real packaged font rendering, not proof of native/device acceptance.
Future<void> loadProductionFonts() async {
  final packages =
      jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
          as Map;
  final flutter = (packages['packages'] as List).cast<Map>().firstWhere(
    (p) => p['name'] == 'flutter',
  );
  final sdk = Directory.fromUri(
    Uri.parse(flutter['rootUri'] as String),
  ).parent.parent.path;
  final families = {
    'Inter': ['assets/fonts/Inter.ttf'],
    'Noto Sans Arabic': [
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold'])
        'assets/fonts/NotoSansArabic-$weight.ttf',
    ],
    'MaterialIcons': [
      '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
      );
    }
    await loader.load();
  }
}
