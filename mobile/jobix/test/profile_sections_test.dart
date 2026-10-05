import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/features/auth/auth_notice.dart';
import 'package:jobix/features/career_profile/profile_sections.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

ProfileItem item(EntitySection section, Map<String, Object?> values) =>
    ProfileItem(id: 'id-1', section: section, values: values);

void main() {
  group('URL normalization mirrors the server', () {
    test('https only; bare domains gain https; others are rejected', () {
      expect(normalizeUrl(''), '');
      expect(normalizeUrl('example.com/me'), 'https://example.com/me');
      expect(normalizeUrl(' https://example.com '), 'https://example.com');
      expect(normalizeUrl('http://example.com'), isNull);
      expect(normalizeUrl('javascript:alert(1)'), isNull);
      expect(normalizeUrl('ftp://example.com'), isNull);
      expect(normalizeUrl('not a url'), isNull);
      expect(normalizeUrl('https://${'a' * 2050}.com'), isNull);
    });
  });

  group('item validation', () {
    test('incomplete items are saveable and earn no local completeness', () {
      final draft = item(EntitySection.experience, {'job_title': 'Dev'});
      expect(draft.problems(), isEmpty);
      expect(draft.locallyComplete, false);
    });

    test('complete experience needs end or current and a 20+ description', () {
      final base = item(EntitySection.experience, {
        'job_title': 'Dev',
        'company': 'Co',
        'start_month': '2022-03',
        'description': 'Shipped features weekly.',
      });
      expect(base.locallyComplete, false, reason: 'no end and not current');
      expect(base.copyWith('is_current', true).locallyComplete, true);
      expect(base.copyWith('end_month', '2023-01').locallyComplete, true);
      expect(
        base
            .copyWith('is_current', true)
            .copyWith('description', 'Too short')
            .locallyComplete,
        false,
      );
    });

    test('months, ranges, URLs and lengths are checked', () {
      expect(
        item(EntitySection.experience, {
          'start_month': '2023-13',
        }).problems()['start_month'],
        FieldProblem.invalidMonth,
      );
      expect(
        item(EntitySection.education, {
          'start_month': '2023-05',
          'end_month': '2022-01',
        }).problems()['end_month'],
        FieldProblem.endBeforeStart,
      );
      // A current role ignores a stale end month.
      expect(
        item(EntitySection.education, {
          'start_month': '2023-05',
          'end_month': '2022-01',
          'is_current': true,
        }).problems(),
        isEmpty,
      );
      expect(
        item(EntitySection.project, {'url': 'http://x.com'}).problems()['url'],
        FieldProblem.invalidUrl,
      );
      expect(
        item(EntitySection.skill, {'name': 'a' * 101}).problems()['name'],
        FieldProblem.tooLong,
      );
      expect(
        item(EntitySection.project, {
          'technologies': ['a' * 101],
        }).problems()['technologies'],
        FieldProblem.tooLong,
      );
    });

    test('skills and languages require their identifying values', () {
      expect(
        item(EntitySection.skill, {'name': '  '}).problems()['name'],
        FieldProblem.required,
      );
      expect(
        item(EntitySection.language, {
          'name': 'Arabic',
          'proficiency': 'EXPERT',
        }).problems()['proficiency'],
        FieldProblem.required,
      );
      expect(
        item(EntitySection.language, {
          'name': 'Arabic',
          'proficiency': 'NATIVE',
        }).problems(),
        isEmpty,
      );
    });

    test('payload trims, normalizes URLs and clears end when current', () {
      final payload = item(EntitySection.experience, {
        'job_title': '  Dev  ',
        'location': '   ',
        'start_month': '2022-03',
        'end_month': '2023-01',
        'is_current': true,
      }).payload();
      expect(payload['id'], 'id-1');
      expect(payload['job_title'], 'Dev');
      expect(payload['location'], isNull);
      expect(payload['end_month'], isNull);
      expect(payload['is_current'], true);
      final project = item(EntitySection.project, {
        'url': 'example.com',
        'technologies': [' Dart ', '', 'Flutter'],
      }).payload();
      expect(project['url'], 'https://example.com');
      expect(project['technologies'], ['Dart', 'Flutter']);
    });

    test('normalized names match server duplicate rules', () {
      expect(nameKey('  Flutter   Dev '), nameKey('flutter dev'));
    });
  });

  group('auth errors map to specific notices', () {
    AuthNoticeKind map(String code, {String message = 'x', String? status}) =>
        authNoticeFor(AuthException(message, code: code, statusCode: status));

    test('provider codes', () {
      expect(map('over_email_send_rate_limit'), AuthNoticeKind.rateLimited);
      expect(map('', status: '429'), AuthNoticeKind.rateLimited);
      expect(map('email_not_confirmed'), AuthNoticeKind.notConfirmed);
      expect(map('invalid_credentials'), AuthNoticeKind.invalidCredentials);
      expect(
        map('', message: 'Invalid login credentials'),
        AuthNoticeKind.invalidCredentials,
      );
      expect(map('weak_password'), AuthNoticeKind.weakPassword);
      expect(map('email_address_invalid'), AuthNoticeKind.invalidEmail);
      expect(map('user_already_exists'), AuthNoticeKind.userExists);
      expect(map('something_new'), AuthNoticeKind.failure);
    });

    test('network failures and unknown errors', () {
      expect(
        authNoticeFor(const SocketException('offline')),
        AuthNoticeKind.network,
      );
      expect(
        authNoticeFor(const FormatException('bad')),
        AuthNoticeKind.failure,
      );
    });
  });
}
