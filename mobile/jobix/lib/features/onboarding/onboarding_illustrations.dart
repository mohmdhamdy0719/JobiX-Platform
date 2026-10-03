import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// Quiet, text-free artwork for the three introduction pages.
/// The whole illustration is decorative and is intentionally absent from
/// the accessibility tree.
class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({
    required this.page,
    required this.height,
    super.key,
  });

  final int page;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: switch (page) {
                0 => const _ProfileArtwork(),
                1 => const _RefinementArtwork(),
                _ => const _ExportArtwork(),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtworkSurface extends StatelessWidget {
  const _ArtworkSurface({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: TokensV0.surfaceCard,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: TokensV0.border.withValues(alpha: .75)),
      boxShadow: [
        BoxShadow(
          color: TokensV0.navy.withValues(alpha: .075),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: TokensV0.navy.withValues(alpha: .025),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: child,
  );
}

class _Line extends StatelessWidget {
  const _Line({this.width, this.height = 7, this.color});

  final double? width;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color ?? TokensV0.surfaceContainerLow,
      borderRadius: BorderRadius.circular(TokensV0.pillRadius),
    ),
  );
}

class _ProfileArtwork extends StatelessWidget {
  const _ProfileArtwork();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 270;
        return Center(
          child: FractionallySizedBox(
            widthFactor: .96,
            child: _ArtworkSurface(
              padding: EdgeInsets.all(compact ? 17 : 21),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 43,
                        height: 43,
                        decoration: BoxDecoration(
                          color: TokensV0.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          color: TokensV0.primary,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            _Line(
                              width: 112,
                              height: 9,
                              color: TokensV0.surfaceContainerHigh,
                            ),
                            SizedBox(height: 8),
                            _Line(width: 152, height: 7),
                          ],
                        ),
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: TokensV0.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          size: 18,
                          color: TokensV0.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 10 : 20),
                  const _Line(
                    width: 112,
                    height: 8,
                    color: TokensV0.primaryHover,
                  ),
                  const SizedBox(height: 10),
                  const _Line(height: 8),
                  const SizedBox(height: 7),
                  const _Line(width: 204, height: 8),
                  SizedBox(height: compact ? 10 : 19),
                  Container(height: 1, color: TokensV0.border),
                  SizedBox(height: compact ? 10 : 17),
                  Row(
                    children: [
                      const Expanded(child: _Pill()),
                      const SizedBox(width: 8),
                      const Expanded(child: _Pill()),
                      const SizedBox(width: 8),
                      const Expanded(child: _Pill()),
                    ],
                  ),
                  SizedBox(height: compact ? 10 : 17),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TokensV0.secondarySurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: TokensV0.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.trending_up_rounded,
                            size: 17,
                            color: TokensV0.primary,
                          ),
                        ),
                        const SizedBox(width: 11),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Line(
                                width: 100,
                                height: 7,
                                color: TokensV0.surfaceContainerHigh,
                              ),
                              SizedBox(height: 7),
                              _Line(height: 6),
                              SizedBox(height: 5),
                              _Line(width: 144, height: 6),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: TokensV0.success,
                          size: 19,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill();

  @override
  Widget build(BuildContext context) => Container(
    height: 23,
    decoration: BoxDecoration(
      color: TokensV0.surfaceContainerLow,
      borderRadius: BorderRadius.circular(TokensV0.pillRadius),
    ),
    alignment: Alignment.center,
    child: Container(
      width: 42,
      height: 5,
      decoration: BoxDecoration(
        color: TokensV0.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(TokensV0.pillRadius),
      ),
    ),
  );
}

