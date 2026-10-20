import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers.dart';

class ExportFailure implements Exception {
  const ExportFailure(
    this.code, {
    this.retryAfterSeconds,
    this.stage,
    this.httpStatus,
    this.receivedBytes,
    this.expectedBytes,
    this.exceptionType,
    this.saveDiagnosticJson,
  });
  final String code;
  final int? retryAfterSeconds;
  final String? stage;
  final int? httpStatus;
  final int? receivedBytes;
  final int? expectedBytes;
  final String? exceptionType;
  final String? saveDiagnosticJson;
}

typedef DownloadDiagnosticSink = void Function(Map<String, Object?> event);

class _DownloadDiagnostic {
  const _DownloadDiagnostic({
    required this.attemptId,
    required this.attempt,
    required this.stage,
    required this.outcome,
    required this.elapsedMs,
    required this.stageElapsedMs,
    this.httpStatus,
    this.expectedBytes,
    this.declaredBytes,
    this.receivedBytes,
    this.finalSizeBytes,
    this.saveResultType,
    this.saveStage,
    this.destinationSelected,
    this.uriReturned,
    this.streamOpened,
    this.writeCompleted,
    this.streamClosed,
    this.bytesWritten,
    this.finalSizeAvailable,
    this.exceptionType,
  });

  final String attemptId;
  final int attempt;
  final String stage;
  final String outcome;
  final int elapsedMs;
  final int stageElapsedMs;
  final int? httpStatus;
  final int? expectedBytes;
  final int? declaredBytes;
  final int? receivedBytes;
  final int? finalSizeBytes;
  final String? saveResultType;
  final String? saveStage;
  final bool? destinationSelected;
  final bool? uriReturned;
  final bool? streamOpened;
  final bool? writeCompleted;
  final bool? streamClosed;
  final int? bytesWritten;
  final bool? finalSizeAvailable;
  final String? exceptionType;

  Map<String, Object?> toSafeMap() => {
    'attempt_id': attemptId,
    'attempt': attempt,
    'stage': stage,
    'outcome': outcome,
    'elapsed_ms': elapsedMs,
    'stage_elapsed_ms': stageElapsedMs,
    if (httpStatus != null) 'http_status': httpStatus,
    if (expectedBytes != null) 'expected_bytes': expectedBytes,
    if (declaredBytes != null) 'declared_bytes': declaredBytes,
    if (receivedBytes != null) 'received_bytes': receivedBytes,
    if (finalSizeBytes != null) 'final_size_bytes': finalSizeBytes,
    if (saveResultType != null) 'save_result_type': saveResultType,
    if (saveStage != null) 'save_stage': saveStage,
    if (destinationSelected != null)
      'destination_selected': destinationSelected,
    if (uriReturned != null) 'uri_returned': uriReturned,
    if (streamOpened != null) 'stream_opened': streamOpened,
    if (writeCompleted != null) 'write_completed': writeCompleted,
    if (streamClosed != null) 'stream_closed': streamClosed,
    if (bytesWritten != null) 'bytes_written': bytesWritten,
    if (finalSizeAvailable != null) 'final_size_available': finalSizeAvailable,
    if (exceptionType != null) 'exception_type': exceptionType,
  };
}

int _nextDownloadAttempt = 0;

String _newDownloadCorrelationId() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

String exportDisplayKey(String actor, String job) =>
    'resume:$actor:job:$job:display';

String resumePdfFilename(String? fullName) {
  final normalized = (fullName ?? '')
      .trim()
      .replaceAll(RegExp(r'[\u0000-\u001f<>:"/\\|?*]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[. ]+$'), '')
      .trim();
  final bounded = String.fromCharCodes(normalized.runes.take(64)).trim();
  return bounded.isEmpty ? 'Resume.pdf' : '$bounded Resume.pdf';
}

final resumeExportServiceProvider = FutureProvider<ResumeExportService>(
  (ref) async =>
      ResumeExportService(await ref.watch(supabaseClientProvider.future)),
);

/// No client balance mutation, stored signed URL or alternate export pathway.
class ResumeExportService {
  ResumeExportService(this.client, {DownloadDiagnosticSink? diagnostics})
    : _diagnostics = diagnostics ?? _debugDownloadDiagnostics;

  final SupabaseClient client;
  final DownloadDiagnosticSink _diagnostics;

