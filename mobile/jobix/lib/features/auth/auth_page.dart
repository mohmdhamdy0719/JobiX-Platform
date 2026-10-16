import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/async_states.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/onboarding_controller.dart';
import '../personal_information/personal_information_validator.dart';
import 'auth_controller.dart';
import 'auth_notice.dart';
import 'provider_settings.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({this.mode = 'gateway', super.key});
  final String mode;
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false, obscure = true;
  AuthNoticeKind? notice;

  @override
  void didUpdateWidget(covariant AuthPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      form.currentState?.reset();
      email.clear();
      password.clear();
      notice = null;
      obscure = true;
    }
  }

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
    } catch (error) {
      final kind = authNoticeFor(error);
      if (!mounted) return;
      if (kind == AuthNoticeKind.notConfirmed && widget.mode == 'login') {
        // The account exists but is unconfirmed: offer the resend path.
        ref.read(pendingConfirmationEmailProvider.notifier).state = email.text
            .trim();
        context.go('/confirm');
        return;
      }
      setState(() => notice = kind);
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
      final registeredUser = await api.signUp(emailValue, passwordValue);
      // Bind first-install answers to this newly registered account only.
      // This is lifecycle metadata, not a change to Auth or confirmation.
      if (registeredUser != null) {
        final database = await container.read(databaseProvider.future);
        await database.setSetting('registration_user', registeredUser);
      }
      container.read(pendingConfirmationEmailProvider.notifier).state =
          emailValue.trim();
      container.invalidate(firstEntryProvider);
      if (mounted) context.go('/confirm');
    } else if (widget.mode == 'forgot') {
      await api.reset(emailValue);
      if (mounted) setState(() => notice = AuthNoticeKind.resetSent);
    } else if (widget.mode == 'recovery') {
      await api.updatePassword(passwordValue);
      container.read(authFlowProvider.notifier).state = const AuthFlow();
      if (mounted) context.go('/home');
    } else {
      container.read(authFlowProvider.notifier).state = const AuthFlow();
      await api.signIn(emailValue, passwordValue);
      container.invalidate(firstEntryProvider);
    }
  });

  Future<void> resend(String address) => run(() async {
    await (await ref.read(authApiProvider.future)).resendConfirmation(address);
    if (mounted) setState(() => notice = AuthNoticeKind.confirmationResent);
  });

  Future<void> google() => run(() async {
    ref.read(authFlowProvider.notifier).state = AuthFlow(
      registration: widget.mode == 'signup',
    );
    final opened = await (await ref.read(authApiProvider.future)).google();
    if (!opened && mounted) {
      setState(() => notice = AuthNoticeKind.googleUnavailable);
    }
  });

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final gateway = widget.mode == 'gateway';
    final confirm = widget.mode == 'confirm';
    final reset = widget.mode == 'forgot';
    final recovery = widget.mode == 'recovery';
    final signup = widget.mode == 'signup';
    final login = widget.mode == 'login';
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
    final subtitle = confirm
        ? copy.confirmEmailBody
        : signup
        ? copy.signupSubtitle
        : login
        ? copy.loginSubtitle
        : gateway
        ? copy.welcomeSubtitle
        : copy.authSubtitle;
    final flow = ref.watch(authFlowProvider);
    final pending = ref.watch(pendingConfirmationEmailProvider);
    final settings = ref.watch(authProviderSettingsProvider);
    final googleEnabled = settings.maybeWhen(
      data: (value) => value.googleEnabled,
      orElse: () => false,
    );
    return SliceScaffold(
      title: !gateway ? title : null,
      leading: gateway
          ? null
          : IconButton(
              tooltip: copy.backAction,
              icon: const Icon(Icons.arrow_back),
              onPressed: busy || recovery ? null : () => context.go('/auth'),
            ),
      fillViewport: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (gateway || signup || login)
                Center(child: BrandMark(size: gateway ? 92 : 64)),
              if (gateway || signup || login)
                SizedBox(height: gateway ? TokensV0.space32 : TokensV0.space24),
              if (gateway)
                Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: TokensV0.space8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                )
              else
                SectionHeading(title: title, subtitle: subtitle),
              const SizedBox(height: TokensV0.space24),
              if (notice != null || flow.error)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: TokensV0.space16,
                  ),
                  child: NoticePanel(
                    error: notice?.isError ?? true,
                    message: (notice ?? AuthNoticeKind.failure).localized(copy),
                  ),
                ),
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
                  child: Text(copy.loginAction),
                ),
                if (googleEnabled) ...[
                  const SizedBox(height: TokensV0.space12),
                  OutlinedButton.icon(
                    key: const Key('auth-google'),
                    onPressed: busy ? null : google,
                    icon: const Text(
                      'G',
                      style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontWeight: FontWeight.w700,
                        fontSize: 19,
                      ),
                    ),
                    label: Text(copy.googleSignIn),
                  ),
                ],
              ] else if (confirm) ...[
                PrimaryAction(
                  label: copy.loginAction,
                  onPressed: () => context.go('/auth?mode=login'),
                ),
                if (pending != null && pending.isNotEmpty) ...[
                  const SizedBox(height: TokensV0.space12),
                  OutlinedButton(
                    key: const Key('resend-confirmation'),
                    onPressed: busy ? null : () => resend(pending),
                    child: Text(copy.resendConfirmation),
                  ),
                ],
              ] else
                Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!recovery) ...[
                        _FieldLabel(label: copy.emailLabel),
                        TextFormField(
                          key: const Key('auth-email'),
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: reset
                              ? TextInputAction.done
                              : TextInputAction.next,
                          onFieldSubmitted: (_) {
                            if (reset && !busy) submit();
                          },
                          textDirection: TextDirection.ltr,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                            hintText: copy.emailExample,
                          ),
                          validator: (value) =>
                              value == null ||
                                  value.trim().isEmpty ||
                                  validatePersonalField('email', value) != null
                              ? copy.invalidEmail
                              : null,
                        ),
                      ],
                      if (!reset) ...[
                        const SizedBox(height: TokensV0.space16),
                        _FieldLabel(
                          label: recovery
                              ? copy.newPassword
                              : copy.passwordLabel,
                        ),
                        TextFormField(
                          key: const Key('auth-password'),
                          controller: password,
                          obscureText: obscure,
                          textDirection: TextDirection.ltr,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!busy) submit();
                          },
                          enableSuggestions: false,
                          autocorrect: false,
                          autofillHints: [
                            signup || recovery
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          decoration: InputDecoration(
                            hintText: recovery
                                ? copy.newPassword
                                : copy.passwordLabel,
                            suffixIcon: IconButton(
                              tooltip: obscure
                                  ? copy.showPassword
                                  : copy.hidePassword,
                              onPressed: () =>
                                  setState(() => obscure = !obscure),
                              icon: Icon(
                                obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? copy.passwordRequired
                              : null,
                        ),
                      ],
                      if ((login || signup) && settings.hasError) ...[
                        const SizedBox(height: TokensV0.space16),
                        NoticePanel(message: copy.providerSettingsUnavailable),
                        TextButton(
                          key: const Key('auth-provider-retry'),
                          onPressed: () =>
                              ref.invalidate(authProviderSettingsProvider),
                          child: Text(copy.retry),
                        ),
                      ],
                      if (signup) ...[
                        const SizedBox(height: TokensV0.space20),
                        Container(
                          padding: const EdgeInsetsDirectional.all(
                            TokensV0.space16,
                          ),
                          decoration: BoxDecoration(
                            color: TokensV0.secondarySurface,
                            border: Border.all(color: TokensV0.border),
                            borderRadius: BorderRadius.circular(
                              TokensV0.controlRadius,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 19,
                                color: TokensV0.textSecondary,
                              ),
                              const SizedBox(width: TokensV0.space12),
                              Expanded(
                                child: Text(
                                  copy.legalLinksUnavailable,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: TokensV0.textPrimary),
                                ),
                              ),
                            ],
                          ),
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
                            : copy.loginAction,
                      ),
                      if ((login || signup) && googleEnabled) ...[
                        const SizedBox(height: TokensV0.space12),
                        OutlinedButton(
                          key: const Key('auth-google'),
                          onPressed: busy ? null : google,
                          child: Text(copy.googleSignIn),
                        ),
                      ],
                      if (login) ...[
                        const SizedBox(height: TokensV0.space8),
                        TextButton(
                          onPressed: busy ? null : () => context.go('/forgot'),
                          child: Text(copy.forgotPassword),
                        ),
                      ],
                      if (signup || login) ...[
                        const SizedBox(height: TokensV0.space16),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => context.go(
                                  signup
                                      ? '/auth?mode=login'
                                      : '/auth?mode=signup',
                                ),
                          child: Text(
                            signup ? copy.haveAccount : copy.needAccount,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: TokensV0.space8),
    child: Text(label, style: Theme.of(context).textTheme.labelMedium),
  );
}
