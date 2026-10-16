import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import '../../core/design/jobix_dialog.dart';
import '../../core/design/jobix_feedback.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/providers.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/auth_repository.dart';

class AccountInformationPage extends ConsumerStatefulWidget {
  const AccountInformationPage({super.key});

  @override
  ConsumerState<AccountInformationPage> createState() =>
      _AccountInformationPageState();
}

class _ChangeEmailDialog extends StatefulWidget {
  const _ChangeEmailDialog({
    required this.initialEmail,
    required this.validate,
    required this.submit,
    required this.say,
  });

  final String initialEmail;
  final String? Function(String value) validate;
  final Future<String?> Function(String value) submit;
  final String Function(String en, String ar) say;

  @override
  State<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<_ChangeEmailDialog> {
  late final TextEditingController controller;
  String? error;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final validation = widget.validate(controller.text);
    if (validation != null) {
      setState(() => error = validation);
      return;
    }
    setState(() {
      submitting = true;
      error = null;
    });
    String? result;
    try {
      result = await widget.submit(controller.text.trim());
    } catch (_) {
      result = widget.say(
        'The email change could not be verified. Refresh Account Information before trying again.',
        'تعذّر التحقق من تغيير البريد. حدّث معلومات الحساب قبل المحاولة مجددًا.',
      );
    }
    if (!mounted) return;
    if (result != null) {
      setState(() {
        submitting = false;
        error = result;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => JobixAlertDialog(
    icon: const Icon(Icons.alternate_email),
    title: Text(widget.say('Change sign-in email', 'تغيير بريد تسجيل الدخول')),
    content: TextField(
      key: const Key('account-change-email-input'),
      controller: controller,
      enabled: !submitting,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      autofillHints: const [AutofillHints.email],
      decoration: InputDecoration(
        labelText: widget.say('New email address', 'عنوان البريد الجديد'),
        errorText: error,
      ),
    ),
    actions: [
      JobixDialogAction.secondary(
        onPressed: submitting ? null : () => Navigator.pop(context, false),
        child: Text(widget.say('Cancel', 'إلغاء')),
      ),
      JobixDialogAction.primary(
        key: const Key('account-send-email-confirmation'),
        onPressed: submitting ? null : send,
        child: Text(widget.say('Send confirmation', 'إرسال التأكيد')),
      ),
    ],
  );
}

class _AccountInformationPageState extends ConsumerState<AccountInformationPage>
    with WidgetsBindingObserver {
  static const resendCooldown = Duration(seconds: 60);
  AuthApi? api;
  AppDatabase? database;
  AuthAccountState? account;
  final currentEmailController = TextEditingController();
  Timer? countdown;
  DateTime? cooldownUntil;
  bool loading = true, busy = false;
  String? error;

  bool get arabic => Localizations.localeOf(context).languageCode == 'ar';
  String say(String en, String ar) => arabic ? ar : en;
  String cooldownKey(String user) => 'auth-email-change:$user:resend-until';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(loadAccount());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(loadAccount());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    countdown?.cancel();
    currentEmailController.dispose();
    super.dispose();
  }

  Future<void> loadAccount() async {
    try {
      final auth = await ref.read(authApiProvider.future);
      final current = await auth.accountState(refresh: true);
      final db = await ref.read(databaseProvider.future);
      final raw = await db.setting(cooldownKey(current.userId));
      final localUntil = raw == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(int.tryParse(raw) ?? 0);
      final sentAt = current.emailChangeSentAt == null
          ? null
          : DateTime.tryParse(current.emailChangeSentAt!);
      final serverUntil = sentAt?.add(resendCooldown);
      final until = current.pendingEmail?.isNotEmpty == true
          ? _later(localUntil, serverUntil)
          : null;
      if (until == null) await db.removeSetting(cooldownKey(current.userId));
      if (!mounted) return;
      api = auth;
      database = db;
      account = current;
      currentEmailController.text = current.email;
      cooldownUntil = until;
      loading = false;
      error = null;
      _startCountdown();
      setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = say(
            'Account information could not be verified. Retry while signed in.',
            'تعذّر التحقق من معلومات الحساب. أعد المحاولة أثناء تسجيل الدخول.',
          );
        });
      }
    }
  }

