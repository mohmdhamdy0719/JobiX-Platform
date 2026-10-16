import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

class SliceScaffold extends StatelessWidget {
  const SliceScaffold({
    required this.child,
    this.title,
    this.leading,
    this.actions,
    this.bottom,
    this.header,
    this.subheader,
    this.singleLineTitle = false,
    this.canvasColor = TokensV0.canvas,
    this.fillViewport = false,
    super.key,
  });
  final Widget child;
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? bottom;
  final Widget? header;
  // Rendered under the standard title row (e.g. builder progress).
  final Widget? subheader;

  /// Builder headers keep their title on one line, scaling down only as needed.
  final bool singleLineTitle;
  final Color canvasColor;
  final bool fillViewport;

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || leading != null || actions != null;
    return Scaffold(
      backgroundColor: canvasColor,
      body: SafeArea(
        bottom: bottom == null,
        child: Column(
          children: [
            if (header != null)
              header!
            else if (hasHeader)
              _SliceHeader(
                title: title,
                leading: leading,
                actions: actions,
                singleLineTitle: singleLineTitle,
              ),
            if (subheader != null) subheader!,
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gutter = constraints.maxWidth >= 600
                      ? TokensV0.tabletGutter
                      : TokensV0.pageGutter;
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsetsDirectional.fromSTEB(
                      gutter,
                      TokensV0.space20,
                      gutter,
                      TokensV0.space32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: TokensV0.contentMaxWidth,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: fillViewport
                                ? (constraints.maxHeight -
                                          TokensV0.space20 -
                                          TokensV0.space32)
                                      .clamp(0, double.infinity)
                                : 0,
                          ),
                          child: SizedBox(width: double.infinity, child: child),
                        ),
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
    required this.singleLineTitle,
  });
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool singleLineTitle;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 64),
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: TokensV0.pageGutter,
      vertical: TokensV0.space8,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: TokensV0.border)),
    ),
    child: Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: TokensV0.space8),
        ],
        Expanded(
          child: title == null
              ? const SizedBox.shrink()
              : singleLineTitle
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    final theme = Theme.of(context);
                    final base = theme.textTheme.headlineSmall!;
                    final scaler = MediaQuery.textScalerOf(context);
                    final painter = TextPainter(
                      text: TextSpan(text: title!, style: base),
                      maxLines: 1,
                      textDirection: Directionality.of(context),
                      textScaler: scaler,
                    )..layout();
                    final baseSize = base.fontSize ?? 24;
                    final minimumSize = scaler.scale(14);
                    final ratio =
                        painter.width <= constraints.maxWidth ||
                            painter.width == 0
                        ? 1.0
                        : constraints.maxWidth / painter.width;
                    final fontSize = math.max(minimumSize, baseSize * ratio);
                    return Text(
                      title!,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: base.copyWith(fontSize: fontSize),
                    );
                  },
                )
              : Text(
                  title!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
        ),
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
  );
}

class SliceCard extends StatelessWidget {
  const SliceCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: TokensV0.surfaceCard,
      borderRadius: BorderRadius.circular(TokensV0.cardRadius),
      border: Border.all(color: TokensV0.border),
    ),
    child: child,
  );
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
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: TokensV0.actionHeight),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        child: AnimatedSwitcher(
          duration: motionDuration(context, TokensV0.motionContent),
          child: busy
              ? const SizedBox(
                  key: ValueKey('busy'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: TokensV0.onPrimary,
                  ),
                )
              : Row(
                  key: const ValueKey('ready'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text(label, textAlign: TextAlign.center)),
                    if (icon != null) ...[
                      const SizedBox(width: 8),
                      Icon(icon, size: 19),
                    ],
                  ],
                ),
        ),
      ),
    ),
  );
}

class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.multiple = false,
    super.key,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool multiple;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: TokensV0.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(TokensV0.controlRadius),
          child: AnimatedContainer(
            duration: motionDuration(context, TokensV0.motionFeedback),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? TokensV0.surfaceContainerLow
                  : TokensV0.surfaceCard,
              borderRadius: BorderRadius.circular(TokensV0.controlRadius),
              border: Border.all(
                color: selected ? TokensV0.primary : TokensV0.border,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 20,
                    color: selected ? TokensV0.primary : TokensV0.textSecondary,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: motionDuration(context, TokensV0.motionFeedback),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(multiple ? 5 : 20),
                    color: selected ? TokensV0.primary : TokensV0.surfaceCard,
                    border: Border.all(
                      color: selected ? TokensV0.primary : TokensV0.divider,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check,
                          size: 14,
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ],
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 48, this.dark = true, super.key});
  final double size;
  final bool dark;
  @override
  Widget build(BuildContext context) => Image.asset(
    dark ? 'assets/brand/logo_dark.png' : 'assets/brand/logo.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
  );
}
