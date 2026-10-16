import 'package:flutter/material.dart';

/// Locale-aware strings shared by the resume experience presentation widgets.
class ResumeCopy {
  const ResumeCopy(this.isArabic);

  final bool isArabic;

  static ResumeCopy of(BuildContext context) =>
      ResumeCopy(Localizations.localeOf(context).languageCode == 'ar');

  String get inspectTemplate => isArabic ? 'معاينة القالب' : 'Inspect template';
  String get atsProfessional =>
      isArabic ? 'احترافي ومتوافق مع ATS' : 'ATS Professional';
  String get sampleFictional =>
      isArabic ? 'نموذج توضيحي خيالي' : 'Illustrative fictional sample';
  String get atsSingleTemplate => isArabic
      ? 'قالب احترافي واحد متوافق مع ATS'
      : 'One ATS-ready professional template';
  String get resumeExport =>
      isArabic ? 'تصدير السيرة الذاتية' : 'Resume export';
  String get exportHistory => isArabic ? 'سجل التصدير' : 'Go to export history';
  String get dashboard =>
      isArabic ? 'العودة إلى لوحة التحكم' : 'Return to dashboard';
  String get downloadPdf => isArabic ? 'تنزيل ملف PDF' : 'Download PDF';
  String get details => isArabic ? 'التفاصيل' : 'Details';
  String get download => isArabic ? 'تنزيل' : 'Download';
  String get downloading => isArabic ? 'جارٍ التنزيل' : 'Downloading';
  String get tryAgain => isArabic ? 'إعادة المحاولة' : 'Try again';
  String get jobId => isArabic ? 'رقم المهمة' : 'Job ID';
  String get exportDetails => isArabic ? 'تفاصيل التصدير' : 'Export details';
  String get profile => isArabic ? 'الملف المهني' : 'Profile';
  String get template => isArabic ? 'القالب' : 'Template';
  String get cvLanguage => isArabic ? 'لغة السيرة الذاتية' : 'CV language';
  String get pages => isArabic ? 'الصفحات' : 'Pages';
  String get fileSize => isArabic ? 'حجم الملف' : 'File size';
  String get status => isArabic ? 'الحالة' : 'Status';
  String get credits => isArabic ? 'الرصيد والتكلفة' : 'Credit impact';
  String get noSecondCharge => isArabic
      ? 'إعادة التنزيل لا تخصم رصيداً إضافياً.'
      : 'Re-downloading does not use additional credits.';
  String get downloadAvailability =>
      isArabic ? 'إتاحة التنزيل' : 'Download availability';
  String get privateDownloadAvailable => isArabic
      ? 'التنزيل الخاص متاح من خوادم JobiX.'
      : 'Private download is available from JobiX servers.';
  String privateDownloadUntil(String date) => isArabic
      ? 'التنزيل الخاص متاح حتى $date.'
      : 'Private download is available until $date.';
  String get downloadUnavailable => isArabic
      ? 'التنزيل غير متاح لهذه المهمة.'
      : 'Download is not available for this job.';
  String get expires => isArabic ? 'ينتهي في' : 'Expires';
  String get resumeReceipt =>
      isArabic ? 'إيصال تصدير السيرة الذاتية' : 'Resume export receipt';
  String get resumeCompilation => isArabic
      ? 'إنشاء وتصدير السيرة الذاتية'
      : 'Resume compilation and export';
  String get chargedTwoCredits => isArabic ? 'خصم ٢ رصيد' : '−2 Credits';
  String get stateExpired => isArabic ? 'انتهت صلاحية الملف' : 'File expired';
  String get stateMissing => isArabic ? 'الملف غير متاح' : 'File unavailable';
  String get unavailableDescription => isArabic
      ? 'لن يتم إنشاء بديل أو خصم أرصدة تلقائيًا. إعادة التصدير طلب جديد يتطلب تأكيدًا.'
      : 'No replacement or charge is automatic. Re-export is a new request requiring confirmation.';
  String get processing =>
      isArabic ? 'جارٍ إعداد سيرتك الذاتية' : 'Your resume is being prepared';
  String get queuedDescription => isArabic
      ? 'تم استلام طلبك. سيظهر التحديث عند اكتمال المعالجة.'
      : 'Your request is queued. This view will update when processing finishes.';
  String get runningDescription => isArabic
      ? 'جارٍ إعداد ملفك. حالة المعالجة غير محددة.'
      : 'Your file is being prepared. Processing time is not estimated.';
  String get completedTitle =>
      isArabic ? 'اكتمل تصدير سيرتك الذاتية' : 'Your resume export is complete';
  String get completedDescription =>
      isArabic ? 'أصبح ملفك جاهزاً.' : 'Your file is ready.';
  String get failedTitle =>
      isArabic ? 'تعذّر إكمال التصدير' : 'The export could not be completed';
  String get failedDescription => isArabic
      ? 'لم يتم تحصيل تكلفة نهائية لهذه المهمة الفاشلة.'
      : 'No final charge is applied to a failed export.';
  String get pendingTitle =>
      isArabic ? 'طلب التصدير قيد الانتظار' : 'Your export is waiting';
  String get pendingDescription => isArabic
      ? 'سيظهر تحديث هنا عند بدء المعالجة.'
      : 'An update will appear here when processing begins.';
  String get stateQueued => isArabic ? 'في قائمة الانتظار' : 'Queued';
  String get stateProcessing => isArabic ? 'قيد المعالجة' : 'Processing';
  String get stateCompleted => isArabic ? 'مكتمل' : 'Completed';
  String get stateFailed => isArabic ? 'فشل' : 'Failed';
  String get statePending => isArabic ? 'قيد الانتظار' : 'Pending';
  String pageCount(int count) {
    if (isArabic) {
      return switch (count) {
        1 => 'صفحة واحدة',
        2 => 'صفحتان',
        _ => '$count صفحات',
      };
    }
    return count == 1 ? '1 page' : '$count pages';
  }

