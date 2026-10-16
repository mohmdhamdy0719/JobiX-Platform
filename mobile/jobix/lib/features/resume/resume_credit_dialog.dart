import 'package:flutter/material.dart';

import '../../core/design/jobix_dialog.dart';

enum ResumeCreditDialogAction { cancel, reviewHistory, retry }

Future<ResumeCreditDialogAction?> showNotEnoughResumeCreditsDialog(
  BuildContext context, {
  required int availableCredits,
}) => showDialog<ResumeCreditDialogAction>(
  context: context,
  builder: (dialog) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String t(String en, String arabic) => ar ? arabic : en;
    return JobixAlertDialog(
      icon: const Icon(Icons.account_balance_wallet_outlined),
      title: Text(t('Not enough Credits', 'الرصيد غير كافٍ')),
      content: Text(
        t(
          'A new PDF export costs 2 Credits. You currently have $availableCredits Credits.',
          'يكلف تصدير PDF جديد رصيدين. رصيدك الحالي $availableCredits.',
        ),
      ),
      actions: [
        JobixDialogAction.secondary(
          onPressed: () =>
              Navigator.pop(dialog, ResumeCreditDialogAction.cancel),
          child: Text(t('Cancel', 'إلغاء')),
        ),
        JobixDialogAction.primary(
          onPressed: () =>
              Navigator.pop(dialog, ResumeCreditDialogAction.reviewHistory),
          child: Text(t('Review Credit History', 'مراجعة سجل الرصيد')),
        ),
      ],
    );
  },
);

Future<ResumeCreditDialogAction?> showResumeCreditBalanceUnavailableDialog(
  BuildContext context,
) => showDialog<ResumeCreditDialogAction>(
  context: context,
  builder: (dialog) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String t(String en, String arabic) => ar ? arabic : en;
    return JobixAlertDialog(
      icon: const Icon(Icons.account_balance_wallet_outlined),
      title: Text(t('Credit balance unavailable', 'الرصيد غير متاح')),
      content: Text(
        t(
          'We could not verify your current Credit balance. No export request was sent. Try again when your connection is available.',
          'تعذّر التحقق من رصيدك الحالي. لم يتم إرسال طلب تصدير. أعد المحاولة عند توفر الاتصال.',
        ),
      ),
      actions: [
        JobixDialogAction.secondary(
          onPressed: () =>
              Navigator.pop(dialog, ResumeCreditDialogAction.cancel),
          child: Text(t('Cancel', 'إلغاء')),
        ),
        JobixDialogAction.primary(
          onPressed: () =>
              Navigator.pop(dialog, ResumeCreditDialogAction.retry),
          child: Text(t('Retry', 'إعادة المحاولة')),
        ),
      ],
    );
  },
);
