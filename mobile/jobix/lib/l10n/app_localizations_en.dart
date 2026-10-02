// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Jobix';

  @override
  String get boot => 'Starting Jobix';

  @override
  String get signedOut => 'Signed-out foundation';

  @override
  String get signedIn => 'Signed-in foundation';

  @override
  String get placeholder =>
      'Foundation placeholder. Product screens are not implemented.';

  @override
  String get updateRequired => 'An app update is required.';

  @override
  String get startupFailed =>
      'Jobix could not start. Check configuration and connectivity, then retry.';

  @override
  String get retry => 'Retry';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutFailed => 'Sign-out could not complete. Please retry.';
}