  String get languageArabic => isArabic ? 'العربية' : 'Arabic';
  String get languageEnglish => isArabic ? 'الإنجليزية' : 'English';
  String downloadPdfWithSize(String size) =>
      isArabic ? 'تنزيل ملف PDF ($size)' : 'Download PDF ($size)';
}

String resumeJobState(Map<String, dynamic> job) {
  final value = job['state']?.toString().trim().toLowerCase() ?? '';
  if (value == 'complete' || value == 'completed' || value == 'success') {
    return 'completed';
  }
  if (value == 'failed' || value == 'failure' || value == 'error') {
    return 'failed';
  }
  if (value == 'queued' || value == 'reserved' || value == 'enqueued') {
    return 'queued';
  }
  if (value == 'processing' || value == 'running' || value == 'in_progress') {
    return 'processing';
  }
  if ([
    'claimed',
    'generating',
    'uploading',
    'retryable_failure',
  ].contains(value)) {
    return 'processing';
  }
  if (value == 'expired') return 'expired';
  if (value == 'missing_object') return 'missing';
  return 'pending';
}

/// Downloads require a completed job, backend eligibility, and an unexpired
/// retention window. Missing or invalid expiry metadata fails closed.
bool resumeIsDownloadAvailable(
  Map<String, dynamic> job,
  String state, {
  DateTime? now,
}) {
  if (state != 'completed' || job['download_eligible'] != true) return false;
  final expiresAt = resumeParseDate(job['expires_at']);
  return expiresAt != null && expiresAt.isAfter(now ?? DateTime.now());
}

String resumeStatusLabel(ResumeCopy copy, String state) => switch (state) {
  'completed' => copy.stateCompleted,
  'failed' => copy.stateFailed,
  'queued' => copy.stateQueued,
  'processing' => copy.stateProcessing,
  'expired' => copy.stateExpired,
  'missing' => copy.stateMissing,
  _ => copy.statePending,
};

String resumeStatusTitle(ResumeCopy copy, String state) => switch (state) {
  'completed' => copy.completedTitle,
  'failed' => copy.failedTitle,
  'queued' || 'processing' => copy.processing,
  'expired' => copy.stateExpired,
  'missing' => copy.stateMissing,
  _ => copy.pendingTitle,
};

String resumeStatusDescription(ResumeCopy copy, String state) =>
    switch (state) {
      'completed' => copy.completedDescription,
      'failed' => copy.failedDescription,
      'queued' => copy.queuedDescription,
      'processing' => copy.runningDescription,
      'expired' || 'missing' => copy.unavailableDescription,
      _ => copy.pendingDescription,
    };

String? resumeCreditNote(ResumeCopy copy, String state) {
  if (state == 'queued' || state == 'processing') {
    return resumeCreditExplanation(copy, state);
  }
  if (state == 'completed') return copy.noSecondCharge;
  if (state == 'failed') return copy.failedDescription;
  if (state == 'expired' || state == 'missing') {
    return copy.unavailableDescription;
  }
  return null;
}

String resumeCreditExplanation(ResumeCopy copy, String state) {
  if (state == 'completed') {
    return copy.isArabic
        ? 'تُخصم ٢ من الرصيد عند نجاح التصدير. التنزيل المؤهل مجاني.'
        : '2 Credits are charged on successful completion. Eligible downloads are free.';
  }
  if (state == 'queued' || state == 'processing') {
    return copy.isArabic
        ? 'تم حجز ٢ من الرصيد أثناء معالجة الطلب.'
        : '2 Credits are reserved while this request is processing.';
  }
  if (state == 'failed') return copy.failedDescription;
  return copy.isArabic
      ? 'تُخصم ٢ من الرصيد عند نجاح التصدير فقط.'
      : '2 Credits are charged only if the export completes successfully.';
}

String resumeLocalizedLanguage(ResumeCopy copy, String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized == 'ar' || normalized == 'arabic' || normalized == 'rtl') {
    return copy.languageArabic;
  }
  if (normalized == 'en' || normalized == 'english' || normalized == 'ltr') {
    return copy.languageEnglish;
  }
  return value;
}

String? resumeFirstString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String? resumeTemplateDisplayName(ResumeCopy copy, String? value) {
  final template = value?.trim();
  if (template == null || template.isEmpty) return null;
  if (template == 'ATS Professional' ||
      RegExp(r'^resume_ats_(en|ar)_v\d+$').hasMatch(template)) {
    return copy.atsProfessional;
  }
  return template;
}

int? resumePositiveInt(Object? value) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}

DateTime? resumeParseDate(Object? value) {
  if (value == null) return null;
  return value is DateTime
      ? value.toLocal()
      : DateTime.tryParse(value.toString())?.toLocal();
}

String? resumeDateLabel(Object? value) {
  final local = resumeParseDate(value);
  if (local == null) return null;
  final dateText =
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
  final timeText =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return '$dateText · $timeText';
}

String resumeFormatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}