class _RefinementArtwork extends StatelessWidget {
  const _RefinementArtwork();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 270;
        return Center(
          child: FractionallySizedBox(
            widthFactor: .96,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ArtworkSurface(
                  padding: compact
                      ? const EdgeInsets.all(12)
                      : const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                  radius: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          _Line(
                            width: 86,
                            height: 7,
                            color: TokensV0.surfaceContainerHigh,
                          ),
                          Spacer(),
                          Icon(
                            Icons.edit_note_rounded,
                            color: TokensV0.disabled,
                            size: 20,
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 9 : 14),
                      const _Line(height: 7),
                      const SizedBox(height: 7),
                      const _Line(width: 214, height: 7),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 4 : 10),
                Container(
                  width: 44,
                  height: compact ? 22 : 30,
                  decoration: BoxDecoration(
                    color: TokensV0.primary,
                    borderRadius: BorderRadius.circular(TokensV0.pillRadius),
                    boxShadow: [
                      BoxShadow(
                        color: TokensV0.primary.withValues(alpha: .2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.south_rounded,
                    color: TokensV0.onPrimary,
                    size: 19,
                  ),
                ),
                SizedBox(height: compact ? 4 : 10),
                _ArtworkSurface(
                  padding: compact
                      ? const EdgeInsets.all(12)
                      : const EdgeInsets.symmetric(
                          horizontal: 19,
                          vertical: 15,
                        ),
                  radius: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: TokensV0.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const _Line(
                            width: 104,
                            height: 8,
                            color: TokensV0.primaryHover,
                          ),
                          const Spacer(),
                          Container(
                            width: 39,
                            height: 20,
                            decoration: BoxDecoration(
                              color: TokensV0.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 8 : 16),
                      const _Line(
                        height: 7,
                        color: TokensV0.surfaceContainerHigh,
                      ),
                      SizedBox(height: compact ? 5 : 7),
                      const _Line(
                        width: 225,
                        height: 7,
                        color: TokensV0.surfaceContainerHigh,
                      ),
                      SizedBox(height: compact ? 5 : 7),
                      const _Line(
                        width: 164,
                        height: 7,
                        color: TokensV0.surfaceContainerHigh,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 7 : 8),
                Row(
                  children: const [
                    Expanded(child: _StaticChoice(icon: Icons.undo_rounded)),
                    SizedBox(width: 9),
                    Expanded(
                      child: _StaticChoice(
                        icon: Icons.check_rounded,
                        selected: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StaticChoice extends StatelessWidget {
  const _StaticChoice({required this.icon, this.selected = false});
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    decoration: BoxDecoration(
      color: selected ? TokensV0.surfaceContainerLow : TokensV0.surfaceCard,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: selected ? TokensV0.surfaceContainerHigh : TokensV0.border,
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 17,
          color: selected ? TokensV0.primary : TokensV0.textSecondary,
        ),
        const SizedBox(width: 9),
        Container(
          width: 34,
          height: 5,
          decoration: BoxDecoration(
            color: selected
                ? TokensV0.surfaceVariant
                : TokensV0.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ],
    ),
  );
}

class _ExportArtwork extends StatelessWidget {
  const _ExportArtwork();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 270;
        final cardWidth = math.min(constraints.maxWidth * .76, 276.0);
        final sheetWidth = cardWidth * .72;
        return Center(
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Transform.rotate(
                  angle: -.105,
                  child: _sideSheet(sheetWidth, compact, true),
                ),
                Transform.rotate(
                  angle: .105,
                  child: _sideSheet(sheetWidth, compact, false),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _ArtworkSurface(
                    padding: EdgeInsets.all(compact ? 17 : 21),
                    radius: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 38,
                              decoration: BoxDecoration(
                                color: TokensV0.deepBlue,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.description_outlined,
                                color: TokensV0.onPrimary,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 11),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Line(
                                    width: 84,
                                    height: 8,
                                    color: TokensV0.surfaceContainerHigh,
                                  ),
                                  SizedBox(height: 7),
                                  _Line(width: 78, height: 6),
                                ],
                              ),
                            ),
                            Container(
                              width: 34,
                              height: 25,
                              decoration: BoxDecoration(
                                color: TokensV0.errorContainer,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Icon(
                                Icons.picture_as_pdf_outlined,
                                color: TokensV0.error,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 17 : 23),
                        const _Line(
                          width: 93,
                          height: 7,
                          color: TokensV0.surfaceContainerHigh,
                        ),
                        const SizedBox(height: 11),
                        const _Line(height: 7),
                        const SizedBox(height: 7),
                        const _Line(width: 162, height: 7),
                        const SizedBox(height: 7),
                        const _Line(width: 145, height: 7),
                        SizedBox(height: compact ? 19 : 25),
                        Container(height: 1, color: TokensV0.border),
                        SizedBox(height: compact ? 12 : 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Icon(
                              Icons.ios_share_rounded,
                              color: TokensV0.textSecondary,
                              size: 18,
                            ),
                            const SizedBox(width: 14),
                            Container(
                              width: 29,
                              height: 29,
                              decoration: BoxDecoration(
                                color: TokensV0.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(
                                Icons.download_rounded,
                                color: TokensV0.primary,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sideSheet(double width, bool compact, bool left) {
    return Transform.translate(
      offset: Offset(left ? -width * .31 : width * .31, compact ? 3 : 7),
      child: Opacity(
        opacity: .8,
        child: SizedBox(
          width: width,
          height: compact ? 169 : 208,
          child: _ArtworkSurface(
            padding: const EdgeInsets.all(14),
            radius: 15,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Line(width: 62, height: 7),
                SizedBox(height: 12),
                _Line(height: 6),
                SizedBox(height: 7),
                _Line(width: 98, height: 6),
                SizedBox(height: 7),
                _Line(width: 74, height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
