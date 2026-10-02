import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/core/localization/direction.dart';

void main() {
  test('device Arabic and English, unsupported fallback and override', () {
    expect(resolveLocale(const Locale('ar', 'EG'), null), const Locale('ar'));
    expect(resolveLocale(const Locale('en', 'GB'), null), const Locale('en'));
    expect(resolveLocale(const Locale('fr'), null), const Locale('en'));
    expect(resolveLocale(const Locale('en'), 'ar'), const Locale('ar'));
    expect(resolveLocale(const Locale('ar'), 'en'), const Locale('en'));
  });
  test('mixed Arabic/English first strong direction, neutral prefix', () {
    expect(
      contentDirection('123 — مهندس Flutter', TextDirection.ltr),
      TextDirection.rtl,
    );
    expect(
      contentDirection('Flutter مهندس', TextDirection.rtl),
      TextDirection.ltr,
    );
    expect(contentDirection('123 +20', TextDirection.rtl), TextDirection.rtl);
    expect(contentDirection('', TextDirection.ltr), TextDirection.ltr);
  });
}
