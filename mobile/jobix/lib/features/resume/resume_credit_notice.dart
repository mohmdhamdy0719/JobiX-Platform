import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// Explains new-export affordability without replacing the server's admission
/// decision. Eligible re-downloads never use this widget.
class ResumeCreditNotice extends StatelessWidget {
  const ResumeCreditNotice({
    required this.availableCredits,
    this.loading = false,
    this.unavailable = false,
    this.onRetry,
    this.onReviewHistory,
    super.key,
  });

  final int? availableCredits;
  final bool loading;
  final bool unavailable;
  final VoidCallback? onRetry;
  final VoidCallback? onReviewHistory;

  @override
  Widget build(BuildContext context) {
    if (availableCredits != null &&
        availableCredits! >= 2 &&
        !loading &&
        !unavailable) {
      return const SizedBox.shrink();
    }
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    String t(String en, String ar) => isArabic ? ar : en;
    final checking = loading;
    final unknown = unavailable || availableCredits == null && !checking;
    final insufficient = !checking && !unknown;
    final balance = availableCredits;
    final background = insufficient
        ? TokensV0.errorContainer
        : TokensV0.surfaceContainerLow;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(TokensV0.space12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(TokensV0.cardRadius),
          border: Border.all(
            color: insufficient
                ? TokensV0.error.withValues(alpha: .35)
                : TokensV0.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  checking
                      ? Icons.hourglass_top
                      : unknown
                      ? Icons.account_balance_wallet_outlined
                      : Icons.info_outline,
                  color: insufficient ? TokensV0.error : TokensV0.deepBlue,
                ),
                const SizedBox(width: TokensV0.space8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checking
                            ? t(
                                'Checking Credit balance',
                                'جارٍ التحقق من الرصيد',
                              )
                            : unknown
                            ? t('Credit balance unavailable', 'الرصيد غير متاح')
                            : t('Not enough Credits', 'الرصيد غير كافٍ'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: insufficient
                              ? TokensV0.onErrorContainer
                              : TokensV0.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: TokensV0.space4),
                      Text(
                        checking
                            ? t(
                                'Checking the server-recorded balance. Export is paused until it loads.',
                                'جارٍ التحقق من الرصيد المسجل على الخادم. سيتاح التصدير بعد تحميله.',
                              )
                            : unknown
                            ? t(
                                'We could not verify your balance. Try again before exporting.',
                                'تعذر التحقق من رصيدك. أعد المحاولة قبل التصدير.',
                              )
                            : t(
                                'A new resume PDF costs 2 Credits. You currently have $balance ${balance == 1 ? 'Credit' : 'Credits'}. Credit purchases are not available in this build.',
                                'يكلف ملف PDF جديد رصيدين. رصيدك الحالي $balance. شراء الأرصدة غير متاح في هذا الإصدار.',
                              ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: insufficient
                              ? TokensV0.onErrorContainer
                              : TokensV0.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (unknown && onRetry != null ||
                insufficient && onReviewHistory != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: unknown ? onRetry : onReviewHistory,
                  child: Text(
                    unknown
                        ? t('Retry balance check', 'إعادة التحقق من الرصيد')
                        : t('Review Credit history', 'مراجعة سجل الرصيد'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
