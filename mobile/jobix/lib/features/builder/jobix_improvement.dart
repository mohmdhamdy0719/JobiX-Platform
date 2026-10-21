import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'ai_allowance.dart';

/// Only server-returned allowance values may be supplied. Null means unknown,
/// never zero. No client-side counters, entitlement assumptions, or ATS claims.
class JobixAllowance extends ConsumerWidget {
  const JobixAllowance({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = AppLocalizations.of(context)!.localeName.startsWith('ar');
    final allowance = ref.watch(aiAllowanceProvider);
    final current = allowance.valueOrNull;
    final now = DateTime.now();
    final future =
        current != null &&
        current.availableFrom.isAfter(DateTime(now.year, now.month, now.day));
    return Semantics(
      key: const Key('jobix-allowance'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TokensV0.space8),
        child: Row(
          children: [
            const Icon(
              Icons.auto_awesome_outlined,
              size: 16,
              color: TokensV0.primary,
            ),
            const SizedBox(width: TokensV0.space8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (allowance.isLoading)
                    Semantics(
                      label: ar
                          ? 'جار التحقق من الحصة'
                          : 'Checking AI allowance',
                      child: Container(
                        width: 160,
                        height: 12,
                        decoration: BoxDecoration(
                          color: TokensV0.surfaceContainer,
                          borderRadius: BorderRadius.circular(TokensV0.space4),
                        ),
                      ),
                    )
                  else
                    Text(
                      current != null && !allowance.hasError
                          ? (ar
                                ? 'إنشاءات الذكاء الاصطناعي: \u2066${current.used} / ${current.limit}\u2069 مستخدمة'
                                : 'AI generations: ${current.used} / ${current.limit} used')
                          : (ar
                                ? 'إنشاءات الذكاء الاصطناعي — الحصة غير متاحة'
                                : 'AI generations — allowance unavailable'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  Text(
                    ar
                        ? 'مزود الذكاء الاصطناعي غير متاح'
                        : 'AI provider unavailable',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (future && !allowance.hasError && !allowance.isLoading)
                    Text(
                      '${ar ? 'الحصة متاحة من' : 'Allowance available from'} ${DateFormat.yMMMd(ar ? 'ar' : 'en').format(current.availableFrom)} ${ar ? '(تاريخ القاهرة)' : '(Cairo date)'}',
                      key: const Key('jobix-allowance-deferred'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Presentation contract for an authoritative proposal. Proposal is never
/// inserted into the editor automatically. The caller owns request/history/
/// acceptance persistence, version checks, and any reservation lifecycle.
class JobixImprovement extends StatefulWidget {
  const JobixImprovement({
    required this.original,
    this.proposal,
    this.onGenerate,
    this.onKeepMine,
    this.onAccept,
    this.onEditBeforeAccepting,
    this.generating = false,
    this.error,
    super.key,
  });
  final String original;
  final String? proposal, error;
  final VoidCallback? onGenerate, onKeepMine, onEditBeforeAccepting;
  final ValueChanged<String>? onAccept;
  final bool generating;

  @override
  State<JobixImprovement> createState() => _JobixImprovementState();
}

class _JobixImprovementState extends State<JobixImprovement> {
  bool showProposal = true;

  @override
  Widget build(BuildContext context) {
    final ar = AppLocalizations.of(context)!.localeName.startsWith('ar');
    String say(String en, String arabic) => ar ? arabic : en;
    final proposal = widget.proposal;
    return Container(
      key: const Key('jobix-improvement'),
      padding: const EdgeInsets.all(TokensV0.space16),
      decoration: BoxDecoration(
        color: TokensV0.surfaceContainerLow,
        borderRadius: BorderRadius.circular(TokensV0.panelRadius),
        border: Border.all(color: TokensV0.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                color: TokensV0.primary,
                size: 20,
              ),
              const SizedBox(width: TokensV0.space8),
              Expanded(
                child: Text(
                  say('JobiX AI Agent', 'مساعد JobiX بالذكاء الاصطناعي'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: TokensV0.space8),
          Text(
            say(
              'Write in your own words. Add relevant details, and JobiX can help make your wording clear, professional, and ATS-friendly.',
              'اكتب بأسلوبك. أضف التفاصيل المهمة، ويمكن لـ JobiX مساعدتك في صياغتها بوضوح ومهنية وبما يناسب أنظمة تتبع المتقدمين.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: TokensV0.space12),
          if (widget.generating)
            const _ProposalSkeleton()
          else if (proposal != null) ...[
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(say('Original', 'الأصل')),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(say('Proposal', 'الاقتراح')),
                ),
              ],
              selected: {showProposal},
              onSelectionChanged: (value) =>
                  setState(() => showProposal = value.single),
            ),
            const SizedBox(height: TokensV0.space12),
            Container(
              padding: const EdgeInsets.all(TokensV0.space12),
              decoration: BoxDecoration(
                color: TokensV0.surfaceCard,
                borderRadius: BorderRadius.circular(TokensV0.controlRadius),
              ),
              child: SelectableText(showProposal ? proposal : widget.original),
            ),
            const SizedBox(height: TokensV0.space12),
            Wrap(
              spacing: TokensV0.space8,
              runSpacing: TokensV0.space8,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: widget.onKeepMine,
                  child: Text(say('Keep Mine', 'الاحتفاظ بنصي')),
                ),
                FilledButton(
                  onPressed: widget.onAccept == null
                      ? null
                      : () => widget.onAccept!(proposal),
                  child: Text(say('Use This', 'استخدام الاقتراح')),
                ),
              ],
            ),
            TextButton(
              onPressed: widget.onEditBeforeAccepting,
              child: Text(say('Edit Before Accepting', 'تعديل قبل القبول')),
            ),
          ] else ...[
            OutlinedButton.icon(
              key: const Key('jobix-generate'),
              onPressed: widget.onGenerate,
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: Text(say('Improve with JobiX', 'حسّن النص مع JobiX')),
            ),
          ],
          if (widget.error != null) ...[
            const SizedBox(height: TokensV0.space8),
            Semantics(
              liveRegion: true,
              child: Text(
                widget.error!,
                style: const TextStyle(color: TokensV0.error),
              ),
            ),
            TextButton(
              onPressed: widget.onGenerate,
              child: Text(say('Retry', 'إعادة المحاولة')),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProposalSkeleton extends StatelessWidget {
  const _ProposalSkeleton();
  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context)!.localeName.startsWith('ar')
        ? 'جار إعداد الاقتراح'
        : 'Preparing proposal',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final width in [double.infinity, double.infinity, 140.0])
          Container(
            height: 14,
            width: width,
            margin: const EdgeInsetsDirectional.only(bottom: TokensV0.space12),
            decoration: BoxDecoration(
              color: TokensV0.surfaceContainer,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    ),
  );
}
