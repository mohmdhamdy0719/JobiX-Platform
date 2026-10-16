import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/core/design/jobix_dialog.dart';
import 'package:jobix/core/design/tokens.dart';
import 'package:jobix/l10n/app_localizations.dart';

void main() {
  for (final locale in ['en', 'ar']) {
    testWidgets(
      '$locale shared dialog is branded, scrollable, and preserves results',
      (tester) async {
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: foundationTheme(languageCode: locale),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showDialog<bool>(
                      context: context,
                      builder: (dialog) => JobixAlertDialog(
                        icon: const Icon(Icons.warning_amber_outlined),
                        title: const Text('Confirm'),
                        content: const Text('Discard these changes?'),
                        actions: [
                          JobixDialogAction.secondary(
                            onPressed: () => Navigator.pop(dialog, false),
                            child: const Text('Stay'),
                          ),
                          JobixDialogAction.destructive(
                            onPressed: () => Navigator.pop(dialog, true),
                            child: const Text('Discard'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final alert = tester.widget<AlertDialog>(find.byType(AlertDialog));
        expect(alert.scrollable, isTrue);
        expect(
          Theme.of(tester.element(find.byType(AlertDialog))).dialogTheme.shape,
          isA<RoundedRectangleBorder>(),
        );
        final discard = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Discard'),
        );
        expect(
          discard.style?.foregroundColor?.resolve({}),
          const Color(0xFFB42332),
        );
        await tester.tap(find.text('Stay'));
        await tester.pumpAndSettle();
        expect(result, false);

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();
        expect(result, true);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
