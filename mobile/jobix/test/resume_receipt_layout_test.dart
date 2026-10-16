import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/core/design/tokens.dart';
import 'package:jobix/features/resume/resume_experience_components.dart';
import 'package:jobix/features/resume/resume_experience_shared.dart';
import 'package:jobix/features/resume/resume_receipt_panel.dart';
import 'package:jobix/l10n/app_localizations.dart';

void main() {
  for (final locale in ['en', 'ar']) {
    for (final width in [288.0, 358.0]) {
      testWidgets(
        '$locale completed receipt aligns Credit impact at $width logical pixels',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: foundationTheme(languageCode: locale),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: width,
                    child: ResumeReceiptPanel(
                      copy: ResumeCopy(locale == 'ar'),
                      state: 'completed',
                      createdAt: 'Today',
                      completedAt: 'Today',
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final panel = tester.getRect(
            find.byKey(const ValueKey('resume-receipt-panel')),
          );
          final pill = tester.getRect(find.byType(ResumeStatePill));
          final cost = tester.getRect(
            find.byKey(const ValueKey('receipt-credit-impact')),
          );
          expect(pill.overlaps(cost), isFalse);
          if (width < 340) {
            expect(cost.top, greaterThanOrEqualTo(pill.bottom));
          }
          final trailingGap = locale == 'ar'
              ? cost.left - panel.left
              : panel.right - cost.right;
          expect(trailingGap, inInclusiveRange(12, 24));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
