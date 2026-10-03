import 'package:flutter/material.dart';

import 'tokens.dart';

/// Shared page frame: soft canvas, compact app bar and a centered scroll column.
class SliceScaffold extends StatelessWidget {
  const SliceScaffold({
    required this.child,
    this.title,
    this.leading,
    this.actions,
    this.bottom,
    super.key,
  });

  final Widget child;
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || leading != null || actions != null;
    return Scaffold(
      backgroundColor: TokensV0.canvas,
      body: SafeArea(
        bottom: bottom == null,
        child: Column(
          children: [
            if (hasHeader)
              _SliceHeader(title: title, leading: leading, actions: actions),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gutter = constraints.maxWidth >= 600
                      ? TokensV0.tabletGutter
                      : TokensV0.pageGutter;
                  return SingleChildScrollView(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      gutter,
                      TokensV0.space16,
                      gutter,
                      TokensV0.space32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: TokensV0.contentMaxWidth,
                        ),
                        child: SizedBox(width: double.infinity, child: child),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (bottom != null)
              SafeArea(
                top: false,
                minimum: const EdgeInsetsDirectional.only(
                  start: TokensV0.pageGutter,
                  end: TokensV0.pageGutter,
                  bottom: TokensV0.space12,
                ).resolve(Directionality.of(context)),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: TokensV0.contentMaxWidth,
                    ),
                    child: SizedBox(width: double.infinity, child: bottom),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SliceHeader extends StatelessWidget {
  const _SliceHeader({
    required this.title,
    required this.leading,
    required this.actions,
  });

  final String? title;
  final Widget? leading;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final titleWidget = title == null
        ? const SizedBox.shrink()
        : Text(
            title!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
            style: Theme.of(context).textTheme.headlineSmall,
          );

    return Material(
      color: TokensV0.canvas.withValues(alpha: 0.96),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: TokensV0.pageGutter,
          vertical: TokensV0.space8,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: TokensV0.border.withValues(alpha: 0.72)),
          ),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: TokensV0.space8),
            ],
            Expanded(child: titleWidget),
            if (actions != null)
              Flexible(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: TokensV0.space4,
                    children: actions!,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SliceCard extends StatelessWidget {
  const SliceCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TokensV0.space16),
      decoration: BoxDecoration(
        color: TokensV0.surfaceCard,
        borderRadius: BorderRadius.circular(TokensV0.cardRadius),
        border: Border.all(color: TokensV0.border.withValues(alpha: 0.62)),
        boxShadow: [
          BoxShadow(
            color: TokensV0.navy.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = busy ? null : onPressed;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: effectiveOnPressed == null && !busy ? 0.68 : 1,
        child: ElevatedButton(
          onPressed: effectiveOnPressed,
          style: ElevatedButton.styleFrom(
            elevation: 1,
            shadowColor: TokensV0.primary.withValues(alpha: 0.18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TokensV0.controlRadius),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: busy
                ? const SizedBox(
                    key: ValueKey<String>('busy'),
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TokensV0.onPrimary,
                    ),
                  )
                : Row(
                    key: const ValueKey<String>('ready'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: TokensV0.onPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (icon != null) ...[
                        const SizedBox(width: TokensV0.space8),
                        Icon(icon, size: 20),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = selected ? TokensV0.primary : TokensV0.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: TokensV0.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(TokensV0.cardRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsetsDirectional.all(TokensV0.space16),
            decoration: BoxDecoration(
              color: selected
                  ? TokensV0.surfaceContainerLow
                  : TokensV0.surfaceCard,
              borderRadius: BorderRadius.circular(TokensV0.cardRadius),
              border: Border.all(
                color: selected ? TokensV0.primary : TokensV0.border,
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: TokensV0.primary.withValues(alpha: 0.055),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: TokensV0.navy.withValues(alpha: 0.025),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 21, color: color),
                  const SizedBox(width: TokensV0.space12),
                ],
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.start,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: TokensV0.textPrimary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: TokensV0.space12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? TokensV0.primary
                        : TokensV0.surfaceContainer,
                    border: selected
                        ? null
                        : Border.all(color: TokensV0.divider),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check,
                          size: 13,
                          color: TokensV0.onPrimary,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: TextAlign.start,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: TokensV0.space4),
          Text(
            subtitle!,
            textAlign: TextAlign.start,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// An abstract, text-free resume visual inspired by the onboarding previews.
class OnboardingArt extends StatelessWidget {
  const OnboardingArt({required this.page, super.key});

  final int page;

  @override
  Widget build(BuildContext context) {
    final normalizedPage = page.clamp(0, 2);
    return AspectRatio(
      aspectRatio: 1.34,
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          PositionedDirectional(
            top: 8,
            end: 8,
            child: _ambientDisc(size: 110, color: TokensV0.primary),
          ),
          PositionedDirectional(
            bottom: 12,
            start: 8,
            child: _ambientDisc(size: 74, color: TokensV0.deepBlue),
          ),
          if (normalizedPage != 1)
            Transform.rotate(
              angle: -0.085,
              child: _miniDocument(
                width: 148,
                color: TokensV0.surfaceCard.withValues(alpha: 0.83),
                alignment: AlignmentDirectional.centerStart,
              ),
            ),
          if (normalizedPage == 2)
            Transform.translate(
              offset: const Offset(68, 4),
              child: Transform.rotate(
                angle: 0.085,
                child: _miniDocument(
                  width: 140,
                  color: TokensV0.surfaceCard.withValues(alpha: 0.88),
                  alignment: AlignmentDirectional.centerEnd,
                  rtl: true,
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(0, normalizedPage == 1 ? 0 : -2),
            child: _mainDocument(refined: normalizedPage == 1),
          ),
        ],
      ),
    );
  }

  Widget _ambientDisc({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.055),
      ),
    );
  }

  Widget _miniDocument({
    required double width,
    required Color color,
    required AlignmentGeometry alignment,
    bool rtl = false,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: width,
        height: 146,
        padding: const EdgeInsets.all(TokensV0.space12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(TokensV0.cardRadius),
          border: Border.all(color: TokensV0.border.withValues(alpha: 0.65)),
          boxShadow: [
            BoxShadow(
              color: TokensV0.navy.withValues(alpha: 0.055),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: rtl
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!rtl) _avatarDot(TokensV0.surfaceContainer),
                if (!rtl) const SizedBox(width: TokensV0.space8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: rtl
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      _line(
                        width: 54,
                        height: 5,
                        color: TokensV0.surfaceVariant,
                      ),
                      const SizedBox(height: TokensV0.space4),
                      _line(
                        width: 38,
                        height: 4,
                        color: TokensV0.surfaceContainer,
                      ),
                    ],
                  ),
                ),
                if (rtl) const SizedBox(width: TokensV0.space8),
                if (rtl) _avatarDot(TokensV0.primary.withValues(alpha: 0.12)),
              ],
            ),
            const SizedBox(height: TokensV0.space16),
            _line(
              width: double.infinity,
              height: 5,
              color: TokensV0.surfaceContainer,
            ),
            const SizedBox(height: TokensV0.space8),
            _line(
              width: width * 0.72,
              height: 5,
              color: TokensV0.surfaceVariant,
            ),
            const SizedBox(height: TokensV0.space8),
            _line(
              width: width * 0.56,
              height: 5,
              color: TokensV0.surfaceContainer,
            ),
            const Spacer(),
            Container(
              width: 52,
              height: 14,
              decoration: BoxDecoration(
                color: TokensV0.surfaceContainerLow,
                borderRadius: BorderRadius.circular(TokensV0.chipRadius),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mainDocument({required bool refined}) {
    return Container(
      width: 206,
      height: 204,
      padding: const EdgeInsets.all(TokensV0.space16),
      decoration: BoxDecoration(
        color: TokensV0.surfaceCard,
        borderRadius: BorderRadius.circular(TokensV0.panelRadius),
        border: Border.all(color: TokensV0.border.withValues(alpha: 0.78)),
        boxShadow: [
          BoxShadow(
            color: TokensV0.navy.withValues(alpha: 0.1),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: TokensV0.deepBlue,
                  borderRadius: BorderRadius.circular(TokensV0.chipRadius),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: TokensV0.onPrimary,
                  size: 16,
                ),
              ),
              const SizedBox(width: TokensV0.space8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line(width: 73, height: 6, color: TokensV0.navy),
                    const SizedBox(height: TokensV0.space4),
                    _line(width: 53, height: 4, color: TokensV0.disabled),
                  ],
                ),
              ),
              Icon(
                refined ? Icons.auto_awesome : Icons.check_circle_outline,
                size: 17,
                color: TokensV0.primary,
              ),
            ],
          ),
          const SizedBox(height: TokensV0.space16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(TokensV0.space12),
            decoration: BoxDecoration(
              color: TokensV0.surfaceContainerLow,
              borderRadius: BorderRadius.circular(TokensV0.chipRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line(width: 64, height: 5, color: TokensV0.primary),
                const SizedBox(height: TokensV0.space8),
                _line(
                  width: double.infinity,
                  height: 5,
                  color: TokensV0.surfaceVariant,
                ),
                const SizedBox(height: TokensV0.space8),
                _line(width: 116, height: 5, color: TokensV0.surfaceVariant),
              ],
            ),
          ),
          const SizedBox(height: TokensV0.space12),
          Row(
            children: [
              _skillPill(width: 53),
              const SizedBox(width: TokensV0.space4),
              _skillPill(width: 47),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(Icons.trending_up, size: 16, color: TokensV0.primary),
              const SizedBox(width: TokensV0.space8),
              Expanded(
                child: _line(
                  width: 112,
                  height: 5,
                  color: TokensV0.surfaceContainer,
                ),
              ),
              const Icon(Icons.check_circle, size: 16, color: TokensV0.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatarDot(Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _line({
    required double width,
    required double height,
    required Color color,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(TokensV0.pillRadius),
      ),
    );
  }

  Widget _skillPill({required double width}) {
    return Container(
      width: width,
      height: 16,
      decoration: BoxDecoration(
        color: TokensV0.surfaceContainerLow,
        borderRadius: BorderRadius.circular(TokensV0.chipRadius),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 48, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/brand/logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            alignment: AlignmentDirectional.center,
            decoration: BoxDecoration(
              color: TokensV0.surfaceCard,
              borderRadius: BorderRadius.circular(TokensV0.controlRadius),
              border: Border.all(color: TokensV0.border),
            ),
            child: Text(
              'Jobix',
              maxLines: 1,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: TokensV0.deepBlue,
                fontSize: size * 0.23,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.35,
              ),
            ),
          );
        },
      ),
    );
  }
}