  static void _debugDownloadDiagnostics(Map<String, Object?> event) {
    if (kDebugMode) {
      debugPrint('JOBIX_PDF_DOWNLOAD ${jsonEncode(event)}');
    }
  }

  void _recordDownloadDiagnostic({
    required String attemptId,
    required int attempt,
    required String stage,
    required String outcome,
    required Stopwatch overall,
    required Stopwatch stageClock,
    int? httpStatus,
    int? expectedBytes,
    int? declaredBytes,
    int? receivedBytes,
    int? finalSizeBytes,
    String? saveResultType,
    String? saveStage,
    bool? destinationSelected,
    bool? uriReturned,
    bool? streamOpened,
    bool? writeCompleted,
    bool? streamClosed,
    int? bytesWritten,
    bool? finalSizeAvailable,
    Object? error,
    String? exceptionType,
  }) {
    try {
      final rawExceptionType = exceptionType ?? error?.runtimeType.toString();
      final safeExceptionType =
          rawExceptionType != null &&
              RegExp(r'^[A-Za-z0-9_$]{1,64}$').hasMatch(rawExceptionType)
          ? rawExceptionType
          : null;
      _diagnostics(
        _DownloadDiagnostic(
          attemptId: attemptId,
          attempt: attempt,
          stage: stage,
          outcome: outcome,
          elapsedMs: overall.elapsedMilliseconds,
          stageElapsedMs: stageClock.elapsedMilliseconds,
          httpStatus: httpStatus,
          expectedBytes: expectedBytes,
          declaredBytes: declaredBytes,
          receivedBytes: receivedBytes,
          finalSizeBytes: finalSizeBytes,
          saveResultType: saveResultType,
          saveStage: saveStage,
          destinationSelected: destinationSelected,
          uriReturned: uriReturned,
          streamOpened: streamOpened,
          writeCompleted: writeCompleted,
          streamClosed: streamClosed,
          bytesWritten: bytesWritten,
          finalSizeAvailable: finalSizeAvailable,
          exceptionType: safeExceptionType,
        ).toSafeMap(),
      );
    } catch (_) {
      // Diagnostics must never affect a download.
    }
  }

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

