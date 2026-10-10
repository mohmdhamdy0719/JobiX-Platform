import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../auth/auth_controller.dart';
import '../../l10n/app_localizations.dart';
import 'resume_export_service.dart';
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
  bool saving = false;
  int generation = 0;
  bool foreground = true;
  bool get ar => Localizations.localeOf(context).languageCode == 'ar';
  String t(String en, String arabic) => ar ? arabic : en;
  static const terminal = {'COMPLETED', 'FAILED', 'EXPIRED', 'MISSING_OBJECT'};
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
    if (foreground && mounted) refresh();
  }

  Future<void> refresh() async {
    if (busy) return;
    final token = generation;
    setState(() => busy = true);
    try {
      final service = await ref.read(resumeExportServiceProvider.future);
      final response = await service.call('status', {
        'export_id': widget.exportId,
      });
      final database = await ref.read(databaseProvider.future);
      final data = await service.withDisplay(response, database.setting);
      if (!mounted || generation != token) return;
      setState(() {
        job = data;
        message = null;
      });
      timer?.cancel();
      if (foreground && !terminal.contains(data['state'])) {
        timer = Timer(const Duration(seconds: 3), refresh);
      }
    } catch (_) {
      if (mounted && generation == token) {
        setState(
          () => message = t(
            'Status is unavailable. The existing operation is preserved; refresh to reconnect.',
            'الحالة غير متاحة. تم الاحتفاظ بالعملية الحالية؛ حدّث لإعادة الاتصال.',
          ),
        );
      }
    } finally {
      if (mounted && generation == token) setState(() => busy = false);
    }
  }

  Future<void> download() async {
    if (busy) return;
    setState(() {
      busy = true;
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
        setState(
          () => message =
              error is ExportFailure &&
                  [
                    'EXPORT_EXPIRED',
                    'EXPORT_OBJECT_MISSING',
                  ].contains(error.code)
              ? t(
                  'File unavailable. It will not be regenerated or charged automatically.',
                  'الملف غير متاح. لن تتم إعادة إنشائه أو خصم أرصدة تلقائيًا.',
                )
              : AppLocalizations.of(context)!.exportTemporarilyUnavailable,
        );
      }
    } finally {
      saving = false;
      if (mounted) setState(() => busy = false);
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
          onPressed: () => context.go('/export-history'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (busy) const LinearProgressIndicator(),
            if (message != null)
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
                      onDownload: downloadable && !busy ? download : null,
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: ResumeDetailsBody(
                        job: job!,
                        busy: busy,
                        onDownload: downloadable && !busy ? download : null,
                        onAgain: canAgain && !busy
                            ? () =>
                                  context.go('/resume?again=${widget.exportId}')
                            : null,
                        onRefresh: refresh,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
