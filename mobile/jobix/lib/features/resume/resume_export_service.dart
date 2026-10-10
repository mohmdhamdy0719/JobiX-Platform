import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers.dart';

class ExportFailure implements Exception {
  const ExportFailure(this.code, {this.retryAfterSeconds});
  final String code;
  final int? retryAfterSeconds;
}

String exportDisplayKey(String actor, String job) =>
    'resume:$actor:job:$job:display';

final resumeExportServiceProvider = FutureProvider<ResumeExportService>(
  (ref) async =>
      ResumeExportService(await ref.watch(supabaseClientProvider.future)),
);

/// No client balance mutation, stored signed URL or alternate export pathway.
class ResumeExportService {
  ResumeExportService(this.client);
  final SupabaseClient client;

  /// Supplemental frozen configuration only, never status, cost, or entitlement.
  /// Missing local metadata must not block essential status/download reads.
  Future<Map<String, dynamic>> withDisplay(
    Map<String, dynamic> job,
    Future<String?> Function(String) readSetting,
  ) async {
    final actor = client.auth.currentUser?.id;
    if (actor == null) throw const ExportFailure('AUTH_REQUIRED');
    Map<String, dynamic> display = {};
    try {
      final raw = await readSetting(
        exportDisplayKey(actor, job['id'].toString()),
      );
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['profile_id'] == job['profile_id']) {
          display = {
            for (final key in ['language', 'template'])
              if (decoded[key] is String) key: decoded[key],
          };
        }
      }
    } catch (_) {
      // UI-only metadata is optional; no fallback admission or synthetic job.
    }
    if (client.auth.currentUser?.id != actor) {
      throw const ExportFailure('AUTH_REQUIRED');
    }
    return {...display, ...job};
  }

  Future<Map<String, dynamic>> call(
    String action,
    Map<String, dynamic> command,
  ) async {
    final actor = client.auth.currentUser?.id;
    if (actor == null) throw const ExportFailure('AUTH_REQUIRED');
    late FunctionResponse response;
    try {
      response = await client.functions
          .invoke('resume-export', body: {'action': action, 'command': command})
          .timeout(const Duration(seconds: 50));
    } on FunctionException catch (error) {
      throw _failure(error.details);
    }
    if (client.auth.currentUser?.id != actor) {
      throw const ExportFailure('AUTH_REQUIRED');
    }
    final envelope = Map<String, dynamic>.from(response.data as Map);
    if (envelope['error'] != null) throw _failure(envelope);
    return Map<String, dynamic>.from(envelope['data'] as Map);
  }

  ExportFailure _failure(dynamic details) {
    final failure = details is Map && details['error'] is Map
        ? details['error'] as Map
        : const {};
    final retry = failure['retry_after_seconds'];
    return ExportFailure(
      failure['code'] is String
          ? failure['code'] as String
          : 'SERVICE_UNAVAILABLE',
      retryAfterSeconds: retry is int && retry > 0 ? retry : null,
    );
  }

  Future<bool> download(String id) async {
    final actor = client.auth.currentUser?.id;
    final result = await call('download', {'export_id': id});
    final uri = Uri.parse(result['url'] as String);
    if (uri.scheme != 'https' || uri.host != 'storage.googleapis.com') {
      throw const ExportFailure('FORBIDDEN');
    }
    final http = HttpClient();
    try {
      final request = await http.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200) {
        throw const ExportFailure('EXPORT_NOT_READY');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      if (client.auth.currentUser?.id != actor) {
        throw const ExportFailure('AUTH_REQUIRED');
      }
      return await const MethodChannel('jobix/pdf_save').invokeMethod<bool>(
            'save',
            {'bytes': builder.takeBytes(), 'name': '$id.pdf'},
          ) ==
          true;
    } finally {
      http.close(force: true);
    }
  }
}
