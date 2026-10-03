import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../core/localization/direction.dart';

class CreditBalance {
  const CreditBalance({
    required this.finalized,
    required this.reserved,
    required this.available,
    required this.version,
  });

  final int finalized, reserved, available, version;

  static int _integer(Object? value) {
    if (value is! int) {
      throw const FormatException('Non-integer authoritative credit value');
    }
    return value;
  }

  factory CreditBalance.fromJson(Map<String, dynamic> json) {
    final value = CreditBalance(
      finalized: _integer(json['finalized']),
      reserved: _integer(json['reserved']),
      available: _integer(json['available']),
      version: _integer(json['version']),
    );
    if (value.finalized < 0 ||
        value.reserved < 0 ||
        value.available < 0 ||
        value.finalized - value.reserved != value.available ||
        value.version < 1) {
      throw const FormatException('Invalid authoritative credit balance');
    }
    return value;
  }
}

class CoreSummary {
  const CoreSummary({
    required this.balance,
    required this.profiles,
    required this.slots,
  });

  final CreditBalance balance;
  final List<Map<String, dynamic>> profiles, slots;

  factory CoreSummary.fromJson(Map<String, dynamic> envelope) {
    if (envelope['state'] != 'SUCCEEDED' || envelope['error'] != null) {
      throw const FormatException('Bootstrap did not succeed');
    }
    final data = Map<String, dynamic>.from(envelope['data'] as Map);
    return CoreSummary(
      balance: CreditBalance.fromJson(
        Map<String, dynamic>.from(data['balance'] as Map),
      ),
      profiles: [
        for (final row in data['profiles'] as List)
          Map<String, dynamic>.from(row as Map),
      ],
      slots: [
        for (final row in data['slots'] as List)
          Map<String, dynamic>.from(row as Map),
      ],
    );
  }
}

class CreditHistory {
  const CreditHistory({required this.items, this.nextCursor});
  final List<Map<String, dynamic>> items;
  final String? nextCursor;

  factory CreditHistory.fromJson(Map<String, dynamic> json) => CreditHistory(
    items: [
      for (final row in json['items'] as List)
        Map<String, dynamic>.from(row as Map),
    ],
    nextCursor: json['next_cursor'] as String?,
  );
}

abstract interface class CoreApi {
  Future<CoreSummary> bootstrap(String locale);
  Future<CreditHistory> transactions({String? cursor});
}

class SupabaseCoreApi implements CoreApi {
  SupabaseCoreApi(this.client, this.appVersion);
  final SupabaseClient client;
  final String appVersion;

  Future<Map<String, dynamic>> _call(
    String operation,
    Map<String, dynamic> params,
  ) async {
    final user = client.auth.currentUser?.id;
    if (user == null) throw StateError('AUTH_REQUIRED');
    final result = await client
        .rpc(operation, params: params)
        .timeout(const Duration(seconds: 15));
    if (client.auth.currentUser?.id != user) {
      throw StateError('AUTH_REQUIRED');
    }
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<CoreSummary> bootstrap(String locale) async => CoreSummary.fromJson(
    await _call('app_bootstrap', {
      'app_version': appVersion,
      'app_locale': locale,
    }),
  );

  @override
  Future<CreditHistory> transactions({String? cursor}) async =>
      CreditHistory.fromJson(
        await _call('credit_transactions_page', {
          'page_size': 25,
          'page_cursor': cursor,
        }),
      );
}

final coreApiProvider = FutureProvider.autoDispose<CoreApi>((ref) async {
  // Recreate the adapter on session changes; don't carry account data across
  // sign-out or a different authenticated identity.
  ref.watch(authSessionProvider);
  final client = await ref.watch(supabaseClientProvider.future);
  return SupabaseCoreApi(client, ref.read(appConfigProvider).appVersion);
});

final coreSummaryProvider = FutureProvider.autoDispose<CoreSummary>((
  ref,
) async {
  final preference = await ref.watch(localeProvider.future);
  final locale = resolveLocale(
    WidgetsBinding.instance.platformDispatcher.locale,
    preference,
  );
  final api = await ref.watch(coreApiProvider.future);
  return api.bootstrap(locale.languageCode);
});