  Future<bool> download(
    String id, {
    String? suggestedName,
    int? expectedBytes,
  }) async {
    final actor = client.auth.currentUser?.id;
    final attempt = ++_nextDownloadAttempt;
    final attemptId = _newDownloadCorrelationId();
    final overall = Stopwatch()..start();
    var stage = 'download_link';
    var stageClock = Stopwatch()..start();
    int? httpStatus;
    int? declaredBytes;
    int? finalFileSizeBytes;
    String? saveResultType;
    String? saveStage;
    bool? destinationSelected;
    bool? uriReturned;
    bool? streamOpened;
    bool? writeCompleted;
    bool? streamClosed;
    int? bytesWritten;
    bool? finalSizeAvailable;
    String? saveExceptionType;
    int? nativeSubmittedBytes;
    var receivedBytes = 0;
    final expected = expectedBytes != null && expectedBytes > 0
        ? expectedBytes
        : null;
    HttpClient? http;

    void record(String outcome, {Object? error, int? finalSizeBytes}) {
      _recordDownloadDiagnostic(
        attemptId: attemptId,
        attempt: attempt,
        stage: stage,
        outcome: outcome,
        overall: overall,
        stageClock: stageClock,
        httpStatus: httpStatus,
        expectedBytes: expected,
        declaredBytes: declaredBytes,
        receivedBytes: receivedBytes,
        finalSizeBytes: finalSizeBytes ?? finalFileSizeBytes,
        saveResultType: saveResultType,
        saveStage: saveStage,
        destinationSelected: destinationSelected,
        uriReturned: uriReturned,
        streamOpened: streamOpened,
        writeCompleted: writeCompleted,
        streamClosed: streamClosed,
        bytesWritten: bytesWritten,
        finalSizeAvailable: finalSizeAvailable,
        error: error,
      );
    }

    String? buildSafeSaveDiagnostic({
      required String outcome,
      String? exceptionType,
    }) {
      if (!kDebugMode || stage != 'android_save') return null;
      final rawExceptionType = exceptionType ?? saveExceptionType;
      final safeExceptionType =
          rawExceptionType != null &&
              RegExp(r'^[A-Za-z0-9_$]{1,64}$').hasMatch(rawExceptionType)
          ? rawExceptionType
          : null;
      return jsonEncode({
        'version': 1,
        'attempt_id': attemptId,
        'download_stage': 'android_save',
        'outcome': outcome,
        'method_result_type': saveResultType ?? 'unavailable',
        'save_stage': saveStage ?? 'unknown',
        'destination_selected': destinationSelected,
        'uri_returned': uriReturned,
        'stream_opened': streamOpened,
        'write_completed': writeCompleted,
        'stream_closed': streamClosed,
        if (nativeSubmittedBytes != null)
          'submitted_bytes': nativeSubmittedBytes,
        if (bytesWritten != null) 'bytes_written': bytesWritten,
        'expected_bytes': expected,
        'downloaded_bytes': receivedBytes,
        'final_size_available': finalSizeAvailable,
        if (finalFileSizeBytes != null) 'final_size_bytes': finalFileSizeBytes,
        if (httpStatus != null) 'download_http_status': httpStatus,
        if (safeExceptionType != null) 'exception_type': safeExceptionType,
      });
    }

    void enterStage(String next) {
      record('complete');
      stage = next;
      stageClock = Stopwatch()..start();
      record('started');
    }

    ExportFailure classify(Object error) {
      if (error is ExportFailure) {
        final failureStage = error.stage ?? stage;
        return ExportFailure(
          error.code,
          retryAfterSeconds: error.retryAfterSeconds,
          stage: failureStage,
          httpStatus: error.httpStatus ?? httpStatus,
          receivedBytes: error.receivedBytes ?? receivedBytes,
          expectedBytes: error.expectedBytes ?? expected,
          exceptionType: error.exceptionType,
          saveDiagnosticJson:
              error.saveDiagnosticJson ??
              (failureStage == 'android_save'
                  ? buildSafeSaveDiagnostic(
                      outcome: error.code,
                      exceptionType: error.exceptionType,
                    )
                  : null),
        );
      }
      if (error is TimeoutException) {
        return ExportFailure(
          'DOWNLOAD_TIMEOUT',
          stage: stage,
          httpStatus: httpStatus,
          receivedBytes: receivedBytes,
          expectedBytes: expected,
          exceptionType: error.runtimeType.toString(),
          saveDiagnosticJson: stage == 'android_save'
              ? buildSafeSaveDiagnostic(
                  outcome: 'DOWNLOAD_TIMEOUT',
                  exceptionType: error.runtimeType.toString(),
                )
              : null,
        );
      }
      if (error is SocketException ||
          error is HandshakeException ||
          error is HttpException) {
        return ExportFailure(
          'DOWNLOAD_NETWORK_ERROR',
          stage: stage,
          httpStatus: httpStatus,
          receivedBytes: receivedBytes,
          expectedBytes: expected,
          exceptionType: error.runtimeType.toString(),
          saveDiagnosticJson: stage == 'android_save'
              ? buildSafeSaveDiagnostic(
                  outcome: 'DOWNLOAD_NETWORK_ERROR',
                  exceptionType: error.runtimeType.toString(),
                )
              : null,
        );
      }
      if (error is PlatformException) {
        return ExportFailure(
          'DOWNLOAD_SAVE_ERROR',
          stage: stage,
          receivedBytes: receivedBytes,
          expectedBytes: expected,
          exceptionType: error.runtimeType.toString(),
          saveDiagnosticJson: stage == 'android_save'
              ? buildSafeSaveDiagnostic(
                  outcome: 'DOWNLOAD_SAVE_ERROR',
                  exceptionType: error.runtimeType.toString(),
                )
              : null,
        );
      }
      return ExportFailure(
        'DOWNLOAD_FAILED',
        stage: stage,
        httpStatus: httpStatus,
        receivedBytes: receivedBytes,
        expectedBytes: expected,
        exceptionType: error.runtimeType.toString(),
        saveDiagnosticJson: stage == 'android_save'
            ? buildSafeSaveDiagnostic(
                outcome: 'DOWNLOAD_FAILED',
                exceptionType: error.runtimeType.toString(),
              )
            : null,
      );
    }

    try {
      record('started');
      final result = await call('download', {'export_id': id});
      enterStage('url_validation');
      final rawUrl = result['url'];
      if (rawUrl is! String) {
        throw const ExportFailure('DOWNLOAD_LINK_INVALID');
      }
      final uri = Uri.tryParse(rawUrl);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'storage.googleapis.com') {
        throw const ExportFailure('FORBIDDEN');
      }

      enterStage('storage_response');
      http = HttpClient();
      final request = await http.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      httpStatus = response.statusCode;
      declaredBytes = response.contentLength >= 0
          ? response.contentLength
          : null;
      record('response_received');
      if (response.statusCode != 200) {
        throw ExportFailure(
          'DOWNLOAD_HTTP_ERROR',
          httpStatus: response.statusCode,
        );
      }

      enterStage('storage_body');
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
        receivedBytes += chunk.length;
      }

