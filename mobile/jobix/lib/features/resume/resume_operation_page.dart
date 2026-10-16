import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/jobix_dialog.dart';
import '../../core/providers.dart';
import '../auth/auth_controller.dart';
import '../../l10n/app_localizations.dart';
import 'resume_export_service.dart';
import '../core_mvp/core_api.dart';
import 'resume_experience_widgets.dart';

class ResumeOperationPage extends ConsumerStatefulWidget {
  const ResumeOperationPage({
    required this.exportId,
    this.waiting = false,
    super.key,
  });
  final String exportId;
  final bool waiting;
  @override
  ConsumerState<ResumeOperationPage> createState() =>
      _ResumeOperationPageState();
}

class _ResumeOperationPageState extends ConsumerState<ResumeOperationPage>
    with WidgetsBindingObserver {
  Map<String, dynamic>? job;
  Timer? timer;
  String? message;
  bool busy = false;
  bool refreshInFlight = false;
  bool saving = false;
  bool failureDialogOpen = false;
  int generation = 0;
  int pollStep = 0;
  Stopwatch? pollClock;
  bool foreground = true;
  bool get ar => Localizations.localeOf(context).languageCode == 'ar';
  String t(String en, String arabic) => ar ? arabic : en;
  static const terminal = {'COMPLETED', 'FAILED', 'EXPIRED', 'MISSING_OBJECT'};
  static const pollDelays = [3, 5, 10, 20, 30];
  static const pollWindow = Duration(minutes: 30);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(
      authSessionProvider.select((s) => s.valueOrNull?.user.id),
      (old, next) {
        if (old != null && old != next) {
          generation++;
          timer?.cancel();
          if (mounted) {
            setState(() {
              job = null;
              busy = false;
              message = null;
              pollStep = 0;
              pollClock = null;
            });
          }
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    generation++;
    timer?.cancel();
    if (saving) {
      const MethodChannel(
        'jobix/pdf_save',
      ).invokeMethod<void>('cancel').catchError((Object _) {});
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    timer?.cancel();
    if (foreground && mounted) {
      pollStep = 0;
      pollClock = Stopwatch()..start();
      refresh(showProgress: job == null);
    }
  }

  Future<void> refresh({bool showProgress = true}) async {
    if (refreshInFlight) return;
    refreshInFlight = true;
    final token = generation;
    timer?.cancel();
    if (showProgress && mounted) {
      setState(() {
        busy = true;
        message = null;
      });
      pollStep = 0;
      pollClock = Stopwatch()..start();
    }
    try {
      final service = await ref.read(resumeExportServiceProvider.future);
      final response = await service.call('status', {
        'export_id': widget.exportId,
      });
      final database = await ref.read(databaseProvider.future);
      final data = await service.withDisplay(response, database.setting);
      if (!mounted || generation != token) return;
      final previousState = job?['state'];
      setState(() {
        job = data;
        message = null;
      });
      timer?.cancel();
      if (terminal.contains(data['state'])) {
        ref.invalidate(coreSummaryProvider);
        pollClock = null;
        pollStep = 0;
      } else {
        if (previousState != data['state']) pollStep = 0;
        _scheduleStatusPoll();
      }
    } catch (_) {
      timer?.cancel();
      if (mounted && generation == token) {
        setState(
          () => message = t(
            'Status is unavailable. The existing operation is preserved; refresh to reconnect.',
            'الحالة غير متاحة. تم الاحتفاظ بالعملية الحالية؛ حدّث لإعادة الاتصال.',
          ),
        );
      }
    } finally {
      refreshInFlight = false;
      if (showProgress && mounted && generation == token) {
        setState(() => busy = false);
      }
    }
  }

  void _scheduleStatusPoll() {
    timer?.cancel();
    final state = job?['state'];
    if (!foreground || state == null || terminal.contains(state)) return;
    pollClock ??= Stopwatch()..start();
    if (pollClock!.elapsed >= pollWindow) {
      if (mounted) {
        setState(
          () => message = t(
            'This request is still processing. Refresh to check its latest status.',
            'لا يزال الطلب قيد المعالجة. حدّث الصفحة للتحقق من أحدث حالة.',
          ),
        );
      }
      return;
    }
    final delayIndex = pollStep < pollDelays.length
        ? pollStep
        : pollDelays.length - 1;
    final delay = pollDelays[delayIndex];
    pollStep++;
    timer = Timer(Duration(seconds: delay), () {
      if (mounted && foreground) refresh(showProgress: false);
    });
  }

  void _backToPreviousScreen() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/export-history');
    }
  }

  Future<void> download() async {
    if (saving) return;
    setState(() {
      saving = true;
      message = null;
    });
    try {
      final service = await ref.read(resumeExportServiceProvider.future);
      final saved = await service.download(widget.exportId);
      if (mounted && saved) {
        setState(
          () => message = t(
            'PDF saved. No Credits charged.',
            'تم حفظ PDF دون خصم أرصدة.',
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        final failureMessage =
            error is ExportFailure &&
                ['EXPORT_EXPIRED', 'EXPORT_OBJECT_MISSING'].contains(error.code)
            ? t(
                'File unavailable. It will not be regenerated or charged automatically.',
                'الملف غير متاح. لن تتم إعادة إنشائه أو خصم أرصدة تلقائيًا.',
              )
            : AppLocalizations.of(context)!.exportTemporarilyUnavailable;
        setState(() {
          message = failureMessage;
          failureDialogOpen = true;
        });
        await showDialog<void>(
          context: context,
          builder: (dialog) => JobixAlertDialog(
            icon: const Icon(Icons.download_outlined),
            title: Text(t('PDF download failed', 'فشل تنزيل PDF')),
            content: Text(failureMessage),
            actions: [
              JobixDialogAction.secondary(
                onPressed: () => Navigator.pop(dialog),
                child: Text(t('Close', 'إغلاق')),
              ),
            ],
          ),
        );
        if (mounted) setState(() => failureDialogOpen = false);
      }
    } finally {
      saving = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadable =
        job?['state'] == 'COMPLETED' &&
        job?['download_eligible'] != false &&
        (DateTime.tryParse(
              job?['expires_at']?.toString() ?? '',
            )?.isAfter(DateTime.now()) ??
            false);
    final active = job != null && !terminal.contains(job!['state']);
    final profile = ref.watch(firstProfileProvider).valueOrNull;
    final canAgain =
        job != null && !active && job!['profile_id'] == profile?.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(
            widget.waiting && active ? 'Preparing Resume' : 'Resume Details',
            widget.waiting && active
                ? 'تجهيز السيرة الذاتية'
                : 'تفاصيل السيرة الذاتية',
          ),
        ),
        leading: IconButton(
          icon: const BackButtonIcon(),
          onPressed: _backToPreviousScreen,
        ),
        actions: [
          if (job != null)
            IconButton(
              tooltip: t('Refresh status', 'تحديث الحالة'),
              onPressed: busy || refreshInFlight ? null : () => refresh(),
              icon: busy || refreshInFlight
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (busy) const LinearProgressIndicator(),
            if (message != null && !failureDialogOpen)
              Padding(padding: const EdgeInsets.all(16), child: Text(message!)),
            Expanded(
              child: job == null
                  ? Center(
                      child: busy
                          ? const CircularProgressIndicator()
                          : TextButton(
                              onPressed: refresh,
                              child: Text(t('Retry', 'إعادة المحاولة')),
                            ),
                    )
                  : widget.waiting && active
                  ? ResumeProcessingView(
                      job: job!,
                      onHistory: () => context.go('/export-history'),
                      onDashboard: () => context.go('/home'),
                      onDownload: downloadable ? download : null,
                      downloading: saving,
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: ResumeDetailsBody(
                        job: job!,
                        onDownload: downloadable ? download : null,
                        downloading: saving,
                        onAgain: canAgain && !busy
                            ? () =>
                                  context.go('/resume?again=${widget.exportId}')
                            : null,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
