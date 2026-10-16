import 'package:flutter/material.dart';

/// The document owns scrolling. Navigation and actions occupy separate space;
/// they never overlay the platform view or change its canonical content.
class ResumePreviewLayout extends StatelessWidget {
  const ResumePreviewLayout({
    required this.paper,
    required this.language,
    required this.page,
    required this.pages,
    required this.busy,
    required this.exportEnabled,
    required this.valid,
    this.availableCredits,
    required this.onExport,
    required this.onEditProfile,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });
  final Widget paper;
  final Object? language;
  final int page, pages;
  final bool busy, exportEnabled, valid;
  final int? availableCredits;
  final VoidCallback? onExport, onEditProfile, onPrevious, onNext;

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String t(String en, String arabic) => ar ? arabic : en;
    final cvLanguage = switch (language) {
      'ar' => 'العربية (RTL)',
      'en' => 'English (LTR)',
      _ => t('CV language unavailable', 'لغة السيرة غير متاحة'),
    };
    final exportReady = exportEnabled && valid && !busy;
    return Scaffold(
      appBar: AppBar(title: Text(t('Preview', 'المعاينة'))),
      body: SafeArea(
        bottom: false,
        child: SizedBox.expand(
          key: const ValueKey('resume-document'),
          child: ClipRect(child: paper),
        ),
      ),
      bottomNavigationBar: Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  key: const ValueKey('resume-page-navigation'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: t('Previous page', 'الصفحة السابقة'),
                      onPressed: onPrevious,
                      icon: Icon(ar ? Icons.chevron_right : Icons.chevron_left),
                    ),
                    Flexible(
                      child: Text(
                        pages == 0
                            ? t('Laying out pages…', 'جارٍ تجهيز الصفحات…')
                            : t(
                                'Page ${page + 1} of $pages',
                                'صفحة ${page + 1} من $pages',
                              ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      tooltip: t('Next page', 'الصفحة التالية'),
                      onPressed: onNext,
                      icon: Icon(ar ? Icons.chevron_left : Icons.chevron_right),
                    ),
                  ],
                ),
                const Divider(height: 1),
                Padding(
                  key: const ValueKey('resume-preview-info'),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '${t('ATS Professional', 'القالب المهني ATS')} • '
                    '$cvLanguage • ${t('New PDF: 2 Credits', 'ملف PDF جديد: رصيدان')}'
                    '${availableCredits == null ? '' : ' • ${t('Available', 'المتاح')}: $availableCredits'}',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                LayoutBuilder(
                  builder: (context, size) {
                    final export = FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: exportReady ? onExport : null,
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_outlined),
                      label: Text(t('Export PDF', 'تصدير PDF')),
                    );
                    final edit = OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: onEditProfile,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(t('Edit Profile', 'تعديل الملف')),
                    );
                    if (size.maxWidth >= 360 &&
                        MediaQuery.textScalerOf(context).scale(14) <= 18) {
                      return Row(
                        children: [
                          Expanded(child: export),
                          const SizedBox(width: 8),
                          Expanded(child: edit),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [export, const SizedBox(height: 4), edit],
                    );
                  },
                ),
                if (!valid || !exportEnabled)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      !valid
                          ? t(
                              'Fix or hide invalid sections before exporting.',
                              'أصلح الأقسام غير الصالحة أو أخفها قبل التصدير.',
                            )
                          : t(
                              'Export disabled. Preview is free.',
                              'التصدير معطّل. المعاينة مجانية.',
                            ),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