      final bytes = builder.takeBytes();
      enterStage('pdf_validation');
      if (expected != null && bytes.length != expected) {
        throw ExportFailure(
          'DOWNLOAD_SIZE_MISMATCH',
          receivedBytes: bytes.length,
          expectedBytes: expected,
        );
      }
      if (declaredBytes != null && bytes.length != declaredBytes) {
        throw ExportFailure(
          'DOWNLOAD_SIZE_MISMATCH',
          receivedBytes: bytes.length,
          expectedBytes: expected ?? declaredBytes,
        );
      }
      if (bytes.length < 5 ||
          bytes[0] != 0x25 ||
          bytes[1] != 0x50 ||
          bytes[2] != 0x44 ||
          bytes[3] != 0x46 ||
          bytes[4] != 0x2d) {
        throw ExportFailure(
          'DOWNLOAD_INVALID_PDF',
          receivedBytes: bytes.length,
          expectedBytes: expected,
        );
      }

      if (client.auth.currentUser?.id != actor) {
        throw const ExportFailure('AUTH_REQUIRED');
      }

      enterStage('android_save');
      final rawSave = await const MethodChannel('jobix/pdf_save')
          .invokeMethod<Object?>('save', {
            'bytes': bytes,
            'name': resumePdfFilename(suggestedName),
          });
      if (rawSave is Map) {
        saveResultType = 'map';
      } else if (rawSave is bool) {
        saveResultType = 'bool';
      } else if (rawSave == null) {
        saveResultType = 'null';
      } else {
        saveResultType = 'other';
      }
      if (rawSave is! Map) {
        throw const ExportFailure('DOWNLOAD_SAVE_ERROR');
      }
      final saveResult = rawSave;
      final saved = saveResult['saved'] == true;
      final finalSize = saveResult['final_size_bytes'];
      finalFileSizeBytes = finalSize is int ? finalSize : null;
      final submittedValue = saveResult['submitted_bytes'];
      final submittedBytes = submittedValue is int ? submittedValue : null;
      nativeSubmittedBytes = submittedBytes;
      final writtenValue = saveResult['bytes_written'];
      bytesWritten = writtenValue is int ? writtenValue : null;
      destinationSelected = saveResult['destination_selected'] is bool
          ? saveResult['destination_selected'] as bool
          : null;
      uriReturned = saveResult['uri_returned'] is bool
          ? saveResult['uri_returned'] as bool
          : null;
      streamOpened = saveResult['stream_opened'] is bool
          ? saveResult['stream_opened'] as bool
          : null;
      writeCompleted = saveResult['write_completed'] is bool
          ? saveResult['write_completed'] as bool
          : null;
      streamClosed = saveResult['stream_closed'] is bool
          ? saveResult['stream_closed'] as bool
          : null;
      finalSizeAvailable = saveResult['final_size_available'] is bool
          ? saveResult['final_size_available'] as bool
          : null;
      final rawSaveStage = saveResult['stage'];
      final allowedSaveStages = {
        'saved',
        'cancelled',
        'uri_missing',
        'output_unavailable',
        'size_mismatch',
        'write_failed',
        'picker_start_failed',
        'picker_result_failed',
        'activity_destroyed',
      };
      final nativeSaveStage =
          rawSaveStage is String && allowedSaveStages.contains(rawSaveStage)
          ? rawSaveStage
          : null;
      saveStage = nativeSaveStage;
      final rawExceptionType = saveResult['exception_type'];
      final nativeExceptionType =
          rawExceptionType is String &&
              RegExp(r'^[A-Za-z0-9_$]{1,64}$').hasMatch(rawExceptionType)
          ? rawExceptionType
          : null;
      saveExceptionType = nativeExceptionType;
      if (!saved &&
          nativeSaveStage == 'cancelled' &&
          streamOpened != true &&
          writeCompleted != true &&
          streamClosed != true &&
          (bytesWritten == null || bytesWritten == 0) &&
          nativeExceptionType == null) {
        _recordDownloadDiagnostic(
          attemptId: attemptId,
          attempt: attempt,
          stage: 'android_save',
          outcome: 'user_cancelled',
          overall: overall,
          stageClock: stageClock,
          httpStatus: httpStatus,
          expectedBytes: expected,
          declaredBytes: declaredBytes,
          receivedBytes: bytes.length,
          saveResultType: saveResultType,
          saveStage: nativeSaveStage,
          destinationSelected: destinationSelected,
          uriReturned: uriReturned,
          streamOpened: streamOpened,
          writeCompleted: writeCompleted,
          streamClosed: streamClosed,
          bytesWritten: bytesWritten,
          finalSizeAvailable: finalSizeAvailable,
        );
        return false;
      }
      if (!saved) {
        if (nativeSaveStage == 'size_mismatch' &&
            finalSizeAvailable == true &&
            finalFileSizeBytes != null) {
          throw ExportFailure(
            'DOWNLOAD_SAVE_SIZE_MISMATCH',
            stage: stage,
            receivedBytes: finalFileSizeBytes,
            expectedBytes: bytes.length,
          );
        }
        throw ExportFailure(
          nativeSaveStage == 'cancelled'
              ? 'DOWNLOAD_SAVE_NOT_CONFIRMED'
              : 'DOWNLOAD_SAVE_ERROR',
          stage: stage,
          receivedBytes: bytes.length,
          expectedBytes: expected,
          exceptionType: nativeExceptionType,
        );
      }
      if (saveStage != 'saved' ||
          destinationSelected != true ||
          uriReturned != true ||
          streamOpened != true ||
          writeCompleted != true ||
          streamClosed != true ||
          submittedBytes != bytes.length ||
          bytesWritten != bytes.length ||
          finalSizeAvailable == null) {
        throw ExportFailure(
          'DOWNLOAD_SAVE_ERROR',
          stage: stage,
          receivedBytes: bytesWritten,
          expectedBytes: bytes.length,
          exceptionType: nativeExceptionType,
        );
      }
      if (finalSizeAvailable == true && finalFileSizeBytes == null) {
        throw ExportFailure(
          'DOWNLOAD_SAVE_ERROR',
          stage: stage,
          receivedBytes: bytesWritten,
          expectedBytes: bytes.length,
          exceptionType: nativeExceptionType,
        );
      }
      if (finalSizeAvailable == false &&
          saveResult.containsKey('final_size_bytes')) {
        throw ExportFailure(
          'DOWNLOAD_SAVE_ERROR',
          stage: stage,
          receivedBytes: bytesWritten,
          expectedBytes: bytes.length,
          exceptionType: nativeExceptionType,
        );
      }
      if (submittedBytes != bytes.length || bytesWritten != bytes.length) {
        throw ExportFailure(
          'DOWNLOAD_SAVE_SIZE_MISMATCH',
          stage: stage,
          receivedBytes: bytesWritten,
          expectedBytes: bytes.length,
        );
      }
      if (finalSizeAvailable == true && finalFileSizeBytes != bytes.length) {
        throw ExportFailure(
          'DOWNLOAD_SAVE_SIZE_MISMATCH',
          stage: stage,
          receivedBytes: finalFileSizeBytes,
          expectedBytes: bytes.length,
        );
      }
      _recordDownloadDiagnostic(
        attemptId: attemptId,
        attempt: attempt,
        stage: stage,
        outcome: 'complete',
        overall: overall,
        stageClock: stageClock,
        expectedBytes: expected,
        declaredBytes: declaredBytes,
        receivedBytes: bytes.length,
        finalSizeBytes: finalFileSizeBytes,
        saveResultType: saveResultType,
        saveStage: saveStage,
        destinationSelected: destinationSelected,
        uriReturned: uriReturned,
        streamOpened: streamOpened,
        writeCompleted: writeCompleted,
        streamClosed: streamClosed,
        bytesWritten: bytesWritten,
        finalSizeAvailable: finalSizeAvailable,
      );
      return true;
    } catch (error) {
      final failure = classify(error);
      _recordDownloadDiagnostic(
        attemptId: attemptId,
        attempt: attempt,
        stage: failure.stage ?? stage,
        outcome: failure.code,
        overall: overall,
        stageClock: stageClock,
        httpStatus: failure.httpStatus ?? httpStatus,
        expectedBytes: failure.expectedBytes ?? expected,
        declaredBytes: declaredBytes,
        receivedBytes: failure.receivedBytes ?? receivedBytes,
        finalSizeBytes: finalFileSizeBytes,
        saveResultType: saveResultType,
        saveStage: saveStage,
        destinationSelected: destinationSelected,
        uriReturned: uriReturned,
        streamOpened: streamOpened,
        writeCompleted: writeCompleted,
        streamClosed: streamClosed,
        bytesWritten: bytesWritten,
        finalSizeAvailable: finalSizeAvailable,
        exceptionType:
            failure.exceptionType ??
            saveExceptionType ??
            (error is ExportFailure ? null : error.runtimeType.toString()),
      );
      throw failure;
    } finally {
      http?.close(force: true);
    }
  }
}

