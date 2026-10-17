import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/jobix_dialog.dart';
import '../../core/providers.dart';
import '../core_mvp/core_api.dart';
import '../../l10n/app_localizations.dart';
import '../career_profile/career_profile.dart';
import '../auth/auth_controller.dart';
import 'resume_document.dart';
import 'resume_experience_shared.dart';
import 'resume_experience_widgets.dart';
import 'resume_export_service.dart';
import 'resume_preview_snapshot.dart';
import 'resume_credit_dialog.dart';
import 'resume_layout.dart';
export 'resume_export_service.dart' show ExportFailure;

/// Rollout is closed by default; this widget never grants/debits Credits.
class ResumeExportPanel extends ConsumerStatefulWidget {
  const ResumeExportPanel({
    super.key,
    required this.profileId,
    required this.showDocument,
    required this.canPrepare,
    this.rebuildLocalDocument,
    this.initialDocument,
    this.experience = false,
    this.historyOnly = false,
    this.onOperation,
  });
  final String profileId;
  final bool canPrepare;
  final Future<Map<String, dynamic>> Function()? rebuildLocalDocument;
  final Map<String, dynamic>? initialDocument;
  final bool experience, historyOnly;
  final ValueChanged<String>? onOperation;
  final Future<void> Function(Map<String, dynamic>) showDocument;
  @override
  ResumeExportPanelState createState() => ResumeExportPanelState();
}

class ResumeExportPanelState extends ConsumerState<ResumeExportPanel> {
  static const enabled = bool.fromEnvironment('JOBIX_ENABLE_PDF_EXPORT');
  Map<String, dynamic>? document;
  List<Map<String, dynamic>> jobs = [];
  String? pending, message, cursor;
  bool busy = false, failureDialogOpen = false;
  bool historyLoadFailed = false;
  final Set<String> downloadingExportIds = {};
  bool get savingPdf => downloadingExportIds.isNotEmpty;
  bool get ar => Localizations.localeOf(context).languageCode == 'ar';
  String t(String en, String arabic) => ar ? arabic : en;
  bool get creationEnabled => enabled && pending == null;
  Future<void> showLocalDocument(Map<String, dynamic> localDocument) async {
    if (!mounted) return;
    setState(() => document = localDocument);
    await widget.showDocument(localDocument);
  }

  void clearLocalDocument() {
    if (mounted) setState(() => document = null);
  }

