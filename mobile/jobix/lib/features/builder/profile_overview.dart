import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../career_profile/career_profile.dart';
import '../career_profile/profile_sections.dart';
import '../core_mvp/core_api.dart';

/// First builder step that still has nothing saved; Review when all do.
int nextBuilderStep(CareerProfile profile) {
  final personal = ['full_name', 'email', 'phone'];
  if (personal.any((f) => (profile.personal[f] ?? '').trim().isEmpty)) {
    return 1;
  }
  if (profile.summary.trim().isEmpty) return 2;
  if (profile.count(EntitySection.experience) == 0) return 3;
  if (profile.count(EntitySection.education) == 0) return 4;
  if (profile.count(EntitySection.skill) == 0 ||
      profile.count(EntitySection.language) == 0) {
    return 5;
  }
  return 6;
}

/// Sections with nothing saved yet (contact, summary and the five lists
/// that carry completeness weight).
int sectionsRemaining(CareerProfile profile) {
  var count = 0;
  if (!profile.hasContact) count++;
  if (profile.summary.trim().isEmpty) count++;
  for (final s in [
    EntitySection.experience,
    EntitySection.education,
    EntitySection.skill,
    EntitySection.language,
  ]) {
    if (profile.count(s) == 0) count++;
  }
  return count;
}

/// Authoritative balance chip; hidden while unavailable (never a guess).
class CreditsPill extends ConsumerWidget {
  const CreditsPill({this.compact = false, super.key});
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = AppLocalizations.of(context)!;
    final summary = ref.watch(coreSummaryProvider).valueOrNull;
    if (summary == null) return const SizedBox.shrink();
    return Material(
      color: TokensV0.surfaceContainerLow,
      borderRadius: BorderRadius.circular(TokensV0.pillRadius),
      child: InkWell(
        key: const Key('credits-pill'),
        borderRadius: BorderRadius.circular(TokensV0.pillRadius),
        onTap: () => context.go('/credits'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.toll_outlined,
                size: 16,
                color: TokensV0.deepBlue,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  compact
                      ? copy.creditsCompactCount(summary.balance.available)
                      : copy.creditsCount(summary.balance.available),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: compact ? TextDirection.ltr : null,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: TokensV0.deepBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompletenessRing extends StatelessWidget {
  const CompletenessRing({required this.percent, this.size = 64, super.key});
  final double percent;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _RingPainter(percent.clamp(0, 100) / 100),
      child: Center(
        child: Text(
          '${percent.toStringAsFixed(0)}%',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.1;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final arc = rect.deflate(stroke / 2);
    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      paint..color = TokensV0.surfaceContainer,
    );
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      paint..color = TokensV0.primary,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}
