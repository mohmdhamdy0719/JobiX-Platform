import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../career_profile/career_profile.dart';
import '../auth/auth_controller.dart';
import '../resume/resume_document.dart';

class ResumeJourney {
  const ResumeJourney({this.step = 1, this.complete = false});
  final int step;
  final bool complete;
  factory ResumeJourney.decode(String? raw) {
    if (raw == null) return const ResumeJourney();
    final value = jsonDecode(raw) as Map;
    return ResumeJourney(
      step: ((value['step'] as num?)?.toInt() ?? 1).clamp(1, 6),
      complete: value['complete'] == true,
    );
  }
  String encode() => jsonEncode({'step': step, 'complete': complete});
}

String journeyKey(String actor, String profile) =>
    'resume:$actor:journey:$profile';

final resumeJourneyProvider = FutureProvider.family<ResumeJourney, String>((
  ref,
  profile,
) async {
  final repository = await ref.watch(draftRepositoryProvider.future);
  return ResumeJourney.decode(
    await repository.database.setting(journeyKey(repository.user, profile)),
  );
});

/// Uses the existing structural content policy, not completeness or prose length.
bool minimumResumeContent(CareerProfile profile) {
  final issues = ResumeDocument.issues(
    profile,
    ResumePresentation(language: profile.resumeLanguage ?? 'en'),
  );
  return !issues.any(
    (issue) => issue.startsWith('personal.') || issue == 'career_content',
  );
}

Future<void> completeResumeJourney(WidgetRef ref, String profile) async {
  final repository = await ref.read(draftRepositoryProvider.future);
  await repository.database.setSetting(
    journeyKey(repository.user, profile),
    const ResumeJourney(step: 6, complete: true).encode(),
  );
  ref.invalidate(resumeJourneyProvider(profile));
}

/// Record only the visited guided step; never turn Review into completion.
/// Records are actor/profile-scoped and use the existing durable local store.
class ResumeJourneyRecorder extends ConsumerStatefulWidget {
  const ResumeJourneyRecorder({
    required this.step,
    required this.enabled,
    required this.child,
    super.key,
  });
  final int step;
  final bool enabled;
  final Widget child;
  @override
  ConsumerState<ResumeJourneyRecorder> createState() =>
      _ResumeJourneyRecorderState();
}

class _ResumeJourneyRecorderState extends ConsumerState<ResumeJourneyRecorder> {
  @override
  void initState() {
    super.initState();
    record();
  }

  @override
  void didUpdateWidget(ResumeJourneyRecorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step || oldWidget.enabled != widget.enabled) {
      record();
    }
  }

  Future<void> record() async {
    if (!widget.enabled) return;
    final step = widget.step;
    try {
      final profile = await ref.read(firstProfileProvider.future);
      final repository = await ref.read(draftRepositoryProvider.future);
      final key = journeyKey(repository.user, profile.id);
      final old = ResumeJourney.decode(await repository.database.setting(key));
      if (!mounted || old.complete || old.step == step) return;
      await repository.database.setSetting(
        key,
        ResumeJourney(step: step).encode(),
      );
      if (mounted) ref.invalidate(resumeJourneyProvider(profile.id));
    } catch (_) {
      if (mounted) {
        final ar = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              ar
                  ? 'تعذر حفظ تقدم الخطوات. بيانات الملف لم تتغير.'
                  : 'Could not save step progress. Profile data is unchanged.',
            ),
            action: SnackBarAction(
              label: ar ? 'إعادة المحاولة' : 'Retry',
              onPressed: record,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
