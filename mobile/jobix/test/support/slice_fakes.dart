import 'dart:io';
import 'package:jobix/features/auth/auth_repository.dart';
import 'package:jobix/features/career_profile/career_profile.dart';
import 'package:jobix/features/career_profile/career_profile_repository.dart';
import 'package:jobix/features/onboarding/research_context.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeProfileApi implements ProfileApi {
  bool entryPending = true;
  @override
  Future<bool> claimRegistrationEntry() async {
    final pending = entryPending;
    entryPending = false;
    return pending;
  }

  CareerProfile server = const CareerProfile(id: 'profile-one', version: 1);
  final Map<String, CareerProfile> acknowledged = {};
  final List<PersonalDraft> requests = [];
  bool offline = false, loseNextResponse = false;
  Object? loadError;
  int contextSaves = 0;
  @override
  Future<CareerProfile> firstProfile() async {
    if (loadError != null) throw loadError!;
    if (offline) throw const SocketException('Offline test boundary');
    return server;
  }

  @override
  Future<CareerProfile> save(PersonalDraft draft) async {
    requests.add(draft);
    if (offline) throw const SocketException('Offline test boundary');
    if (acknowledged.containsKey(draft.commandKey)) {
      return acknowledged[draft.commandKey]!;
    }
    final frozen = draft.frozen!;
    if (frozen['version'] != server.version) {
      throw const PostgrestException(
        message: 'VERSION_CONFLICT',
        code: 'P0001',
      );
    }
    final values = Map<String, String>.from(frozen['personal'] as Map);
    server = CareerProfile(
      id: server.id,
      version: server.version + 1,
      resumeLanguage: frozen['language'] as String?,
      personal: {for (final f in personalFields) f: (values[f] ?? '').trim()},
    );
    acknowledged[draft.commandKey!] = server;
    if (loseNextResponse) {
      loseNextResponse = false;
      throw const SocketException('Response lost after server commit');
    }
    return server;
  }

  @override
  Future<void> saveContext(ResearchProgress progress) async {
    contextSaves++;
  }
}

class FakeAuthApi implements AuthApi {
  final List<String> calls = [];
  bool confirmed = false, googleOpened = true;
  void Function()? onSignedIn;
  Object? signInError;
  @override
  Future<String?> signUp(String email, String password) async {
    calls.add('signup');
    return 'new-user';
  }

  @override
  Future<void> signIn(String email, String password) async {
    calls.add('signin');
    if (signInError case final Object error) throw error;
    if (!confirmed) throw const AuthException('EMAIL_CONFIRMATION_REQUIRED');
    onSignedIn?.call();
  }

  @override
  Future<bool> google() async {
    calls.add('google');
    return googleOpened;
  }

  @override
  Future<void> reset(String email) async {
    calls.add('reset');
  }

  @override
  Future<void> resendConfirmation(String email) async {
    calls.add('resend');
  }

  @override
  Future<void> updatePassword(String password) async {
    calls.add('password');
  }

  @override
  Future<void> callback(Uri uri) async {
    calls.add('callback');
  }

  @override
  Future<void> signOut() async {
    calls.add('signout');
  }
}

Session testSession({bool confirmed = true, String provider = 'email'}) =>
    Session(
      accessToken: 'test-only-token',
      tokenType: 'bearer',
      refreshToken: 'test-only-refresh',
      user: User(
        id: 'user-one',
        appMetadata: {'provider': provider},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-10-03T00:00:00Z',
        emailConfirmedAt: confirmed ? '2026-10-03T00:01:00Z' : null,
      ),
    );
