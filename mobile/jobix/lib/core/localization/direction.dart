import 'package:flutter/widgets.dart';

/// First strong character sets paragraph direction; bidi handles embedded runs.
/// Digits and punctuation are neutral. Never reverse user-entered content.
TextDirection contentDirection(String text, TextDirection fallback) {
  for (final rune in text.runes) {
    if ((rune >= 0x0620 && rune <= 0x064a) ||
        (rune >= 0x066e && rune <= 0x06d3) ||
        (rune >= 0x05d0 && rune <= 0x05ea) ||
        (rune >= 0xfb50 && rune <= 0xfdff) ||
        (rune >= 0xfe70 && rune <= 0xfefc)) {
      return TextDirection.rtl;
    }
    if (RegExp(r'[A-Za-z]').hasMatch(String.fromCharCode(rune))) {
      return TextDirection.ltr;
    }
  }
  return fallback;
}

Locale resolveLocale(Locale device, String? override) {
  if (override == 'ar' || override == 'en') return Locale(override!);
  return Locale(device.languageCode == 'ar' ? 'ar' : 'en');
}