  DateTime? _later(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  Duration get remaining {
    final until = cooldownUntil;
    if (until == null) return Duration.zero;
    final value = until.difference(DateTime.now());
    return value.isNegative ? Duration.zero : value;
  }

  String get countdownLabel {
    final seconds = remaining.inSeconds;
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _startCountdown() {
    countdown?.cancel();
    if (cooldownUntil == null || remaining == Duration.zero) return;
    countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (remaining == Duration.zero) {
        countdown?.cancel();
      }
      setState(() {});
    });
  }

  Future<void> _recordCooldown() async {
    final current = account;
    if (current == null || database == null) return;
    if (current.pendingEmail?.isNotEmpty != true) {
      await database!.removeSetting(cooldownKey(current.userId));
      if (mounted) setState(() => cooldownUntil = null);
      countdown?.cancel();
      return;
    }
    final until = DateTime.now().add(resendCooldown);
    await database!.setSetting(
      cooldownKey(current.userId),
      until.millisecondsSinceEpoch.toString(),
    );
    if (!mounted) return;
    setState(() => cooldownUntil = until);
    _startCountdown();
  }

  String? _validateEmail(String value) {
    final current = account;
    final normalized = value.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return say(
        'Enter a valid email address.',
        'أدخل بريدًا إلكترونيًا صالحًا.',
      );
    }
    if (normalized == current?.email.trim().toLowerCase()) {
      return say(
        'Enter an address different from your current email.',
        'أدخل عنوانًا مختلفًا عن بريدك الحالي.',
      );
    }
    if (normalized == current?.pendingEmail?.trim().toLowerCase()) {
      return say(
        'This address is already awaiting confirmation.',
        'هذا العنوان بانتظار التأكيد بالفعل.',
      );
    }
    return null;
  }

  Future<void> openChangeEmail() async {
    final current = account;
    if (busy || current == null || api == null) return;
    var confirmationPending = true;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangeEmailDialog(
        initialEmail: current.pendingEmail ?? '',
        validate: _validateEmail,
        say: say,
        submit: (value) async {
          if (mounted) setState(() => busy = true);
          try {
            var changed = await api!.updateEmail(value);
            if (changed.pendingEmail?.trim().toLowerCase() !=
                    value.trim().toLowerCase() &&
                changed.email.trim().toLowerCase() !=
                    value.trim().toLowerCase()) {
              changed = await api!.accountState(refresh: true);
            }
            final target = value.trim().toLowerCase();
            final isPending =
                changed.pendingEmail?.trim().toLowerCase() == target;
            final isCurrent = changed.email.trim().toLowerCase() == target;
            if (!isPending && !isCurrent) {
              throw StateError('EMAIL_CHANGE_NOT_CONFIRMED');
            }
            if (mounted) {
              setState(() => account = changed);
              confirmationPending = isPending;
              await _recordCooldown();
            }
            return null;
          } catch (_) {
            return say(
              'The email change could not be verified. Refresh Account Information before trying again.',
              'تعذّر التحقق من تغيير البريد. حدّث معلومات الحساب قبل المحاولة مجددًا.',
            );
          } finally {
            if (mounted) setState(() => busy = false);
          }
        },
      ),
    );
    if (submitted == true && mounted) {
      showJobixFeedback(
        context,
        confirmationPending
            ? say(
                'Confirmation requested. The new address takes effect only after you confirm it.',
                'تم طلب التأكيد. لن يسري العنوان الجديد إلا بعد تأكيده.',
              )
            : say(
                'Your sign-in email has been updated.',
                'تم تحديث بريد تسجيل الدخول.',
              ),
      );
    }
  }

  Future<void> resendConfirmation() async {
    final pendingEmail = account?.pendingEmail;
    if (busy ||
        api == null ||
        pendingEmail == null ||
        pendingEmail.isEmpty ||
        remaining > Duration.zero) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await api!.resendEmailChange(pendingEmail);
      await _recordCooldown();
      if (mounted) {
        showJobixFeedback(
          context,
          say('Confirmation resent.', 'أُعيد إرسال رسالة التأكيد.'),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = say(
            'The confirmation could not be resent. Try again later.',
            'تعذّر إعادة إرسال التأكيد. حاول لاحقًا.',
          ),
        );
        showJobixFeedback(context, error!, kind: JobixFeedbackKind.error);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resetPassword() async {
    final currentEmail = account?.email ?? '';
    if (busy || currentEmail.isEmpty || api == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await api!.reset(currentEmail);
      if (mounted) {
        showJobixFeedback(
          context,
          say(
            'Password reset instructions were sent to your sign-in email.',
            'أُرسلت تعليمات إعادة تعيين كلمة المرور إلى بريد تسجيل الدخول.',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        showJobixFeedback(
          context,
          say(
            'Password reset is unavailable right now. Try again later.',
            'إعادة تعيين كلمة المرور غير متاحة الآن. حاول لاحقًا.',
          ),
          kind: JobixFeedbackKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = account;
    final pending = current?.pendingEmail?.trim();
    final canResend =
        pending != null && pending.isNotEmpty && remaining == Duration.zero;
    return SliceScaffold(
      title: say('Account Information', 'معلومات الحساب'),
      leading: IconButton(
        tooltip: say('Back', 'رجوع'),
        onPressed: busy ? null : () => context.go('/settings'),
        icon: const Icon(Icons.arrow_back),
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      style: const TextStyle(color: TokensV0.error),
                    ),
                  ),
                  TextButton(
                    key: const Key('account-retry-load'),
                    onPressed: busy ? null : loadAccount,
                    child: Text(say('Retry', 'إعادة المحاولة')),
                  ),
                ],
                SliceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        say(
                          'Your current sign-in email is managed by Supabase Auth.',
                          'تتم إدارة بريد تسجيل الدخول الحالي عبر Supabase Auth.',
                        ),
                      ),
                      const SizedBox(height: TokensV0.space16),
                      TextField(
                        key: const Key('account-current-email'),
                        readOnly: true,
                        controller: currentEmailController,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: say('Sign-in email', 'بريد تسجيل الدخول'),
                        ),
                      ),
                      const SizedBox(height: TokensV0.space12),
                      PrimaryAction(
                        key: const Key('account-change-email'),
                        label: say('Change email', 'تغيير البريد الإلكتروني'),
                        busy: busy,
                        onPressed: current == null ? null : openChangeEmail,
                      ),
                    ],
                  ),
                ),
                if (pending != null && pending.isNotEmpty) ...[
                  const SizedBox(height: TokensV0.space16),
                  SliceCard(
                    key: const Key('account-pending-email'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          say('Pending confirmation', 'بانتظار التأكيد'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: TokensV0.space8),
                        Text(pending, textDirection: TextDirection.ltr),
                        if (!canResend) ...[
                          const SizedBox(height: TokensV0.space8),
                          Text(
                            say(
                              'Resend available in $countdownLabel',
                              'تتاح إعادة الإرسال خلال $countdownLabel',
                            ),
                          ),
                        ],
                        const SizedBox(height: TokensV0.space8),
                        Wrap(
                          spacing: TokensV0.space8,
                          runSpacing: TokensV0.space4,
                          children: [
                            TextButton(
                              key: const Key('account-edit-pending-email'),
                              onPressed: busy ? null : openChangeEmail,
                              child: Text(say('Edit email', 'تعديل البريد')),
                            ),
                            TextButton(
                              key: const Key('account-resend-email'),
                              onPressed: busy || !canResend
                                  ? null
                                  : resendConfirmation,
                              child: Text(
                                say(
                                  'Resend confirmation',
                                  'إعادة إرسال التأكيد',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: TokensV0.space16),
                SliceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        say(
                          'Reset your password using the verified email flow.',
                          'أعد تعيين كلمة المرور عبر مسار البريد المعتمد.',
                        ),
                      ),
                      const SizedBox(height: TokensV0.space12),
                      OutlinedButton(
                        key: const Key('account-reset-password'),
                        onPressed: busy || (current?.email.isEmpty ?? true)
                            ? null
                            : resetPassword,
                        child: Text(
                          say(
                            'Send password reset email',
                            'إرسال بريد إعادة التعيين',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