  /// Fetches the current server document and exports only if the saved source
  /// and configuration still match the version shown in Preview.
  Future<Map<String, dynamic>?> createPdf(
    Map<String, dynamic> reviewedDocument,
  ) async {
    Map<String, dynamic>? replacement;
    await _run(() async {
      if (!enabled || (reviewedDocument['issues'] as List? ?? []).isNotEmpty) {
        return;
      }
      if (pending != null) throw const ExportFailure('EXPORT_IN_PROGRESS');
      final client = await ref.read(supabaseClientProvider.future);
      final actor = client.auth.currentUser?.id;
      if (actor == null) throw const ExportFailure('AUTH_REQUIRED');
      if (!await _ensureCurrentCredits()) return;
      if (client.auth.currentUser?.id != actor) {
        throw const ExportFailure('AUTH_REQUIRED');
      }
      final authoritative = await _call('document', {
        'profile_id': widget.profileId,
      });
      if (client.auth.currentUser?.id != actor) {
        throw const ExportFailure('AUTH_REQUIRED');
      }
      final layout =
          (reviewedDocument['configuration'] as Map?)?['render_config_version'];
      // Older deployed canonicalizers silently ignore section_order. Never offer
      // their HTML as a valid rendering of a layout they cannot implement.
      if (layout == ResumeLayout.renderVersion &&
          !(authoritative['html'] as String? ?? '').contains(
            '<meta name="jobix-layout-version" content="1">',
          )) {
        throw const ExportFailure('RENDERER_UPDATE_REQUIRED');
      }
      final differences = reviewedResumeDifferences(
        reviewedDocument,
        authoritative,
      );
      if (differences.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            'JOBIX_EXPORT_SNAPSHOT stage=before_submit fields=${differences.join(",")}',
          );
        }
        if (mounted) setState(() => document = authoritative);
        replacement = authoritative;
        return;
      }
      if (!mounted) return;
      setState(() => document = authoritative);
      try {
        await _submit(creditsAlreadyVerified: true);
      } on ExportFailure catch (error) {
        if (error.code != 'VERSION_CONFLICT') rethrow;
        // Definitive rejection, not an ambiguous timeout. Gateway checks replay
        // first, so an already accepted same-key request returns its ACK instead.
        final current = await _call('document', {
          'profile_id': widget.profileId,
        });
        if (client.auth.currentUser?.id != actor) {
          throw const ExportFailure('AUTH_REQUIRED');
        }
        final db = await ref.read(databaseProvider.future);
        if (await db.setting(storageKey(actor)) != pending) {
          throw const ExportFailure('SERVICE_UNAVAILABLE');
        }
        await db.removeSetting(storageKey(actor));
        if (mounted) {
          setState(() {
            pending = null;
            document = current;
          });
        }
        replacement = current;
        if (kDebugMode) {
          debugPrint(
            'JOBIX_EXPORT_SNAPSHOT stage=create_rejected code=VERSION_CONFLICT',
          );
        }
      }
    }, showFailureDialog: true);
    return replacement;
  }

  @override
  void initState() {
    super.initState();
    document = widget.initialDocument;
    ref.listenManual(
      authSessionProvider.select((session) => session.valueOrNull?.user.id),
      (previous, next) {
        if (previous != null && previous != next) {
          if (mounted) {
            setState(() {
              jobs = [];
              document = null;
              pending = null;
              cursor = null;
            });
          }
        }
      },
    );
    _run(_load);
  }

  @override
  void dispose() {
    if (savingPdf) {
      const MethodChannel(
        'jobix/pdf_save',
      ).invokeMethod<void>('cancel').catchError((Object _) {});
    }
    super.dispose();
  }

  String storageKey(String user) => 'resume:$user:export:${widget.profileId}';
  Future<Map<String, dynamic>> _call(
    String action,
    Map<String, dynamic> command,
  ) async {
    final client = await ref.read(supabaseClientProvider.future);
    final user = client.auth.currentUser?.id;
    if (user == null) throw const ExportFailure('AUTH_REQUIRED');
    try {
      return await ResumeExportService(client).call(action, command);
    } finally {
      if (client.auth.currentUser?.id != user) {
        final db = await ref.read(databaseProvider.future);
        await db.removeSetting(storageKey(user));
      }
    }
  }

  Future<void> _run(
    Future<void> Function() operation, {
    bool allowWhileBusy = false,
    bool showFailureDialog = false,
  }) async {
    if (busy && !allowWhileBusy) return;
    if (mounted && !allowWhileBusy) {
      setState(() {
        busy = true;
        message = null;
      });
    }
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        final code = error is ExportFailure
            ? error.code
            : 'SERVICE_UNAVAILABLE';
        int? refreshedBalance;
        if (code == 'CREDIT_INSUFFICIENT') {
          ref.invalidate(coreSummaryProvider);
          try {
            refreshedBalance = (await ref.read(
              coreSummaryProvider.future,
            )).balance.available;
          } catch (_) {
            // The server rejection is authoritative; omit a numeric balance
            // when the separate balance refresh is unavailable.
          }
        }
        setState(() {
          final retryAfter = error is ExportFailure
              ? error.retryAfterSeconds
              : null;
          final l10n = AppLocalizations.of(context)!;
          final downloadMessage = error is ExportFailure
              ? resumeDownloadFailureMessage(error, t)
              : null;
          message = error is ResumePreviewNeedsConfirmation
              ? t(
                  'Presentation was saved, but other edits are still unsaved. Use Preview saved version to review only saved content.',
                  'تم حفظ إعدادات العرض، لكن توجد تعديلات أخرى غير محفوظة. استخدم معاينة النسخة المحفوظة لمراجعة المحتوى المحفوظ فقط.',
                )
              : error is ResumePreviewBlocked
              ? t(
                  'Presentation was saved, but the current Resume snapshot could not be rebuilt safely. Return to Preview and retry.',
                  'تم حفظ إعدادات العرض، لكن تعذّر تجهيز نسخة السيرة بأمان. ارجع إلى المعاينة وأعد المحاولة.',
                )
              : downloadMessage ??
                    switch (code) {
                      'VERSION_CONFLICT' => t(
                        'The saved Resume changed elsewhere. Open Preview to see the current saved version. No new PDF was accepted.',
                        'تغيّرت السيرة المحفوظة من مكان آخر. افتح المعاينة للاطلاع على النسخة الحالية. لم يتم قبول ملف PDF جديد.',
                      ),
                      'RENDERER_UPDATE_REQUIRED' => t(
                        'This layout needs the Development PDF service update. No export was created or charged.',
                        'يتطلب هذا التصميم تحديث خدمة PDF للتطوير. لم يتم إنشاء تصدير أو خصم رصيد.',
                      ),
                      'VALIDATION_FAILED' => t(
                        'Fix or explicitly hide invalid saved content, then review Preview.',
                        'أصلح المحتوى المحفوظ غير الصالح أو أخفه صراحةً ثم راجع المعاينة.',
                      ),
                      'CREDIT_INSUFFICIENT' => t(
                        'Not enough Credits. The server did not accept this export; no export was created or charged.',
                        'الرصيد غير كافٍ. لم يقبل الخادم هذا التصدير ولم يتم إنشاء ملف أو خصم رصيد.',
                      ),
                      'EXPORT_NOT_READY' => t(
                        'Export is disabled. No new export can be accepted.',
                        'التصدير معطّل. لا يمكن قبول تصدير جديد.',
                      ),
                      'EXPORT_EXPIRED' => t(
                        'The file expired. No automatic regeneration or charge.',
                        'انتهت صلاحية الملف. لا توجد إعادة إنشاء أو رسوم تلقائية.',
                      ),
                      'EXPORT_OBJECT_MISSING' => t(
                        'The file is unavailable. No automatic regeneration or charge.',
                        'الملف غير متاح. لا توجد إعادة إنشاء أو رسوم تلقائية.',
                      ),
                      'SERVICE_UNAVAILABLE' =>
                        l10n.exportTemporarilyUnavailable,
                      'RATE_LIMITED' =>
                        retryAfter == null
                            ? l10n.exportRateLimited
                            : l10n.exportRateLimitedRetry(retryAfter),
                      'EXPORT_IN_PROGRESS' => l10n.exportInProgress,
                      _ => t(
                        'The request could not be confirmed. It is preserved to prevent a duplicate export.',
                        'تعذّر تأكيد الطلب. تم الاحتفاظ به لمنع إنشاء تصدير مكرر.',
                      ),
                    };
        });
        if (showFailureDialog && mounted) {
          setState(() => failureDialogOpen = true);
          if (code == 'CREDIT_INSUFFICIENT' &&
              refreshedBalance != null &&
              refreshedBalance < 2) {
            final action = await showNotEnoughResumeCreditsDialog(
              context,
              availableCredits: refreshedBalance,
            );
            if (action == ResumeCreditDialogAction.reviewHistory && mounted) {
              await context.push('/credits');
              if (mounted) ref.invalidate(coreSummaryProvider);
            }
          } else {
            await showDialog<void>(
              context: context,
              builder: (dialog) => JobixAlertDialog(
                icon: Icon(
                  code == 'CREDIT_INSUFFICIENT'
                      ? Icons.account_balance_wallet_outlined
                      : Icons.error_outline,
                ),
                title: Text(
                  code == 'CREDIT_INSUFFICIENT'
                      ? t('Not enough Credits', 'الرصيد غير كافٍ')
                      : t('PDF request issue', 'مشكلة في طلب PDF'),
                ),
                content: Text(
                  message ??
                      AppLocalizations.of(
                        context,
                      )!.exportTemporarilyUnavailable,
                ),
                actions: [
                  if (code == 'CREDIT_INSUFFICIENT')
                    JobixDialogAction.secondary(
                      onPressed: () {
                        Navigator.pop(dialog);
                        context.push('/credits').whenComplete(() {
                          if (mounted) ref.invalidate(coreSummaryProvider);
                        });
                      },
                      child: Text(
                        t('Review Credit history', 'مراجعة سجل الرصيد'),
                      ),
                    ),
                  JobixDialogAction.secondary(
                    onPressed: () => Navigator.pop(dialog),
                    child: Text(
                      code == 'CREDIT_INSUFFICIENT'
                          ? t('Cancel', 'رجوع')
                          : t('Close', 'إغلاق'),
                    ),
                  ),
                ],
              ),
            );
          }
          if (mounted) {
            setState(() {
              failureDialogOpen = false;
              // Request errors are shown in the dialog for this action only,
              // not left as persistent page-level status text.
              message = null;
            });
          }
        }
      }
    } finally {
      if (mounted && !allowWhileBusy) setState(() => busy = false);
    }
  }

  Future<void> _load({bool recoverPending = true}) async {
    try {
      final client = await ref.read(supabaseClientProvider.future);
      final user = client.auth.currentUser?.id;
      if (user == null) return;
      final db = await ref.read(databaseProvider.future);
      final raw = await db.setting(storageKey(user));
      final history = await _call('history', {});
      final decorated = await Future.wait([
        for (final job in history['jobs'] as List)
          ResumeExportService(
            client,
          ).withDisplay(Map<String, dynamic>.from(job as Map), db.setting),
      ]);
      if (!mounted || client.auth.currentUser?.id != user) return;
      setState(() {
        pending = raw;
        jobs = decorated;
        cursor = history['next_cursor'] as String?;
        historyLoadFailed = false;
      });
      if (recoverPending && !widget.historyOnly && raw != null) {
        // A prior explicit request may have reached the server even if its
        // response was lost. Reuse its frozen idempotency key internally; never
        // create a second user-facing retry action.
        try {
          await _retry(internalRecovery: true);
        } catch (_) {
          // Preserve the frozen request. A later Preview entry can reconcile
          // the same key; do not allocate a new request while it is unresolved.
        }
      }
    } catch (_) {
      if (mounted) setState(() => historyLoadFailed = true);
      rethrow;
    }
  }

  Future<void> _prepare() async {
    final result = await _call('document', {'profile_id': widget.profileId});
    if (!mounted) return;
    setState(() => document = result);
    await widget.showDocument(result);
  }

  Future<void> _submit({bool creditsAlreadyVerified = false}) async {
    if (!enabled ||
        document == null ||
        pending != null ||
        (document!['issues'] as List? ?? []).isNotEmpty) {
      return;
    }
    if (!creditsAlreadyVerified && !await _ensureCurrentCredits()) return;
    // Re-read the durable request before allocating a new intent. This also
    // protects against an initial history load still in flight.
    final client = await ref.read(supabaseClientProvider.future);
    final database = await ref.read(databaseProvider.future);
    final actor = client.auth.currentUser?.id;
    if (actor == null) throw const ExportFailure('AUTH_REQUIRED');
    final frozen = await database.setting(storageKey(actor));
    if (frozen != null) {
      if (mounted) setState(() => pending = frozen);
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => JobixAlertDialog(
        title: Text(t('Create a new PDF?', 'إنشاء PDF جديد؟')),
        content: Text(
          t(
            'A successful new export costs 2 Credits. Existing valid downloads are free.',
            'التصدير الجديد الناجح يكلف رصيدين. تنزيل الملف الصالح الموجود مجاني.',
          ),
        ),
        actions: [
          JobixDialogAction.secondary(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('Cancel', 'رجوع')),
          ),
          JobixDialogAction.primary(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('Create — 2 Credits', 'إنشاء — رصيدان')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (client.auth.currentUser?.id != actor) {
      throw const ExportFailure('AUTH_REQUIRED');
    }
    final user = actor;
    final exportLanguage = document!['language'];
    if (!['en', 'ar'].contains(exportLanguage)) {
      throw const ExportFailure('VALIDATION_FAILED');
    }
    final packet = {
      'action': 'create',
      'display': {
        'profile_id': widget.profileId,
        'language': exportLanguage,
        'template': exportLanguage == 'ar'
            ? 'resume_ats_ar_v1'
            : 'resume_ats_en_v1',
      },
      'command': {
        'request_id': newCommandKey(),
        'idempotency_key': newCommandKey(),
        'expected_profile_version': document!['profile_version'],
        'payload': {
          'profile_id': widget.profileId,
          'expected_configuration_version': document!['configuration_version'],
          'expected_document_sha256': document!['document_sha256'],
          'renderer_bundle_version': document!['bundle'],
        },
      },
    };
    final raw = jsonEncode(packet);
    final db = await ref.read(databaseProvider.future);
    await db.setSetting(
      storageKey(user),
      raw,
    ); // Freeze before any network request.
    if (client.auth.currentUser?.id != user) throw StateError('AUTH_REQUIRED');
    pending = raw;
    await _retry();
  }

  Future<bool> _ensureCurrentCredits() async {
    while (mounted) {
      ref.invalidate(coreSummaryProvider);
      try {
        final summary = await ref.read(coreSummaryProvider.future);
        if (!mounted) return false;
        if (summary.balance.available >= 2) return true;
        final action = await showNotEnoughResumeCreditsDialog(
          context,
          availableCredits: summary.balance.available,
        );
        if (action == ResumeCreditDialogAction.reviewHistory && mounted) {
          await context.push('/credits');
          if (mounted) ref.invalidate(coreSummaryProvider);
        }
        return false;
      } catch (_) {
        if (!mounted) return false;
        final action = await showResumeCreditBalanceUnavailableDialog(context);
        if (action != ResumeCreditDialogAction.retry) return false;
      }
    }
    return false;
  }

  Future<void> _retry({bool internalRecovery = false}) async {
    final client = await ref.read(supabaseClientProvider.future);
    final user = client.auth.currentUser!.id;
    final packet = jsonDecode(pending!) as Map;
    if (packet['action'] == 'presentation') {
      final request = Map<String, dynamic>.from(packet['command'] as Map);
      await client
          .rpc('save_resume_presentation', params: request)
          .timeout(const Duration(seconds: 20));
      if (client.auth.currentUser?.id != user) {
        throw StateError('AUTH_REQUIRED');
      }
      final db = await ref.read(databaseProvider.future);
      await db.removeSetting(storageKey(user));
      pending = null;
      if (internalRecovery) {
        await _load(recoverPending: false);
        return;
      }
      if (widget.experience && widget.rebuildLocalDocument != null) {
        if (mounted) setState(() => document = null);
        final local = await widget.rebuildLocalDocument!();
        if (mounted) setState(() => document = local);
      } else {
        await _prepare();
      }
      return;
    }
    final command = Map<String, dynamic>.from(packet['command'] as Map);
    command['request_id'] = newCommandKey(); // Logical key/payload unchanged.
    final db = await ref.read(databaseProvider.future);
    late final Map<String, dynamic> ack;
    try {
      ack = await _call(packet['action'] as String, command);
    } on ExportFailure catch (failure) {
      // These server outcomes occur before job, Credit reservation, or cost
      // hold creation. A future export must be a new explicit user action,
      // rather than a saved request becoming admissible after the rejection.
      const rejectedBeforeAdmission = {
        'RATE_LIMITED',
        'CREDIT_INSUFFICIENT',
        'EXPORT_IN_PROGRESS',
        'EXPORT_NOT_READY',
        'VALIDATION_FAILED',
      };
      final frozen = pending;
      if (rejectedBeforeAdmission.contains(failure.code) &&
          frozen != null &&
          await db.setting(storageKey(user)) == frozen &&
          client.auth.currentUser?.id == user) {
        await db.removeSetting(storageKey(user));
        if (mounted) setState(() => pending = null);
      }
      rethrow;
    }
    ref.invalidate(coreSummaryProvider);
    if (client.auth.currentUser?.id != user) throw StateError('AUTH_REQUIRED');
    if (packet['display'] is Map) {
      final jobId = ack['operation_id'] as String;
      await db.setSetting(
        exportDisplayKey(user, jobId),
        jsonEncode(packet['display']),
      );
      if (client.auth.currentUser?.id != user) {
        throw StateError('AUTH_REQUIRED');
      }
    }
    await db.removeSetting(storageKey(user));
    if (!mounted) return;
    setState(() {
      pending = null;
      if (internalRecovery) {
        message = null;
      } else {
        final balance = (ack['data'] as Map)['balance'] as Map;
        message = t(
          'Server balance: ${balance['available']} available.',
          'الرصيد المتاح من الخادم: ${balance['available']}.',
        );
      }
    });
    if (internalRecovery) {
      await _load(recoverPending: false);
      return;
    }
    final id = ack['operation_id'] as String;
    if (widget.onOperation != null) {
      if (mounted) widget.onOperation!.call(id);
      return;
    }
    if (!mounted) return;
    await context.push('/resume-status/$id');
    if (mounted) await _load();
  }

  Future<void> _visibility(String section, bool visible) async {
    if (document == null || pending != null) return;
    final config = Map<String, dynamic>.from(document!['configuration'] as Map);
    final visibility = Map<String, dynamic>.from(
      config['section_visibility'] as Map? ?? {},
    );
    visibility[section] = visible;
    final request = {
      'command_key': newCommandKey(),
      'requested_profile': widget.profileId,
      'expected_profile_version': document!['profile_version'],
      'expected_configuration_version': document!['configuration_version'],
      'language': document!['language'],
      'hidden_sections': [
        for (final key in visibility.keys)
          if (visibility[key] == false) key,
      ],
    };
    final client = await ref.read(supabaseClientProvider.future);
    final user = client.auth.currentUser!.id;
    final db = await ref.read(databaseProvider.future);
    pending = jsonEncode({'action': 'presentation', 'command': request});
    await db.setSetting(storageKey(user), pending!);
    if (client.auth.currentUser?.id != user) throw StateError('AUTH_REQUIRED');
    await _retry();
  }

  Future<void> _download(String id, {int? expectedBytes}) async {
    if (downloadingExportIds.contains(id)) return;
    if (mounted) {
      setState(() {
        downloadingExportIds.add(id);
        message = null;
      });
    }
    try {
      final client = await ref.read(supabaseClientProvider.future);
      final fullName = ref
          .read(firstProfileProvider)
          .valueOrNull
          ?.personal['full_name'];
      final saved = await ResumeExportService(
        client,
      ).download(id, suggestedName: fullName, expectedBytes: expectedBytes);
      if (mounted) {
        setState(
          () => message = saved == true
              ? t('PDF saved. No Credits charged.', 'تم حفظ PDF دون خصم أرصدة.')
              : null,
        );
      }
    } finally {
      downloadingExportIds.remove(id);
      if (mounted) setState(() {});
    }
  }

  String stateLabel(String state) => switch (state) {
    'QUEUED' => t('Queued', 'في الانتظار'),
    'CLAIMED' || 'GENERATING' => t('Generating', 'جارٍ الإنشاء'),
    'UPLOADING' => t('Storing privately', 'جارٍ الحفظ الخاص'),
    'COMPLETED' => t('Ready', 'جاهز'),
    'RETRYABLE_FAILURE' => t('Recovery pending', 'بانتظار إعادة المحاولة'),
    'FAILED' => t(
      'Failed — reservation released',
      'فشل — تم تحرير الرصيد المحجوز',
    ),
    'EXPIRED' => t('Expired', 'منتهي الصلاحية'),
    'MISSING_OBJECT' => t('File unavailable', 'الملف غير متاح'),
    _ => t('Unavailable', 'غير متاح'),
  };
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!enabled && !widget.historyOnly)
          Text(
            t(
              'New PDF exports are currently disabled. Preview and existing valid downloads remain available.',
              'التصديرات الجديدة معطّلة حاليًا. المعاينة وتنزيل الملفات الصالحة الموجودة متاحان.',
            ),
          ),
        if (message != null && !failureDialogOpen) Text(message!),
        if (busy) const LinearProgressIndicator(),
        if (!widget.experience && !widget.historyOnly)
          TextButton(
            onPressed: busy || !widget.canPrepare || pending != null
                ? null
                : () => _run(_prepare),
            child: Text(
              t(
                'Prepare online Preview — free',
                'تجهيز المعاينة المتصلة — مجاني',
              ),
            ),
          ),
        if (document != null && !widget.historyOnly) ...[
          if (!widget.experience)
            for (final section in ResumePresentation.sectionKeys)
              CheckboxListTile(
                title: Text(sectionLabel(section)),
                value:
                    (document!['configuration'] as Map)['section_visibility']
                        is Map
                    ? ((document!['configuration'] as Map)['section_visibility']
                              as Map)[section] !=
                          false
                    : true,
                onChanged: busy || pending != null
                    ? null
                    : (value) =>
                          _run(() => _visibility(section, value == true)),
              ),
          for (final issue in document!['issues'] as List)
            if (!widget.historyOnly)
              Text(
                t(
                  'Fix or explicitly hide the invalid section: $issue',
                  'أصلح القسم غير الصالح أو أخفه صراحةً: $issue',
                ),
              ),
          if (!widget.experience)
            TextButton(
              onPressed:
                  !enabled ||
                      busy ||
                      pending != null ||
                      (document!['issues'] as List).isNotEmpty
                  ? null
                  : () => _run(() => _submit(), showFailureDialog: true),
              child: Text(t('Create PDF — 2 Credits', 'إنشاء PDF — رصيدان')),
            ),
        ],
        if (pending != null)
          if (!widget.historyOnly)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                t(
                  'An earlier PDF request is unresolved. It is preserved so JobiX can check the same request and prevent a duplicate.',
                  'يوجد طلب PDF سابق لم تُحسم حالته. تم الاحتفاظ به كي يتحقق JobiX من الطلب نفسه ويمنع التكرار.',
                ),
              ),
            ),
        if (widget.historyOnly && historyLoadFailed)
          TextButton(
            onPressed: busy ? null : () => _run(_load),
            child: Text(t('Retry history', 'إعادة محاولة تحميل السجل')),
          ),
        if (widget.experience && !widget.historyOnly)
          TextButton.icon(
            onPressed: () => context.push('/export-history'),
            icon: const Icon(Icons.history),
            label: Text(t('Credit & Export History', 'سجل الأرصدة والتصدير')),
          ),
        if (widget.historyOnly && jobs.isEmpty && !busy && message == null)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              t(
                'No resume exports yet. Your exports will appear here.',
                'لا توجد تصديرات بعد. ستظهر ملفاتك هنا.',
              ),
            ),
          ),
        if (widget.experience && widget.historyOnly)
          for (final job in jobs)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 12),
              child: ResumeJobCard(
                job: job,
                onDetails: () => context.push('/resume-details/${job['id']}'),
                onDownload:
                    job['state'] != 'COMPLETED' ||
                        job['download_eligible'] == false
                    ? null
                    : () => _run(
                        () => _download(
                          job['id'] as String,
                          expectedBytes: resumePositiveInt(job['object_size']),
                        ),
                        allowWhileBusy: true,
                        showFailureDialog: true,
                      ),
                downloading: downloadingExportIds.contains(job['id'] as String),
              ),
            ),
        if (!widget.experience)
          for (final job in jobs)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(stateLabel(job['state'] as String)),
                Text(job['created_at'] as String),
                Wrap(
                  children: [
                    if (job['state'] == 'COMPLETED' &&
                        job['download_eligible'] != false)
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: busy
                            ? null
                            : () => _run(
                                () => _download(
                                  job['id'] as String,
                                  expectedBytes: resumePositiveInt(
                                    job['object_size'],
                                  ),
                                ),
                              ),
                        child: Text(t('Download — free', 'تنزيل — مجاني')),
                      ),
                  ],
                ),
              ],
            ),
        if (cursor != null && (!widget.experience || widget.historyOnly))
          TextButton(
            onPressed: busy
                ? null
                : () => _run(() async {
                    final page = await _call('history', {'cursor': cursor});
                    if (mounted) {
                      setState(() {
                        jobs.addAll(
                          List<Map<String, dynamic>>.from(page['jobs'] as List),
                        );
                        cursor = page['next_cursor'] as String?;
                      });
                    }
                  }),
            child: Text(t('More exports', 'المزيد من الملفات')),
          ),
      ],
    );
  }

  String sectionLabel(String key) => {
    'summary': t('Summary', 'الملخص'),
    'target_role': t('Target Role', 'الوظيفة المستهدفة'),
    'experience': t('Work Experience', 'الخبرة المهنية'),
    'volunteer': t('Volunteer Experience', 'الخبرات التطوعية'),
    'education': t('Education', 'التعليم'),
    'certification': t('Certifications', 'الشهادات'),
    'achievement': t('Achievements', 'الإنجازات'),
    'project': t('Projects', 'المشروعات'),
    'skill': t('Skills', 'المهارات'),
    'language': t('Languages', 'اللغات'),
  }[key]!;
}
