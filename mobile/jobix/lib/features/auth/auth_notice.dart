import '../../l10n/app_localizations.dart';

enum AuthNoticeKind { failure, resetSent, googleUnavailable }

/// Keep notice semantics in state so language switching always updates copy.
extension AuthNoticeCopy on AuthNoticeKind {
  String localized(AppLocalizations copy) => switch (this) {
    AuthNoticeKind.failure => copy.authError,
    AuthNoticeKind.resetSent => copy.resetSent,
    AuthNoticeKind.googleUnavailable => copy.googleUnavailable,
  };
}
