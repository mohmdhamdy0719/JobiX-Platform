import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../features/auth/auth_controller.dart';
import '../../core/providers.dart';

class AccountInformationPage extends ConsumerStatefulWidget {
  const AccountInformationPage({super.key});

  @override
  ConsumerState<AccountInformationPage> createState() =>
      _AccountInformationPageState();
}

class _AccountInformationPageState
    extends ConsumerState<AccountInformationPage> {
  final email = TextEditingController();
  bool busy = false;
  String? notice;
  String? error;

  bool get arabic => Localizations.localeOf(context).languageCode == 'ar';
  String say(String en, String ar) => arabic ? ar : en;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> updateEmail() async {
    final value = email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      setState(
        () => error = say(
          'Enter a valid email address.',
          'أدخل بريدًا إلكترونيًا صالحًا.',
        ),
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await (await ref.read(authApiProvider.future)).updateEmail(value);
      if (!mounted) return;
      setState(
        () => notice = say(
          'Check your email to confirm the address change. It takes effect only after confirmation.',
          'تحقق من بريدك لتأكيد تغيير العنوان. لن يسري التغيير إلا بعد التأكيد.',
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => error = say(
            'The email could not be changed. Check the address or try again later.',
            'تعذر تغيير البريد الإلكتروني. تحقق من العنوان أو حاول لاحقًا.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resetPassword(String currentEmail) async {
    if (currentEmail.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await (await ref.read(authApiProvider.future)).reset(currentEmail);
      if (mounted) {
        setState(
          () => notice = say(
            'Password reset instructions were sent to your sign-in email.',
            'أُرسلت تعليمات إعادة تعيين كلمة المرور إلى بريد تسجيل الدخول.',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = say(
            'Password reset is unavailable right now. Try again later.',
            'إعادة تعيين كلمة المرور غير متاحة الآن. حاول لاحقًا.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(supabaseClientProvider).valueOrNull;
    final currentEmail = client?.auth.currentUser?.email ?? '';
    if (email.text.isEmpty && currentEmail.isNotEmpty) {
      email.text = currentEmail;
    }
    return SliceScaffold(
      title: say('Account Information', 'معلومات الحساب'),
      leading: IconButton(
        tooltip: say('Back', 'رجوع'),
        onPressed: busy ? null : () => context.go('/settings'),
        icon: const Icon(Icons.arrow_back),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SliceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  say(
                    'Change your sign-in email. Supabase will require email confirmation before the new address takes effect.',
                    'غيّر بريد تسجيل الدخول. سيطلب Supabase تأكيد البريد قبل تفعيل العنوان الجديد.',
                  ),
                ),
                const SizedBox(height: TokensV0.space16),
                TextField(
                  key: const Key('account-new-email'),
                  controller: email,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: say('Sign-in email', 'بريد تسجيل الدخول'),
                  ),
                ),
                const SizedBox(height: TokensV0.space12),
                PrimaryAction(
                  key: const Key('account-update-email'),
                  label: say('Send confirmation', 'إرسال التأكيد'),
                  busy: busy,
                  onPressed: updateEmail,
                ),
              ],
            ),
          ),
          const SizedBox(height: TokensV0.space16),
          SliceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  say(
                    'Reset your password using the existing verified email flow.',
                    'أعد تعيين كلمة المرور باستخدام مسار البريد الإلكتروني المعتمد.',
                  ),
                ),
                const SizedBox(height: TokensV0.space12),
                OutlinedButton(
                  key: const Key('account-reset-password'),
                  onPressed: busy || currentEmail.isEmpty
                      ? null
                      : () => resetPassword(currentEmail),
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
          if (notice != null || error != null) ...[
            const SizedBox(height: TokensV0.space16),
            Semantics(
              liveRegion: true,
              child: SliceCard(
                child: Text(
                  error ?? notice!,
                  style: TextStyle(
                    color: error == null
                        ? TokensV0.success
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
