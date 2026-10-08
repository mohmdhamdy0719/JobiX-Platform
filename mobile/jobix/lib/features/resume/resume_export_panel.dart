import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers.dart';
import '../career_profile/career_profile.dart';
import 'resume_document.dart';

class ExportFailure implements Exception {
  const ExportFailure(this.code);
  final String code;
}
/// Rollout is closed by default; this widget never grants/debits Credits.
class ResumeExportPanel extends ConsumerStatefulWidget {
  const ResumeExportPanel({super.key, required this.profileId,
    required this.showDocument, required this.canPrepare, this.initialDocument});
  final String profileId;
  final bool canPrepare;
  final Map<String, dynamic>? initialDocument;
  final Future<void> Function(Map<String, dynamic>) showDocument;
  @override
  ConsumerState<ResumeExportPanel> createState() => _ResumeExportPanelState();
}

class _ResumeExportPanelState extends ConsumerState<ResumeExportPanel> {
  static const enabled = bool.fromEnvironment('JOBIX_ENABLE_PDF_EXPORT');
  Map<String, dynamic>? document, current;
  List<Map<String, dynamic>> jobs = [];
  String? pending, message, cursor;
  bool busy = false;
  bool savingPdf = false;
  bool reviewRequired = false;
  Timer? timer;
  bool get ar => Localizations.localeOf(context).languageCode == 'ar';
  String t(String en, String arabic) => ar ? arabic : en;
  @override
  void initState() {
    super.initState();
    document = widget.initialDocument;
    if (enabled) _run(_load);
  }
  @override
  void dispose() {
    timer?.cancel();
    if (savingPdf) {
      const MethodChannel('jobix/pdf_save').invokeMethod<void>('cancel')
          .catchError((Object _) {});
    }
    super.dispose();
  }
  String storageKey(String user) => 'resume:$user:export:${widget.profileId}';
  Future<Map<String, dynamic>> _call(String action, Map<String, dynamic> command) async {
    final client = await ref.read(supabaseClientProvider.future);
    final user = client.auth.currentUser?.id;
    if (user == null) throw StateError('AUTH_REQUIRED');
    late FunctionResponse response;
    try {
      response = await client.functions.invoke('resume-export',
        body: {'action': action, 'command': command}).timeout(const Duration(seconds: 50));
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map && details['error'] is Map
        ? (details['error'] as Map)['code'] : null;
      throw ExportFailure(code is String ? code : 'SERVICE_UNAVAILABLE');
    }
    if (client.auth.currentUser?.id != user) {
      final db = await ref.read(databaseProvider.future);
      await db.removeSetting(storageKey(user));
      throw StateError('AUTH_REQUIRED');
    }
    final envelope = Map<String, dynamic>.from(response.data as Map);
    if (envelope['error'] != null) {
      final code = (envelope['error'] as Map)['code'];
      throw ExportFailure(code is String ? code : 'SERVICE_UNAVAILABLE');
    }
    return Map<String, dynamic>.from(envelope['data'] as Map);
  }
  Future<void> _run(Future<void> Function() operation) async {
    if (busy || !enabled) return;
    if (mounted) setState(() { busy = true; message = null; });
    try { await operation(); }
    catch (error) {
      if (mounted) setState(() {
        final code = error is ExportFailure ? error.code : 'SERVICE_UNAVAILABLE';
        reviewRequired = ['VERSION_CONFLICT','VALIDATION_FAILED'].contains(code);
        message = switch (code) {
          'VERSION_CONFLICT' => t('The saved document changed. Review the current Preview before creating a new export.',
            'تغيّر المستند المحفوظ. راجع المعاينة الحالية قبل إنشاء تصدير جديد.'),
          'VALIDATION_FAILED' => t('Fix or explicitly hide invalid saved content, then review Preview.',
            'أصلح المحتوى المحفوظ غير الصالح أو أخفه صراحةً ثم راجع المعاينة.'),
          'CREDIT_INSUFFICIENT' => t('Not enough Credits. No export was accepted. Retry the same request after Credits are available.',
            'الرصيد غير كافٍ. لم يُقبل التصدير. أعد محاولة الطلب نفسه عند توفر الرصيد.'),
          'EXPORT_NOT_READY' => t('Export is disabled. No new export can be accepted.',
            'التصدير معطّل. لا يمكن قبول تصدير جديد.'),
          'EXPORT_EXPIRED' => t('The file expired. No automatic regeneration or charge.',
            'انتهت صلاحية الملف. لا توجد إعادة إنشاء أو رسوم تلقائية.'),
          'EXPORT_OBJECT_MISSING' => t('The file is unavailable. No automatic regeneration or charge.',
            'الملف غير متاح. لا توجد إعادة إنشاء أو رسوم تلقائية.'),
          _ => t('The request could not be confirmed. Retry uses the same saved request; do not submit another export.',
            'تعذّر تأكيد الطلب. إعادة المحاولة تستخدم الطلب المحفوظ نفسه؛ لا ترسل طلب تصدير آخر.'),
        };
      });
    } finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _load() async {
    final client = await ref.read(supabaseClientProvider.future);
    final user = client.auth.currentUser?.id;
    if (user == null) return;
    final db = await ref.read(databaseProvider.future);
    final raw = await db.setting(storageKey(user));
    final history = await _call('history', {});
    if (!mounted || client.auth.currentUser?.id != user) return;
    setState(() {
      pending = raw;
      jobs = List<Map<String, dynamic>>.from(history['jobs'] as List);
      cursor = history['next_cursor'] as String?;
    });
  }
  Future<void> _prepare() async {
    final result = await _call('document', {'profile_id': widget.profileId});
    if (!mounted) return;
    setState(() => document = result);
    await widget.showDocument(result);
  }
  Future<void> _submit([String? historicalId]) async {
    if (document == null || pending != null) return;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) =>
      AlertDialog(title: Text(t('Create a new PDF?', 'إنشاء PDF جديد؟')),
        content: Text(t('A successful new export costs 2 Credits. Existing valid downloads are free.',
          'التصدير الجديد الناجح يكلف رصيدين. تنزيل الملف الصالح الموجود مجاني.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Cancel', 'رجوع'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('Create — 2 Credits', 'إنشاء — رصيدان'))),
        ]));
    if (confirmed != true || !mounted) return;
    final client = await ref.read(supabaseClientProvider.future);
    final user = client.auth.currentUser!.id;
    final packet = {
      'action': historicalId == null ? 'create' : 'again',
      'command': {
        'request_id': newCommandKey(), 'idempotency_key': newCommandKey(),
        'expected_profile_version': document!['profile_version'],
        'payload': {'profile_id': widget.profileId,
          'expected_configuration_version': document!['configuration_version'],
          'expected_document_sha256': document!['document_sha256'],
          'renderer_bundle_version': document!['bundle'],
          if (historicalId != null) 'historical_export_id': historicalId},
      },
    };
    final raw = jsonEncode(packet);
    final db = await ref.read(databaseProvider.future);
    await db.setSetting(storageKey(user), raw); // Freeze before any network request.
    if (client.auth.currentUser?.id != user) throw StateError('AUTH_REQUIRED');
    pending = raw;
    await _retry();
  }
  Future<void> _retry() async {
    final client = await ref.read(supabaseClientProvider.future);
    final user = client.auth.currentUser!.id;
    final packet = jsonDecode(pending!) as Map;
    if (packet['action'] == 'presentation') {
      final request = Map<String, dynamic>.from(packet['command'] as Map);
      await client.rpc('save_resume_presentation', params: request)
          .timeout(const Duration(seconds: 20));
      if (client.auth.currentUser?.id != user) throw StateError('AUTH_REQUIRED');
      final db = await ref.read(databaseProvider.future);
      await db.removeSetting(storageKey(user));
      pending = null;
      await _prepare();
      return;
    }
    final command = Map<String, dynamic>.from(packet['command'] as Map);
    command['request_id'] = newCommandKey(); // Logical key/payload unchanged.
    final ack = await _call(packet['action'] as String, command);
    final db = await ref.read(databaseProvider.future);
    if (client.auth.currentUser?.id != user) throw StateError('AUTH_REQUIRED');
    await db.removeSetting(storageKey(user));
    if (!mounted) return;
    setState(() {
      pending = null;
      final balance = (ack['data'] as Map)['balance'] as Map;
      message = t('Server balance: ${balance['available']} available.',
        'الرصيد المتاح من الخادم: ${balance['available']}.');
    });
    final id = ack['operation_id'] as String;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!busy && mounted) _run(() async {
        final status = await _call('status', {'export_id': id});
        if (!mounted) return;
        setState(() => current = status);
        if (['COMPLETED','FAILED','EXPIRED','MISSING_OBJECT'].contains(status['state'])) {
          timer?.cancel(); await _load();
        }
      });
    });
    await _load();
  }
  Future<void> _visibility(String section, bool visible) async {
    if (document == null || pending != null) return;
    final config = Map<String, dynamic>.from(document!['configuration'] as Map);
    final visibility = Map<String, dynamic>.from(config['section_visibility'] as Map? ?? {});
    visibility[section] = visible;
    final request = {
      'command_key': newCommandKey(), 'requested_profile': widget.profileId,
      'expected_profile_version': document!['profile_version'],
      'expected_configuration_version': document!['configuration_version'],
      'language': document!['language'],
      'hidden_sections': [for (final key in visibility.keys) if (visibility[key] == false) key],
    };
    final client = await ref.read(supabaseClientProvider.future);
    final user = client.auth.currentUser!.id;
    final db = await ref.read(databaseProvider.future);
    pending = jsonEncode({'action': 'presentation', 'command': request});
    await db.setSetting(storageKey(user), pending!);
    if (client.auth.currentUser?.id != user) throw StateError('AUTH_REQUIRED');
    await _retry();
  }
  Future<void> _download(String id) async {
    final client = await ref.read(supabaseClientProvider.future);
    final user = client.auth.currentUser!.id;
    final result = await _call('download', {'export_id': id});
    final uri = Uri.parse(result['url'] as String);
    if (uri.scheme != 'https' || uri.host != 'storage.googleapis.com') {
      throw StateError('FORBIDDEN');
    }
    final http = HttpClient();
    try {
      final request = await http.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) throw StateError('EXPORT_NOT_READY');
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) { builder.add(chunk); }
      if (client.auth.currentUser?.id != user) throw StateError('AUTH_REQUIRED');
      // Bytes and URL are memory-only. Android SAF saves only to a user-chosen file.
      savingPdf = true;
      final saved = await const MethodChannel('jobix/pdf_save').invokeMethod<bool>(
        'save', {'bytes': builder.takeBytes(), 'name': '$id.pdf'});
      if (mounted) setState(() => message = saved == true
        ? t('PDF saved. No Credits charged.', 'تم حفظ PDF دون خصم أرصدة.') : null);
    } finally { savingPdf = false; http.close(force: true); }
  }
  String stateLabel(String state) => switch (state) {
    'QUEUED' => t('Queued', 'في الانتظار'),
    'CLAIMED' || 'GENERATING' => t('Generating', 'جارٍ الإنشاء'),
    'UPLOADING' => t('Storing privately', 'جارٍ الحفظ الخاص'),
    'COMPLETED' => t('Ready', 'جاهز'),
    'RETRYABLE_FAILURE' => t('Recovery pending', 'بانتظار إعادة المحاولة'),
    'FAILED' => t('Failed — reservation released', 'فشل — تم تحرير الرصيد المحجوز'),
    'EXPIRED' => t('Expired', 'منتهي الصلاحية'),
    'MISSING_OBJECT' => t('File unavailable', 'الملف غير متاح'),
    _ => t('Unavailable', 'غير متاح'),
  };
  @override
  Widget build(BuildContext context) {
    if (!enabled) return Text(t(
      'PDF export is disabled pending development rollout. No Credits can be charged.',
      'تصدير PDF معطّل حتى تفعيل بيئة التطوير. لا يمكن خصم أرصدة.'));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (message != null) Text(message!),
      if (busy) const LinearProgressIndicator(),
      TextButton(onPressed: busy || !widget.canPrepare || pending != null ? null : () => _run(_prepare),
        child: Text(t('Prepare online Preview — free', 'تجهيز المعاينة المتصلة — مجاني'))),
      if (document != null) ...[
        for (final section in ResumePresentation.sectionKeys)
          CheckboxListTile(
            title: Text(sectionLabel(section)),
            value: (document!['configuration'] as Map)['section_visibility'] is Map
              ? ((document!['configuration'] as Map)['section_visibility'] as Map)[section] != false : true,
            onChanged: busy || pending != null ? null :
              (value) => _run(() => _visibility(section, value == true)),
          ),
        for (final issue in document!['issues'] as List)
          Text(t('Fix or explicitly hide the invalid section: $issue',
            'أصلح القسم غير الصالح أو أخفه صراحةً: $issue')),
        TextButton(onPressed: busy || pending != null ||
          (document!['issues'] as List).isNotEmpty ? null : () => _run(_submit),
          child: Text(t('Create PDF — 2 Credits', 'إنشاء PDF — رصيدان'))),
      ],
      if (pending != null) TextButton(onPressed: busy ? null : () => _run(_retry),
        child: Text(t('Reconcile saved export request', 'تأكيد طلب التصدير المحفوظ'))),
      if (pending != null && reviewRequired) TextButton(
        onPressed: busy ? null : () => _run(() async {
          final client = await ref.read(supabaseClientProvider.future);
          final user = client.auth.currentUser!.id;
          final db = await ref.read(databaseProvider.future);
          await db.removeSetting(storageKey(user));
          if (!mounted || client.auth.currentUser?.id != user) return;
          setState(() { pending = null; reviewRequired = false; document = null; });
          await _prepare();
        }),
        child: Text(t('Review rejected request with current Preview',
          'مراجعة الطلب المرفوض بالمعاينة الحالية'))),
      if (current != null) Text(stateLabel(current!['state'] as String)),
      TextButton(onPressed: busy ? null : () => _run(_load),
        child: Text(t('Refresh export history', 'تحديث سجل التصدير'))),
      for (final job in jobs) ListTile(
        title: Text(stateLabel(job['state'] as String)),
        subtitle: Text(job['created_at'] as String),
        trailing: Wrap(children: [
          if (job['state'] == 'COMPLETED') TextButton(
            onPressed: busy ? null : () => _run(() => _download(job['id'] as String)),
            child: Text(t('Download — free', 'تنزيل — مجاني'))),
          TextButton(onPressed: busy || document == null || pending != null ||
              (document!['issues'] as List).isNotEmpty ? null :
            () => _run(() => _submit(job['id'] as String)),
            child: Text(t('Export Again — 2', 'تصدير جديد — رصيدان'))),
        ]),
      ),
      if (cursor != null) TextButton(onPressed: busy ? null : () => _run(() async {
        final page = await _call('history', {'cursor': cursor});
        if (mounted) setState(() {
          jobs.addAll(List<Map<String, dynamic>>.from(page['jobs'] as List));
          cursor = page['next_cursor'] as String?;
        });
      }), child: Text(t('More exports', 'المزيد من الملفات'))),
    ]);
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
