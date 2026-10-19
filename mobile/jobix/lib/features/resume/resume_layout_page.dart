import 'package:flutter/material.dart';
import '../../core/design/jobix_dialog.dart';
import '../../core/design/tokens.dart';
import 'resume_layout.dart';
import 'resume_layout_repository.dart';

class ResumeLayoutPage extends StatefulWidget {
  const ResumeLayoutPage({
    required this.initial,
    required this.onSave,
    required this.onReload,
    required this.hasPending,
    this.onRetryPending,
    this.pending = false,
    super.key,
  });
  final ResumeLayout initial;
  final bool pending;
  final Future<void> Function(ResumeLayout) onSave;
  final Future<ResumeLayout> Function() onReload;
  final Future<bool> Function() hasPending;
  final Future<ResumeLayout> Function()? onRetryPending;
  @override
  State<ResumeLayoutPage> createState() => _ResumeLayoutPageState();
}

class _ResumeLayoutPageState extends State<ResumeLayoutPage> {
  late ResumeLayout saved = widget.initial, layout = widget.initial;
  late bool pending = widget.pending;
  bool saving = false, allowPop = false, conflict = false, leaving = false;
  String? error;
  bool get dirty => layout.fingerprint != saved.fingerprint;
  bool get ar => Localizations.localeOf(context).languageCode == 'ar';
  String t(String en, String arabic) => ar ? arabic : en;

  String label(String key) => switch (key) {
    'summary' => t('Professional Summary', 'الملخص المهني'),
    'target_role' => t('Target Role', 'الوظيفة المستهدفة'),
    'experience' => t('Work Experience', 'الخبرة المهنية'),
    'volunteer' => t('Volunteer Experience', 'الخبرات التطوعية'),
    'education' => t('Education', 'التعليم'),
    'certification' => t('Certifications', 'الشهادات'),
    'achievement' => t('Achievements', 'الإنجازات'),
    'project' => t('Projects', 'المشروعات'),
    'skill' => t('Skills', 'المهارات'),
    'language' => t('Languages', 'اللغات'),
    _ => throw StateError('INVALID_RESUME_SECTION'),
  };

  Future<void> leave() async {
    if (saving || leaving) return;
    leaving = true;
    var discard = true;
    if (dirty || pending) {
      discard =
          await showDialog<bool>(
            context: context,
            builder: (dialog) => JobixAlertDialog(
              title: Text(t('Leave layout editor?', 'مغادرة محرر التصميم؟')),
              content: Text(
                pending
                    ? t(
                        'A save is not yet confirmed. It will be kept for retry; Preview stays blocked until it is resolved.',
                        'لم يتم تأكيد الحفظ بعد. سيبقى الطلب لإعادة المحاولة، وستظل المعاينة متوقفة حتى تتم تسويته.',
                      )
                    : t(
                        'Discard unsaved layout changes?',
                        'تجاهل تغييرات التصميم غير المحفوظة؟',
                      ),
              ),
              actions: [
                JobixDialogAction.secondary(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: Text(t('Stay', 'البقاء')),
                ),
                JobixDialogAction.primary(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: Text(
                    pending ? t('Leave', 'مغادرة') : t('Discard', 'تجاهل'),
                  ),
                ),
              ],
            ),
          ) ==
          true;
    }
    leaving = false;
    if (discard && mounted) {
      setState(() => allowPop = true);
      Navigator.pop(context);
    }
  }

