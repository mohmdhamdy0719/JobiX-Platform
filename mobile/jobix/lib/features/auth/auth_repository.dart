import 'package:supabase_flutter/supabase_flutter.dart';

const authRedirectUri = 'com.mhflow.jobix://auth/callback';

bool sessionIsConfirmed(Session? session) {
  if (session == null) return false;
  // Supabase's verified Google identity is authoritative for Google login.
  return session.user.emailConfirmedAt != null ||
      session.user.appMetadata['provider'] == 'google';
}

abstract interface class AuthApi {
  Future<String?> signUp(String email, String password);
  Future<void> signIn(String email, String password);
  Future<bool> google();
  Future<void> reset(String email);
  Future<void> resendConfirmation(String email);
  Future<AuthAccountState> updateEmail(String email);
  Future<void> resendEmailChange(String email);
  Future<AuthAccountState> accountState({bool refresh = false});
  Future<void> updatePassword(String password);
  Future<void> callback(Uri uri);
  Future<void> signOut();
}

class AuthAccountState {
  const AuthAccountState({
    required this.userId,
    required this.email,
    this.pendingEmail,
    this.emailChangeSentAt,
  });
  final String userId, email;
  final String? pendingEmail, emailChangeSentAt;
}

class SupabaseAuthApi implements AuthApi {
  SupabaseAuthApi(this.client);
  final SupabaseClient client;
  @override
  Future<String?> signUp(String email, String password) async {
    final result = await client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: authRedirectUri,
    );
    // A confirmed address returns an obfuscated user with no identities.
    if (result.user != null && (result.user!.identities?.isEmpty ?? false)) {
      throw const AuthException(
        'user_already_exists',
        code: 'user_already_exists',
      );
    }
    return result.user?.id;
  }

  @override
  Future<void> resendConfirmation(String email) async {
    await client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: authRedirectUri,
    );
  }

  @override
  Future<void> signIn(String email, String password) async {
    final result = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (!sessionIsConfirmed(result.session)) {
      await client.auth.signOut(scope: SignOutScope.local);
      throw const AuthException(
        'EMAIL_CONFIRMATION_REQUIRED',
        code: 'email_not_confirmed',
      );
    }
  }

  @override
  Future<bool> google() => client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: authRedirectUri,
  );
  @override
  Future<void> reset(String email) => client.auth.resetPasswordForEmail(
    email.trim(),
    redirectTo: authRedirectUri,
  );
  @override
  Future<AuthAccountState> updateEmail(String email) async {
    final response = await client.auth.updateUser(
      UserAttributes(email: email.trim()),
    );
    final user = response.user;
    if (user == null) throw StateError('EMAIL_CHANGE_UNCONFIRMED');
    return AuthAccountState(
      userId: user.id,
      email: user.email ?? '',
      pendingEmail: user.newEmail,
      emailChangeSentAt: user.emailChangeSentAt,
    );
  }

  @override
  Future<void> resendEmailChange(String email) async {
    await client.auth.resend(
      type: OtpType.emailChange,
      email: email.trim(),
      emailRedirectTo: authRedirectUri,
    );
  }

  @override
  Future<AuthAccountState> accountState({bool refresh = false}) async {
    final user = refresh
        ? (await client.auth.getUser()).user
        : client.auth.currentUser;
    if (user == null) throw StateError('AUTH_REQUIRED');
    return AuthAccountState(
      userId: user.id,
      email: user.email ?? '',
      pendingEmail: user.newEmail,
      emailChangeSentAt: user.emailChangeSentAt,
    );
  }

  @override
  Future<void> updatePassword(String password) async {
    await client.auth.updateUser(UserAttributes(password: password));
  }

  @override
  Future<void> callback(Uri uri) async {
    if (!validAuthCallback(uri)) {
      throw const FormatException('Invalid auth callback');
    }
    if (uri.queryParameters['code'] case final String code) {
      await client.auth.exchangeCodeForSession(code);
    } else {
      // Supabase confirmation/recovery links may use provider-returned fragments.
      await client.auth.getSessionFromUrl(uri);
    }
  }

  @override
  Future<void> signOut() => client.auth.signOut(scope: SignOutScope.local);
}

bool validAuthCallback(Uri uri) =>
    uri.scheme == 'com.mhflow.jobix' &&
    uri.host == 'auth' &&
    uri.path == '/callback' &&
    uri.userInfo.isEmpty &&
    (uri.queryParameters.containsKey('code') ||
        uri.fragment.contains('access_token='));
