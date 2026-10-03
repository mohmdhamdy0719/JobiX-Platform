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
  Future<void> updatePassword(String password);
  Future<void> callback(Uri uri);
  Future<void> signOut();
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
    return result.user?.id;
  }

  @override
  Future<void> signIn(String email, String password) async {
    final result = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (!sessionIsConfirmed(result.session)) {
      await client.auth.signOut(scope: SignOutScope.local);
      throw const AuthException('EMAIL_CONFIRMATION_REQUIRED');
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
