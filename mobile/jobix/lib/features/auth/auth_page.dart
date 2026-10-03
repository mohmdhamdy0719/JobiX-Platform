import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/app_language_button.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/onboarding_controller.dart';
import 'auth_controller.dart';
import '../personal_information/personal_information_validator.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({this.mode = 'gateway', super.key});
  final String mode;
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false, obscure = true;
  String? notice;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() operation) async {
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        setState(() => notice = AppLocalizations.of(context)!.authError);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() => run(() async {
    if (!form.currentState!.validate()) return;
    final container = ProviderScope.containerOf(context);
    final emailValue = email.text, passwordValue = password.text;
    final api = await container.read(authApiProvider.future);
    if (widget.mode == 'signup') {
      container.read(authFlowProvider.notifier).state = const AuthFlow(
        registration: true,
      );
      await api.signUp(emailValue, passwordValue);
      container.invalidate(firstEntryProvider);
      if (mounted) context.go('/confirm');
    } else if (widget.mode == 'forgot') {
      await api.reset(emailValue);
      if (mounted) {
        setState(() => notice = AppLocalizations.of(context)!.resetSent);
      }
    } else if (widget.mode == 'recovery') {
      await api.updatePassword(passwordValue);
      container.read(authFlowProvider.notifier).state = const AuthFlow();
      if (mounted) context.go('/home');
    } else {
      // New-entry routing uses server-owned account metadata, never form intent.
      container.read(authFlowProvider.notifier).state = const AuthFlow();
      await api.signIn(emailValue, passwordValue);
      container.invalidate(firstEntryProvider);
    }
  });
  Future<void> google() => run(() async {
    ref.read(authFlowProvider.notifier).state = AuthFlow(
      registration: widget.mode == 'signup',
    );
    final opened = await (await ref.read(authApiProvider.future)).google();
    if (!opened && mounted) {
      setState(() => notice = AppLocalizations.of(context)!.googleUnavailable);
    }
  });
  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final gateway = widget.mode == 'gateway';
    final confirm = widget.mode == 'confirm';
    final reset = widget.mode == 'forgot', recovery = widget.mode == 'recovery';
    final signup = widget.mode == 'signup';
    final title = confirm
        ? copy.confirmEmail
        : recovery
        ? copy.newPassword
        : reset
        ? copy.forgotPassword
        : signup
        ? copy.createAccount
        : gateway
        ? copy.welcome
        : copy.existingAccount;
    final flow = ref.watch(authFlowProvider);
    return SliceScaffold(
      title: !gateway ? title : null,
      leading: gateway
          ? const BrandMark(size: 36)
          : IconButton(
              tooltip: copy.backAction,
              icon: const Icon(Icons.arrow_back),
              onPressed: busy || recovery ? null : () => context.go('/auth'),
            ),
      actions: const [AppLanguageButton()],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: BrandMark(size: 76)),
          const SizedBox(height: TokensV0.space24),
          SectionHeading(
            title: title,
            subtitle: confirm ? copy.confirmEmailBody : copy.authSubtitle,
          ),
          const SizedBox(height: TokensV0.space24),
          if (notice != null || flow.error) ...[
            SliceCard(child: Text(notice ?? copy.authError)),
            const SizedBox(height: TokensV0.space16),
          ],
          if (gateway) ...[
            PrimaryAction(
              label: copy.createAccount,
              onPressed: () async {
                final progress = await ref.read(researchProvider.future);
                if (context.mounted) {
                  context.go(
                    progress.complete ? '/auth?mode=signup' : '/onboarding',
                  );
                }
              },
            ),
            const SizedBox(height: TokensV0.space12),
            OutlinedButton(
              onPressed: () => context.go('/auth?mode=login'),
              child: Text(copy.existingAccount),
            ),
            const SizedBox(height: TokensV0.space24),
            SliceCard(child: Text(copy.contextOnly)),
          ] else if (confirm) ...[
            PrimaryAction(
              label: copy.existingAccount,
              onPressed: () => context.go('/auth?mode=login'),
            ),
          ] else
            Form(
              key: form,
              child: Column(
                children: [
                  if (!recovery)
                    TextFormField(
                      key: const Key('auth-email'),
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(labelText: copy.emailLabel),
                      validator: (value) =>
                          value == null ||
                              value.trim().isEmpty ||
                              validatePersonalField('email', value) != null
                          ? copy.invalidEmail
                          : null,
                    ),
                  if (!reset) ...[
                    const SizedBox(height: TokensV0.space16),
                    TextFormField(
                      key: const Key('auth-password'),
                      controller: password,
                      obscureText: obscure,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: [
                        signup || recovery
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: recovery
                            ? copy.newPassword
                            : copy.passwordLabel,
                        suffixIcon: IconButton(
                          tooltip: copy.showPassword,
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? copy.passwordLabel
                          : null,
                    ),
                  ],
                  const SizedBox(height: TokensV0.space24),
                  PrimaryAction(
                    key: const Key('auth-submit'),
                    busy: busy,
                    onPressed: submit,
                    label: recovery
                        ? copy.updatePassword
                        : reset
                        ? copy.sendReset
                        : signup
                        ? copy.createAccount
                        : copy.existingAccount,
                  ),
                  if (!reset && !recovery) ...[
                    const SizedBox(height: TokensV0.space12),
                    OutlinedButton(
                      key: const Key('auth-google'),
                      onPressed: busy ? null : google,
                      child: Text(copy.googleSignIn),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => context.go('/forgot'),
                      child: Text(copy.forgotPassword),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