String? resumeDownloadFailureMessage(
  ExportFailure error,
  String Function(String, String) localize,
) {
  if (error.stage == null) return null;
  return switch (error.code) {
    'EXPORT_NOT_READY' => localize(
      'This PDF is not ready to download. No new export or Credit charge was created.',
      'ملف PDF هذا غير جاهز للتنزيل. لم يتم إنشاء تصدير جديد أو خصم أرصدة.',
    ),
    'DOWNLOAD_HTTP_ERROR' => localize(
      'The file server returned HTTP ${error.httpStatus ?? 'unknown'}. Your completed export and Credits are unchanged; retry the download later.',
      'أعاد خادم الملف HTTP ${error.httpStatus ?? 'غير معروف'}. ملفك المكتمل وأرصدتك لم يتغيرا؛ أعد محاولة التنزيل لاحقًا.',
    ),
    'DOWNLOAD_TIMEOUT' || 'DOWNLOAD_NETWORK_ERROR' => localize(
      'The PDF transfer did not complete. Your existing export and Credits are unchanged; check your connection and retry.',
      'لم يكتمل نقل ملف PDF. ملفك الحالي وأرصدتك لم يتغيرا؛ تحقق من الاتصال ثم أعد المحاولة.',
    ),
    'DOWNLOAD_SIZE_MISMATCH' || 'DOWNLOAD_INVALID_PDF' => localize(
      'The downloaded file was incomplete or not a valid PDF. It was not saved, and no Credits were charged. Retry the download later.',
      'الملف الذي تم تنزيله غير مكتمل أو ليس ملف PDF صالحًا. لم يتم حفظه ولم يتم خصم أرصدة؛ أعد المحاولة لاحقًا.',
    ),
    'DOWNLOAD_SAVE_NOT_CONFIRMED' => localize(
      'Android did not confirm saving the PDF. If you cancelled the file picker, choose a location and complete the save. No Credits were charged.',
      'لم يؤكد Android حفظ ملف PDF. إذا ألغيت نافذة اختيار الموقع، اختر موقعًا وأكمل الحفظ. لم يتم خصم أرصدة.',
    ),
    'DOWNLOAD_SAVE_ERROR' || 'DOWNLOAD_SAVE_SIZE_MISMATCH' => localize(
      'Android could not confirm a complete PDF save. Check device storage and retry. Your existing export and Credits are unchanged.',
      'تعذر على Android تأكيد حفظ ملف PDF كامل. تحقق من مساحة الجهاز ثم أعد المحاولة. ملفك الحالي وأرصدتك لم يتغيرا.',
    ),
    'DOWNLOAD_FAILED' || 'DOWNLOAD_LINK_INVALID' || 'FORBIDDEN' => localize(
      'The download could not be completed. Your existing export and Credits are unchanged; try downloading again later.',
      'تعذر إكمال التنزيل. ملفك الحالي وأرصدتك لم يتغيرا؛ أعد محاولة التنزيل لاحقًا.',
    ),
    _ => null,
  };
}
