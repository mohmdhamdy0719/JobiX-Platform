import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';

enum AuthNoticeKind {
  failure,
  resetSent,
  googleUnavailable,
  rateLimited,
  notConfirmed,
  invalidCredentials,
  weakPassword,
  invalidEmail,
  userExists,
  network,
  confirmationResent,
}

/// Maps provider errors to a specific, actionable notice instead of one
/// generic failure. Unknown errors stay generic.
AuthNoticeKind authNoticeFor(Object error) {
  if (error is SocketException ||
      error is TimeoutException ||
      error is AuthRetryableFetchException) {
    return AuthNoticeKind.network;
  }
  if (error is! AuthException) return AuthNoticeKind.failure;
  final code = (error.code ?? '').toLowerCase();
  final message = error.message.toLowerCase();
  bool has(String value) => code == value || message.contains(value);
  if (has('over_email_send_rate_limit') ||
      has('over_request_rate_limit') ||
      error.statusCode == '429') {
    return AuthNoticeKind.rateLimited;
  }
  if (has('email_not_confirmed') ||
      has('email_confirmation_required') ||
      message.contains('email not confirmed')) {
    return AuthNoticeKind.notConfirmed;
  }
  if (has('invalid_credentials') ||
      message.contains('invalid login credentials')) {
    return AuthNoticeKind.invalidCredentials;
  }
  if (has('weak_password') || error is AuthWeakPasswordException) {
    return AuthNoticeKind.weakPassword;
  }
  if (has('email_address_invalid') || has('validation_failed')) {
    return AuthNoticeKind.invalidEmail;
  }
  if (has('user_already_exists') || has('email_exists')) {
    return AuthNoticeKind.userExists;
  }
  return AuthNoticeKind.failure;
}

/// Keep notice semantics in state so language switching always updates copy.
extension AuthNoticeCopy on AuthNoticeKind {
  String localized(AppLocalizations copy) => switch (this) {
    AuthNoticeKind.failure => copy.authError,
    AuthNoticeKind.resetSent => copy.resetSent,
    AuthNoticeKind.googleUnavailable => copy.googleUnavailable,
    AuthNoticeKind.rateLimited => copy.authRateLimited,
    AuthNoticeKind.notConfirmed => copy.authNotConfirmed,
    AuthNoticeKind.invalidCredentials => copy.authInvalidCredentials,
    AuthNoticeKind.weakPassword => copy.authWeakPassword,
    AuthNoticeKind.invalidEmail => copy.authInvalidEmail,
    AuthNoticeKind.userExists => copy.authUserExists,
    AuthNoticeKind.network => copy.authNetwork,
    AuthNoticeKind.confirmationResent => copy.confirmationResent,
  };

  bool get isError =>
      this != AuthNoticeKind.resetSent &&
      this != AuthNoticeKind.confirmationResent;
}
