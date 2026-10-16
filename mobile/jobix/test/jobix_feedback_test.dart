import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/core/design/jobix_feedback.dart';
import 'package:jobix/core/design/tokens.dart';

void main() {
  testWidgets(
    'feedback is accessible, color-coded, and replaces prior notices',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (value) {
                context = value;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );

      showJobixFeedback(context, 'Saved.');
      await tester.pump();
      var success = tester.widget<SnackBar>(
        find.byKey(const ValueKey('jobix-feedback-success')),
      );
      expect(success.backgroundColor, const Color(0xFFE8F5EE));
      expect(
        success.margin!.resolve(TextDirection.ltr).bottom,
        greaterThanOrEqualTo(84),
      );
      expect(
        tester
            .widget<Semantics>(
              find
                  .descendant(
                    of: find.byKey(const ValueKey('jobix-feedback-success')),
                    matching: find.byType(Semantics),
                  )
                  .first,
            )
            .properties
            .liveRegion,
        isTrue,
      );

      showJobixFeedback(
        context,
        'Check the highlighted fields.',
        kind: JobixFeedbackKind.warning,
      );
      await tester.pump(const Duration(milliseconds: 400));
      final warning = tester.widget<SnackBar>(
        find.byKey(const ValueKey('jobix-feedback-warning')),
      );
      expect(warning.backgroundColor, const Color(0xFFFFF2D6));
      expect(
        find.byKey(const ValueKey('jobix-feedback-success')),
        findsNothing,
      );
      expect(find.text('Check the highlighted fields.'), findsOneWidget);

      showJobixFeedback(context, 'Save failed.', kind: JobixFeedbackKind.error);
      await tester.pump(const Duration(milliseconds: 400));
      final error = tester.widget<SnackBar>(
        find.byKey(const ValueKey('jobix-feedback-error')),
      );
      expect(error.backgroundColor, TokensV0.errorContainer);
      expect(
        find.byKey(const ValueKey('jobix-feedback-warning')),
        findsNothing,
      );
      expect(find.text('Save failed.'), findsOneWidget);
    },
  );

  testWidgets('RTL feedback remains within the screen', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: Scaffold(
          body: Builder(
            builder: (value) {
              context = value;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    showJobixFeedback(context, 'تم الحفظ.');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.byType(SnackBar)).left, greaterThanOrEqualTo(0));
    expect(tester.getRect(find.byType(SnackBar)).right, lessThanOrEqualTo(360));
  });
}
