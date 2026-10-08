import 'dart:async';
import '../../core/navigation/back_policy.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/design/form_loading_state.dart';
import '../../core/design/slice_widgets.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../career_profile/career_profile.dart';
import '../career_profile/profile_sections.dart';
import 'profile_extras_repository.dart';

class ProfileExtrasPage extends ConsumerStatefulWidget {
  const ProfileExtrasPage({this.origin = 'career', super.key});
  final String origin;
  @override
  ConsumerState<ProfileExtrasPage> createState() => _ProfileExtrasPageState();
}

class _ProfileExtrasPageState extends ConsumerState<ProfileExtrasPage> {
  ProfileExtrasRepository? repository;
  ExtrasDraft? draft;
  CareerProfile? profile;
  final controllers = <String, TextEditingController>{};
  Future<void> writes = Future.value();
  bool busy = false, failed = false, validate = false, localFailed = false;
  String? notice;
  bool get ar => AppLocalizations.of(context)!.localeName.startsWith('ar');
  String say(String en, String arabic) => ar ? arabic : en;
  String get destination => widget.origin == 'builder'
      ? '/builder/1'
      : widget.origin == 'review'
      ? '/career/personal?origin=review'
      : '/career/personal';

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final repo = await ref.read(profileExtrasRepositoryProvider.future);
      final current = await repo.parent.load();
      final input = await repo.open(current);
      if (!mounted) return;
      setState(() {
        repository = repo;
        profile = current;
        draft = input;
        failed = false;
      });
      // Android can destroy the activity while the native picker is open.
      if (Platform.isAndroid) {
        try {
          final lost = await ImagePicker().retrieveLostData();
          if (!mounted) return;
          if (lost.files?.isNotEmpty == true) {
            await acceptPicked(lost.files!.first);
          }
          if (lost.exception != null) {
            setState(
              () => notice = say(
                'The photo could not be recovered. Please select it again.',
                'تعذر استعادة الصورة. يرجى اختيارها مجددًا.',
              ),
            );
          }
        } catch (_) {
          if (mounted) {
            setState(
              () => notice = say(
                'The photo could not be recovered. Please select it again.',
                'تعذر استعادة الصورة. يرجى اختيارها مجددًا.',
              ),
            );
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  void edit(ProfileExtras value) {
    final next = draft!.edit(value);
    setState(() {
      draft = next;
      notice = null;
    });
    writes = writes
        .then((_) => repository!.retain(next))
        .then((_) {
          if (mounted) setState(() => localFailed = false);
        })
        .catchError((Object _) {
          if (mounted) setState(() => localFailed = true);
        });
  }

  Future<bool> flush() async {
    try {
      await writes;
      await repository!.retain(draft!);
      if (mounted) setState(() => localFailed = false);
      return true;
    } catch (_) {
      if (mounted) setState(() => localFailed = true);
      return false;
    }
  }

  Future<void> leave() async {
    if (busy) return;
    if (draft != null && !await flush()) return;
    if (mounted) context.go(destination);
  }

  Future<void> pickPhoto() async {
    setState(() => busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );
      if (picked != null && mounted) await acceptPicked(picked);
    } on PlatformException catch (_) {
      if (mounted) {
        setState(
          () => notice = say(
            'Photo access was unavailable. Allow photo access in device settings and try again.',
            'الوصول إلى الصور غير متاح. اسمح بالوصول في إعدادات الجهاز ثم حاول مجددًا.',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => notice = say(
            'This photo could not be opened. Try another JPEG or PNG.',
            'تعذر فتح هذه الصورة. جرّب صورة JPEG أو PNG أخرى.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> acceptPicked(XFile file) async {
    final bytes = await file.readAsBytes();
    final mime = ProfileExtras.imageMime(bytes);
    if (mime == null) {
      if (mounted) {
        setState(
          () => notice = say(
            'Choose a JPEG or PNG up to 1 MiB. SVG and other formats are not supported.',
            'اختر صورة JPEG أو PNG بحجم لا يتجاوز 1 ميبيبايت. لا ندعم SVG أو الصيغ الأخرى.',
          ),
        );
      }
      return;
    }
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      final validSize = frame.image.width <= 1024 && frame.image.height <= 1024;
      frame.image.dispose();
      if (!validSize) {
        if (mounted) {
          setState(
            () => notice = say(
              'The selected image is still too large. Choose an image no larger than 1024 × 1024.',
              'ما زالت أبعاد الصورة كبيرة. اختر صورة لا تتجاوز 1024 × 1024.',
            ),
          );
        }
        return;
      }
    } finally {
      codec.dispose();
    }
    if (mounted) edit(draft!.value.withPhoto(bytes, mime));
  }

  Future<void> removeLink(CustomProfileLink link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(say('Remove this link?', 'حذف هذا الرابط؟')),
        content: Text(
          link.label.isEmpty
              ? say('Untitled link', 'رابط بلا عنوان')
              : link.label,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(say('Cancel', 'إلغاء')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(say('Remove', 'حذف')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      edit(
        draft!.value.withLinks([
          for (final current in draft!.value.links)
            if (current.id != link.id) current,
        ]),
      );
    }
  }

  String sanitized(Object error) {
    final reason = error is PostgrestException
        ? error.message
        : error is StateError
        ? error.message.toString()
        : '';
    if (reason.contains('VERSION_CONFLICT') ||
        reason.contains('BASELINE_CONFLICT')) {
      return say(
        'The profile changed. Your photo and links are retained. Reconcile Personal Information first, then review the latest saved version before retrying.',
        'تغير الملف. احتفظنا بصورتك وروابطك. عالج تعارض المعلومات الشخصية أولًا، ثم راجع أحدث نسخة محفوظة قبل إعادة المحاولة.',
      );
    }
    if (reason.contains('PERSONAL_SAVE_PENDING') ||
        reason.contains('OTHER_SAVE_PENDING')) {
      return say(
        'Another profile save is awaiting confirmation. Resolve it before saving photo and links. Your input is retained.',
        'هناك عملية حفظ أخرى تنتظر التأكيد. عالجها قبل حفظ الصورة والروابط. احتفظنا بمدخلاتك.',
      );
    }
    if (reason.contains('VALIDATION_FAILED') ||
        reason.contains('EXTRAS_INVALID')) {
      return say(
        'Check the link labels, HTTPS addresses and photo format. Nothing was discarded.',
        'راجع عناوين الروابط وروابط HTTPS وصيغة الصورة. لم نحذف أي مدخلات.',
      );
    }
    if (reason.contains('FORBIDDEN') ||
        reason.contains('AUTH_REQUIRED') ||
        reason.contains('ACCOUNT_DELETING')) {
      return say(
        'Saving is not available for this session. Sign in again before retrying.',
        'الحفظ غير متاح في هذه الجلسة. سجّل الدخول مجددًا قبل المحاولة.',
      );
    }
    return say(
      'The save outcome is not confirmed. Your exact request is retained. Retry to confirm it before making another save.',
      'نتيجة الحفظ غير مؤكدة. احتفظنا بالطلب نفسه. أعد المحاولة لتأكيده قبل إجراء حفظ آخر.',
    );
  }

  Future<void> save() async {
    if (busy || draft == null) return;
    setState(() {
      busy = true;
      validate = true;
      notice = null;
    });
    try {
      if (!await flush()) return;
      final result = await repository!.save(draft!);
      if (!mounted) return;
      setState(() {
        profile = result.profile;
        draft = result.draft;
      });
      ref.invalidate(firstProfileProvider);
      if (result.hasUnsentEdits) {
        setState(
          () => notice = say(
            'The original request was confirmed. Your newer photo or link edits are still retained locally. Save again to submit them.',
            'تأكد حفظ الطلب الأصلي. احتفظنا بتعديلات الصورة أو الروابط الأحدث على جهازك. احفظ مجددًا لإرسالها.',
          ),
        );
        return;
      }
      if (!result.personalSafe) {
        setState(
          () => notice = say(
            'Photo and links were saved, but Personal Information changed during the save. Those edits are retained and were not rebased. Return to Personal Information to reconcile them.',
            'حُفظت الصورة والروابط، لكن المعلومات الشخصية تغيرت أثناء الحفظ. احتفظنا بالتعديلات ولم نغيّر أساس نسختها. عد إلى المعلومات الشخصية لمعالجة التعارض.',
          ),
        );
        return;
      }
      if (mounted) context.go(destination);
    } catch (error) {
      if (!mounted) return;
      ExtrasDraft? retained;
      try {
        retained = await repository!.local(draft!.profileId);
      } catch (_) {
        // Account/session transition: retain no stale owner-bound references.
      }
      if (mounted) {
        setState(() {
          draft = retained ?? draft;
          notice = sanitized(error);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reviewLatest() async {
    if (busy || draft == null || draft!.pending != null) return;
    setState(() => busy = true);
    try {
      if (!await flush()) return;
      final latest = await repository!.parent.load(freshOnly: true);
      final extras = await repository!.api.read(latest.id);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            say('Review latest saved version', 'مراجعة أحدث نسخة محفوظة'),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  say(
                    'Your draft will replace the saved photo and custom links only. Personal Information must already be reconciled.',
                    'ستستبدل مسودتك الصورة والروابط المخصصة المحفوظة فقط. يجب معالجة تعارض المعلومات الشخصية مسبقًا.',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  say('Currently saved', 'المحفوظ حاليًا'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (extras.photoBytes != null)
                  Image.memory(
                    extras.photoBytes!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                if (extras.links.isEmpty)
                  Text(say('No custom links', 'لا توجد روابط مخصصة')),
                for (final link in extras.links)
                  Text('${link.label}\n${link.url}'),
                const SizedBox(height: 16),
                Text(
                  say('Your draft', 'مسودتك'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (draft!.value.photoBytes != null)
                  Image.memory(
                    draft!.value.photoBytes!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                for (final link in draft!.value.links)
                  Text('${link.label}\n${link.url}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(say('Keep draft', 'الاحتفاظ بالمسودة')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                say(
                  'Use my edits on this version',
                  'تطبيق تعديلاتي على هذه النسخة',
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        final next = await repository!.reapply(draft!, latest);
        if (mounted) {
          setState(() {
            draft = next;
            profile = latest;
            notice = null;
          });
        }
      }
    } catch (error) {
      if (mounted) setState(() => notice = sanitized(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = draft?.pending != null;
    return JobixBackHandler(
      onBack: leave,
      child: SliceScaffold(
        title: say('Photo & custom links', 'الصورة والروابط المخصصة'),
        leading: IconButton(
          onPressed: busy ? null : () => requestJobixBack(context),
          tooltip: say(
            'Back to Personal Information',
            'العودة إلى المعلومات الشخصية',
          ),
          icon: const BackButtonIcon(),
        ),
        bottom: draft == null
            ? null
            : PrimaryAction(
                key: const Key('extras-save'),
                label: pending
                    ? say('Retry exact save', 'إعادة طلب الحفظ نفسه')
                    : say('Save & return', 'حفظ والعودة'),
                busy: busy,
                onPressed: save,
              ),
        child: draft == null
            ? failed
                  ? Column(
                      children: [
                        Text(
                          say(
                            'Could not load photo and links.',
                            'تعذر تحميل الصورة والروابط.',
                          ),
                        ),
                        TextButton(
                          onPressed: load,
                          child: Text(say('Retry', 'إعادة المحاولة')),
                        ),
                      ],
                    )
                  : const FormLoadingState()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    say(
                      'Optional details. Your photo is private to your account; no public image URL is created.',
                      'تفاصيل اختيارية. صورتك خاصة بحسابك؛ لا ننشئ رابطًا عامًا للصورة.',
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (notice != null || localFailed) ...[
                    SliceCard(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          localFailed
                              ? say(
                                  'Could not retain this draft on your device. Keep this screen open and retry.',
                                  'تعذر حفظ المسودة على جهازك. أبقِ هذه الشاشة مفتوحة وأعد المحاولة.',
                                )
                              : notice!,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (pending) ...[
                    Text(
                      say(
                        'A save is awaiting confirmation. The original request will be replayed without changing its identity.',
                        'هناك حفظ ينتظر التأكيد. سنعيد الطلب الأصلي دون تغيير هويته.',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SliceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeading(
                          title: say('Profile photo', 'صورة الملف'),
                          subtitle: say(
                            'JPEG or PNG · up to 1 MiB · max 1024 × 1024',
                            'JPEG أو PNG · حتى 1 ميبيبايت · أقصى أبعاد 1024 × 1024',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: draft!.value.photoBytes == null
                                ? Container(
                                    width: 100,
                                    height: 100,
                                    color: TokensV0.surfaceContainerLow,
                                    child: const Icon(
                                      Icons.person_outline,
                                      color: TokensV0.deepBlue,
                                      size: 40,
                                    ),
                                  )
                                : Image.memory(
                                    draft!.value.photoBytes!,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image_outlined,
                                      size: 48,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: busy || pending ? null : pickPhoto,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(
                            draft!.value.photoBase64 == null
                                ? say('Add photo', 'إضافة صورة')
                                : say('Replace photo', 'استبدال الصورة'),
                          ),
                        ),
                        if (draft!.value.photoBase64 != null)
                          TextButton(
                            onPressed: busy || pending
                                ? null
                                : () =>
                                      edit(draft!.value.withPhoto(null, null)),
                            child: Text(say('Remove photo', 'حذف الصورة')),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SliceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeading(
                          title: say('Custom links', 'روابط مخصصة'),
                          subtitle: say(
                            'Give each HTTPS link a clear label. Standard links stay in Personal Information.',
                            'أضف عنوانًا واضحًا لكل رابط HTTPS. تبقى الروابط القياسية في المعلومات الشخصية.',
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (draft!.value.links.isEmpty)
                          Text(
                            say(
                              'Add a publication, personal website or another relevant link.',
                              'أضف منشورًا أو موقعك الشخصي أو رابطًا آخر ذا صلة.',
                            ),
                          ),
                        for (final link in draft!.value.links)
                          _link(link, pending),
                        OutlinedButton.icon(
                          key: const Key('extras-add-link'),
                          onPressed: busy || pending
                              ? null
                              : () => edit(
                                  draft!.value.withLinks([
                                    ...draft!.value.links,
                                    CustomProfileLink(id: newCommandKey()),
                                  ]),
                                ),
                          icon: const Icon(Icons.add_link),
                          label: Text(
                            say('Add custom link', 'إضافة رابط مخصص'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!pending)
                    TextButton(
                      onPressed: busy ? null : reviewLatest,
                      child: Text(
                        say(
                          'Review latest saved version',
                          'مراجعة أحدث نسخة محفوظة',
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: busy ? null : leave,
                    child: Text(
                      say(
                        'Back · retain local draft',
                        'العودة · الاحتفاظ بالمسودة على الجهاز',
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _link(CustomProfileLink link, bool pending) {
    TextEditingController controller(String field, String initial) =>
        controllers.putIfAbsent(
          '${link.id}:$field',
          () => TextEditingController(text: initial),
        );
    void change({String? label, String? url}) => edit(
      draft!.value.withLinks([
        for (final current in draft!.value.links)
          current.id == link.id
              ? current.edit(label: label, url: url)
              : current,
      ]),
    );
    return Padding(
      key: Key('extras-link-${link.id}'),
      padding: const EdgeInsetsDirectional.only(bottom: TokensV0.space20),
      child: Column(
        children: [
          TextField(
            controller: controller('label', link.label),
            enabled: !busy && !pending,
            maxLength: 200,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            decoration: InputDecoration(
              labelText: say('Link label', 'عنوان الرابط'),
              errorText:
                  validate &&
                      (link.label.trim().isEmpty ||
                          link.label.trim().runes.length > 200)
                  ? say(
                      'Enter a label up to 200 characters.',
                      'أدخل عنوانًا لا يتجاوز 200 حرف.',
                    )
                  : null,
            ),
            onChanged: (value) => change(label: value),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller('url', link.url),
            enabled: !busy && !pending,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
            maxLength: 2048,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            decoration: InputDecoration(
              labelText: say('HTTPS address', 'رابط HTTPS'),
              hintText: 'https://',
              errorText:
                  validate &&
                      (link.url.trim().isEmpty ||
                          normalizeUrl(link.url) == null)
                  ? say(
                      'Enter a valid HTTPS address.',
                      'أدخل رابط HTTPS صالحًا.',
                    )
                  : null,
            ),
            onChanged: (value) => change(url: value),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: busy || pending ? null : () => removeLink(link),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(say('Remove link', 'حذف الرابط')),
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