  Future<void> done() async {
    if (saving) return;
    if (!dirty && !pending) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      if (pending && widget.onRetryPending != null) {
        final confirmed = await widget.onRetryPending!();
        if (mounted) {
          setState(() {
            saved = layout = confirmed;
            allowPop = true;
            pending = false;
          });
          Navigator.pop(context, true);
        }
        return;
      }
      await widget.onSave(layout);
      if (mounted) {
        setState(() {
          allowPop = true;
          pending = false;
        });
        Navigator.pop(context, true);
      }
    } catch (failure) {
      bool stillPending;
      try {
        stillPending = await widget.hasPending();
      } catch (_) {
        if (mounted) {
          setState(
            () => error = t(
              'The account session changed. Return to Resume Export.',
              'تغيّرت جلسة الحساب. ارجع إلى تصدير السيرة الذاتية.',
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        pending = stillPending;
        conflict =
            failure is ResumeLayoutSaveFailure &&
            failure.code == 'VERSION_CONFLICT';
        error =
            failure is ResumeLayoutSaveFailure &&
                failure.code == 'BACKEND_UPDATE_REQUIRED'
            ? stillPending
                  ? t(
                      'The Development backend cannot resolve an earlier layout save yet. Its exact request remains pending; retry after the backend update.',
                      'لا يستطيع خادم التطوير تسوية حفظ سابق للتصميم بعد. ما زال الطلب نفسه معلقًا؛ أعد المحاولة بعد تحديث الخادم.',
                    )
                  : t(
                      'The Development backend needs Migration 022 for layout saves. This attempt was not applied; discard it or leave and retry after the backend is updated.',
                      'يحتاج خادم التطوير إلى الترحيل 022 لحفظ التصميم. لم يُطبّق هذا الطلب؛ تجاهله أو غادر وأعد المحاولة بعد تحديث الخادم.',
                    )
            : conflict
            ? t(
                'The saved Resume changed elsewhere. Reload it before applying your layout.',
                'تغيّرت السيرة المحفوظة من مكان آخر. أعد تحميلها قبل تطبيق التصميم.',
              )
            : t(
                'Save was not confirmed. Retry Done to resolve the same request.',
                'لم يتم تأكيد الحفظ. أعد المحاولة بزر تم لتسوية الطلب نفسه.',
              );
      });
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> reload() async {
    setState(() => saving = true);
    try {
      final current = await widget.onReload();
      if (mounted) {
        setState(() {
          saved = layout = current;
          conflict = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = t(
            'Could not reload. Try again.',
            'تعذّر التحميل. أعد المحاولة.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowPop || (!dirty && !pending && !saving),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) leave();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: saving ? null : leave,
          icon: const BackButtonIcon(),
        ),
        title: Text(t('Edit resume layout', 'تعديل تصميم السيرة')),
      ),
      body: Column(
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  style: const TextStyle(color: TokensV0.error),
                ),
              ),
            ),
          if (pending)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                t(
                  'The layout shown is the latest confirmed server version. A previous save is unresolved; Retry uses its original request.',
                  'التصميم المعروض هو أحدث نسخة مؤكدة من الخادم. يوجد حفظ سابق لم تتم تسويته؛ إعادة المحاولة تستخدم الطلب الأصلي.',
                ),
              ),
            ),
          if (conflict)
            TextButton(
              onPressed: saving ? null : reload,
              child: Text(
                t('Reload saved layout', 'إعادة تحميل التصميم المحفوظ'),
              ),
            ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              buildDefaultDragHandles: false,
              itemCount: layout.order.length,
              onReorder: (old, next) {
                if (!saving && !pending && !conflict) {
                  setState(() => layout = layout.reorder(old, next));
                }
              },
              itemBuilder: (context, index) {
                final section = layout.order[index];
                final enabled = !layout.hidden.contains(section);
                final interactive = !saving && !pending && !conflict;
                return Padding(
                  key: ValueKey('layout-$section'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: enabled
                        ? Theme.of(context).colorScheme.surface
                        : const Color(0xffedf0f5),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 8, 8),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            enabled: interactive,
                            child: Semantics(
                              label: t(
                                'Reorder ${label(section)}',
                                'إعادة ترتيب ${label(section)}',
                              ),
                              hint: t(
                                'Drag to move section',
                                'اسحب لنقل القسم',
                              ),
                              child: const SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(
                                  Icons.drag_indicator,
                                  color: TokensV0.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              label(section),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          Semantics(
                            label: label(section),
                            child: Switch.adaptive(
                              key: ValueKey('visible-$section'),
                              value: enabled,
                              onChanged: interactive
                                  ? (value) => setState(
                                      () => layout = layout.toggle(
                                        section,
                                        value,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: saving || pending || conflict
                      ? null
                      : () => setState(() => layout = ResumeLayout()),
                  child: Text(t('Reset', 'إعادة ضبط')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: saving || conflict ? null : done,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          pending
                              ? t('Retry save', 'إعادة الحفظ')
                              : t('Done', 'تم'),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
