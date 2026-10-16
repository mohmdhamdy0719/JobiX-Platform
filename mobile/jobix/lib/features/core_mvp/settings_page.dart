import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_language_button.dart';
import '../../core/design/jobix_dialog.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../builder/entity_labels.dart';
import 'authenticated_navigation.dart';

/// Real name (Career Profile) and sign-in email; nothing invented.
class _AccountHeader extends ConsumerWidget {
  const _AccountHeader();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name =
        ref
            .watch(firstProfileProvider)
            .valueOrNull
            ?.personal['full_name']
            ?.trim() ??
        '';
    final email =
        ref
            .watch(supabaseClientProvider)
            .valueOrNull
            ?.auth
            .currentUser
            ?.email ??
        '';
    if (name.isEmpty && email.isEmpty) return const SizedBox.shrink();
    return SliceCard(
      key: const Key('settings-account-header'),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: TokensV0.surfaceContainerLow,
            foregroundColor: TokensV0.deepBlue,
            child: name.isEmpty
                ? const Icon(Icons.person_outline)
                : Text(
                    initials(name),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(width: TokensV0.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name.isNotEmpty)
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: TokensV0.textSecondary,
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

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = AppLocalizations.of(context)!;
    return SliceScaffold(
      title: copy.settingsNav,
      leading: const BrandMark(size: 32),
      bottom: const AuthenticatedNavigation(selected: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AccountHeader(),
          const SizedBox(height: TokensV0.space20),
          _SettingsGroup(
            title: copy.accountSection,
            children: [
              ref
                  .watch(supabaseClientProvider)
                  .when(
                    loading: () => const _AccountLoadingRow(),
                    error: (_, __) => _SettingsRow(
                      icon: Icons.person_outline,
                      title: copy.accountInformation,
                      subtitle: copy.accountInfoUnavailable,
                      enabled: false,
                    ),
                    data: (client) => _SettingsRow(
                      icon: Icons.person_outline,
                      title: copy.accountInformation,
                      subtitle:
                          client.auth.currentUser?.email ??
                          copy.accountInfoUnavailable,
                      enabled: false,
                    ),
                  ),
              _SettingsRow(
                icon: Icons.contact_page_outlined,
                title: copy.personalInformation,
                subtitle: copy.personalInfoSettingsHint,
                onTap: () => context.go('/career/personal'),
              ),
            ],
          ),
          const SizedBox(height: TokensV0.space16),
          _SettingsGroup(
            title: copy.preferencesSection,
            children: [
              _SettingsRow(
                icon: Icons.translate,
                title: copy.languageSwitch,
                subtitle: copy.languageSettingsHint,
                trailing: const AppLanguageButton(),
              ),
            ],
          ),
          const SizedBox(height: TokensV0.space16),
          _SettingsGroup(
            title: copy.careerDataSection,
            children: [
              _SettingsRow(
                icon: Icons.history,
                title: copy.creditHistoryTitle,
                subtitle: copy.creditHistorySubtitle,
                onTap: () => context.go('/credits'),
              ),
            ],
          ),
          const SizedBox(height: TokensV0.space16),
          _SettingsGroup(
            title: copy.supportSection,
            children: [
              _SettingsRow(
                icon: Icons.support_agent_outlined,
                title: copy.contactUs,
                subtitle: copy.serviceNotConfigured,
                enabled: false,
              ),
            ],
          ),
          const SizedBox(height: TokensV0.space16),
          _SettingsGroup(
            title: copy.legalSection,
            children: [
              _SettingsRow(
                icon: Icons.privacy_tip_outlined,
                title: copy.privacyPolicy,
                subtitle: copy.legalUnavailable,
                enabled: false,
              ),
              _SettingsRow(
                icon: Icons.description_outlined,
                title: copy.termsOfService,
                subtitle: copy.legalUnavailable,
                enabled: false,
              ),
            ],
          ),
          const SizedBox(height: TokensV0.space16),
          _SettingsGroup(
            title: copy.accountActionsSection,
            children: [
              _SettingsRow(
                key: const Key('settings-sign-out'),
                icon: Icons.logout,
                title: copy.signOut,
                subtitle: copy.signOutLocalWarning,
                onTap: () => _confirmSignOut(context, ref, copy),
              ),
            ],
          ),
          const SizedBox(height: TokensV0.space20),
          Center(
            child: Text(
              copy.settingsFooter,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations copy,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => JobixAlertDialog(
        title: Text(copy.signOut),
        content: Text(copy.signOutLocalWarning),
        actions: [
          JobixDialogAction.secondary(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(copy.stayAction),
          ),
          JobixDialogAction.destructive(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(copy.signOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await signOutAndWipe(ref);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(copy.signOutFailed)));
      }
    }
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(
          start: TokensV0.space4,
          bottom: TokensV0.space8,
        ),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: TokensV0.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ),
      SliceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0)
                const Divider(height: 1, indent: 56, endIndent: 16),
              children[index],
            ],
          ],
        ),
      ),
    ],
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.enabled = true,
    super.key,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: TokensV0.space12,
          vertical: TokensV0.space8,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: TokensV0.iconSize,
              color: enabled ? TokensV0.deepBlue : TokensV0.disabled,
            ),
            const SizedBox(width: TokensV0.space12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelMedium),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (onTap != null)
              const Icon(Icons.chevron_right, color: TokensV0.textSecondary),
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TokensV0.cardRadius),
        child: content,
      ),
    );
  }
}

class _AccountLoadingRow extends StatelessWidget {
  const _AccountLoadingRow();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsetsDirectional.all(TokensV0.space16),
    child: Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: TokensV0.surfaceContainer,
            borderRadius: BorderRadius.all(
              Radius.circular(TokensV0.controlRadius),
            ),
          ),
          child: SizedBox(width: 24, height: 24),
        ),
        SizedBox(width: TokensV0.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: TokensV0.surfaceContainer,
                  borderRadius: BorderRadius.all(
                    Radius.circular(TokensV0.chipRadius),
                  ),
                ),
                child: SizedBox(width: 136, height: 14),
              ),
              SizedBox(height: TokensV0.space8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: TokensV0.surfaceContainer,
                  borderRadius: BorderRadius.all(
                    Radius.circular(TokensV0.chipRadius),
                  ),
                ),
                child: SizedBox(width: 184, height: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
