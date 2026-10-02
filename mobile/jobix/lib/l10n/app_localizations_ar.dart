// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Jobix';

  @override
  String get boot => 'جارٍ تشغيل Jobix';

  @override
  String get signedOut => 'الأساس — دون تسجيل دخول';

  @override
  String get signedIn => 'الأساس — تم تسجيل الدخول';

  @override
  String get placeholder => 'واجهة مؤقتة للأساس. لم يتم تنفيذ شاشات المنتج.';

  @override
  String get updateRequired => 'يلزم تحديث التطبيق.';

  @override
  String get startupFailed =>
      'تعذّر تشغيل Jobix. تحقق من الإعدادات والاتصال ثم أعد المحاولة.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get signOutFailed => 'تعذّر إكمال تسجيل الخروج. يرجى إعادة المحاولة.';
}
