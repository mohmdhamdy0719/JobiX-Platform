import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../auth/auth_controller.dart';

/// Read-only server allocation. This model never calculates, increments,
/// reserves, consumes, or grants generations on the client.
class AiAllowance {
  const AiAllowance({
    required this.used,
    required this.limit,
    required this.reserved,
    required this.bucket,
    required this.availableFrom,
    required this.generationEnabled,
  });
  final int used, limit, reserved;
  final String bucket;

  /// Server Cairo-calendar date, deliberately not a device-local timestamp.
  final DateTime availableFrom;
  final bool generationEnabled;

  factory AiAllowance.fromJson(Map response) {
    int integer(String key) {
      final value = response[key];
      if (value is! int || value < 0) {
        throw const FormatException('Allowance unavailable');
      }
      return value;
    }

    final date = response['available_from'];
    final parsed = date is String ? DateTime.tryParse(date) : null;
    final bucket = response['bucket'];
    if (parsed == null ||
        bucket is! String ||
        !{'FIRST_PROFILE', 'DAILY'}.contains(bucket) ||
        response['generation_enabled'] is! bool) {
      throw const FormatException('Allowance unavailable');
    }
    return AiAllowance(
      used: integer('used'),
      limit: integer('limit'),
      reserved: integer('reserved'),
      bucket: bucket,
      availableFrom: DateTime(parsed.year, parsed.month, parsed.day),
      generationEnabled: response['generation_enabled'] as bool,
    );
  }
}

final aiAllowanceProvider = FutureProvider.autoDispose<AiAllowance>((
  ref,
) async {
  // Session changes invalidate any previous account's allocation.
  ref.watch(authSessionProvider);
  await ref.watch(firstProfileProvider.future);
  final client = await ref.watch(supabaseClientProvider.future);
  final owner = client.auth.currentUser?.id;
  if (owner == null) throw StateError('Allowance unavailable');
  final response = await client
      .rpc('ai_allowance')
      .timeout(const Duration(seconds: 15));
  if (client.auth.currentUser?.id != owner || response is! Map) {
    throw StateError('Allowance unavailable');
  }
  return AiAllowance.fromJson(response);
});
