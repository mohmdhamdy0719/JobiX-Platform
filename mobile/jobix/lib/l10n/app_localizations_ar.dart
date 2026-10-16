// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get sectionVolunteer => 'الخبرات التطوعية';

  @override
  String get addVolunteer => 'إضافة دور تطوعي';

  @override
  String get fieldOrganization => 'المنظمة';

  @override
  String get currentVolunteer => 'أتطوع حاليًا';

  @override
  String get volunteerEvidenceHint =>
      'الأدوار التطوعية خبرات غير مدفوعة ومستقلة تظهر في سيرتك الذاتية، ولا تغيّر نسبة اكتمال الملف المهني.';

  @override
  String get exitTitle => 'الخروج من Jobix؟';

  @override
  String get exitMessage => 'هل تريد إغلاق Jobix؟';

  @override
  String get exitAction => 'خروج';

  @override
  String get itemSaved => 'محفوظ';

  @override
  String get pendingBackWarning =>
      'قد يكون طلب الحفظ السابق قد وصل إلى الخادم. الرجوع يلغي التعديلات غير المرسلة فقط، وليس ذلك الطلب. سنحتفظ بالطلب نفسه لإعادة المحاولة، ولن نرسل طلب حفظ جديدًا.';

  @override
  String get appTitle => 'Jobix';

  @override
  String get boot => 'جارٍ تشغيل Jobix';

  @override
  String get signedOut => 'الأساس — دون تسجيل دخول';

  @override
  String get signedIn => 'الأساس — تم تسجيل الدخول';

  @override
  String get placeholder => 'واجهة مؤقتة للأساس. لم يتم تنفيذ شاشات المنتج.';

  @override
  String get updateRequired => 'يلزم تحديث التطبيق.';

  @override
  String get startupFailed =>
      'تعذّر تشغيل Jobix. تحقق من الإعدادات والاتصال ثم أعد المحاولة.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get signOutFailed => 'تعذّر إكمال تسجيل الخروج. يرجى إعادة المحاولة.';

  @override
  String get continueAction => 'متابعة';

  @override
  String get backAction => 'رجوع';

  @override
  String get skipOnboarding => 'تخطي المقدمة';

  @override
  String get skipShort => 'تخطي';

  @override
  String get languageSwitch => 'لغة التطبيق';

  @override
  String get onboardingTitleOne =>
      'أنشئ سيرة ذاتية احترافية ومتوافقة مع أنظمة تتبع المتقدمين';

  @override
  String get onboardingTitleTwo => 'حوّل خبرتك إلى محتوى احترافي';

  @override
  String get onboardingTitleThree => 'أنشئها مرة واحدة. وحدّثها في أي وقت.';

  @override
  String get onboardingBodyOne =>
      'أنشئ سيرة ذاتية تعرض خبراتك ومهاراتك ونقاط قوتك بوضوح — دون عناء البدء من الصفر.';

  @override
  String get onboardingBodyTwo =>
      'صِف خبرتك بكلماتك. يساعدك Jobix على صياغتها في محتوى واضح واحترافي مناسب للسيرة الذاتية — دون اختلاق معلومات.';

  @override
  String get onboardingBodyThree =>
      'اختر قالب سيرتك الذاتية وصدّرها بصيغة PDF واحتفظ بمعلوماتك جاهزة للتحديث مع كل تغيير في مسيرتك المهنية.';

  @override
  String get researchHeading => 'لنتعرّف على مسيرتك المهنية';

  @override
  String get contextOnly =>
      'تساعدنا تفضيلاتك على تخصيص تجربة JobiX مستقبلًا. يمكنك تغييرها في أي وقت من الإعدادات.';

  @override
  String get questionStage => 'أي وصف يناسب مرحلتك المهنية الحالية؟';

  @override
  String get questionGoal => 'ما الذي تسعى لتحقيقه حاليًا في مسيرتك المهنية؟';

  @override
  String get questionLocation => 'أين تبحث حاليًا عن فرص عمل؟';

  @override
  String get questionHelp =>
      'ما أكثر ما تحتاج إلى مساعدة فيه في مسيرتك المهنية؟';

  @override
  String get helpLimit => 'اختر حتى 3 إجابات';

  @override
  String get stageStudent => 'طالب';

  @override
  String get stageGraduate => 'حديث التخرج (خبرة من 0 إلى سنة)';

  @override
  String get stageEarly => 'في بداية المسيرة المهنية (خبرة من سنة إلى 3 سنوات)';

  @override
  String get stageMid => 'في منتصف المسيرة المهنية (خبرة من 4 إلى 7 سنوات)';

  @override
  String get stageExperienced => 'صاحب خبرة (8 سنوات فأكثر)';

  @override
  String get stageReturning => 'العودة للعمل بعد انقطاع';

  @override
  String get stageChanger => 'تغيير المسار المهني';

  @override
  String get goalFirst => 'العثور على أول وظيفة';

  @override
  String get goalBetter => 'العثور على وظيفة جديدة أو أفضل';

  @override
  String get goalChange => 'تغيير مساري المهني';

  @override
  String get goalAdvance => 'التقدم في مساري المهني الحالي';

  @override
  String get goalPrepare => 'الاستعداد لفرص مستقبلية';

  @override
  String get notSure => 'لم أحدد بعد';

  @override
  String get locationCity => 'في مدينتي الحالية';

  @override
  String get locationCountry => 'في مكان آخر داخل بلدي';

  @override
  String get locationRemote => 'عن بُعد';

  @override
  String get locationAbroad => 'في الخارج';

  @override
  String get locationMultiple => 'منفتح على خيارات متعددة';

  @override
  String get helpCv => 'إنشاء سيرة ذاتية أقوى';

  @override
  String get helpOpportunities => 'العثور على فرص مهنية أفضل';

  @override
  String get helpPaths => 'اكتشاف مسارات مهنية مناسبة';

  @override
  String get helpOnline => 'العمل عبر الإنترنت';

  @override
  String get helpSkills => 'تعلّم مهارات جديدة';

  @override
  String get helpInterviews => 'الاستعداد لمقابلات العمل';

  @override
  String get welcome => 'مرحبًا بك في Jobix';

  @override
  String get welcomeSubtitle => 'أنشئ ملفك المهني واستعد لفرصتك القادمة.';

  @override
  String get authSubtitle =>
      'مسيرتك المهنية بكلماتك. أنشئ حسابًا أو سجّل الدخول للمتابعة.';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get existingAccount => 'تسجيل الدخول إلى حساب موجود';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get googleSignIn => 'المتابعة باستخدام Google';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get sendReset => 'إرسال رابط إعادة التعيين';

  @override
  String get resetSent =>
      'إذا كان الحساب موجودًا، فقد أُرسل رابط إعادة تعيين كلمة المرور. افتح الرابط لاختيار كلمة مرور جديدة.';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get updatePassword => 'تحديث كلمة المرور';

  @override
  String get passwordUpdated => 'تم تحديث كلمة المرور.';

  @override
  String get confirmEmail => 'تأكيد بريدك الإلكتروني';

  @override
  String get confirmEmailBody =>
      'افتح رابط التأكيد في بريدك الإلكتروني، ثم سجّل الدخول. لن يتم تسجيل دخولك قبل تأكيد البريد.';

  @override
  String get authError =>
      'تعذّر إكمال المصادقة. تحقق من بياناتك وتأكيد بريدك والاتصال ثم أعد المحاولة.';

  @override
  String get googleUnavailable =>
      'تعذّر فتح تسجيل الدخول باستخدام Google. أعد المحاولة أو استخدم البريد وكلمة المرور.';

  @override
  String get localWriteError =>
      'تعذّر حفظ تغييراتك على هذا الجهاز. أعد المحاولة قبل المغادرة.';

  @override
  String get homeTitle => 'مسيرتك المهنية تبدأ هنا';

  @override
  String get homeSubtitle => 'احتفظ بمعلوماتك جاهزة لفرصتك القادمة.';

  @override
  String get careerTitle => 'الملف المهني الأول';

  @override
  String get nextAction => 'خطوتك المهنية التالية';

  @override
  String get continueCareer => 'متابعة الملف المهني';

  @override
  String get personalInformation => 'المعلومات الشخصية';

  @override
  String get personalIntro =>
      'ابدأ ببيانات التواصل. يمكنك الحفظ أو المغادرة في أي وقت، حتى لو لم تكمل هذا القسم.';

  @override
  String get moreStepsLater =>
      'الخطوات المهنية الأخرى غير متاحة في هذه المرحلة بعد.';

  @override
  String get draftAvailable => 'لديك عمل غير مكتمل محفوظ على هذا الجهاز.';

  @override
  String get contextPending =>
      'إجاباتك محفوظة على هذا الجهاز. أعد المحاولة لحفظها في حسابك.';

  @override
  String get profileUnavailable =>
      'تعذّر تحميل ملفك المهني الأول. أعد المحاولة. لم يتم إنشاء ملف محلي بديل.';

  @override
  String get resumeLanguage => 'لغة السيرة الذاتية';

  @override
  String get resumeLanguageHint =>
      'اختر لغة أسماء الحقول والأمثلة. لن تتغيّر لغة التطبيق أو محتواك الحالي.';

  @override
  String get chooseResumeLanguage =>
      'اختر لغة السيرة الذاتية لبدء إدخال معلوماتك.';

  @override
  String get contactHeading => 'بيانات التواصل الأساسية';

  @override
  String get optionalHeading => 'الروابط المهنية';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get phoneLabel => 'الهاتف';

  @override
  String get countryLabel => 'الدولة (اختياري)';

  @override
  String get cityLabel => 'المدينة (اختياري)';

  @override
  String get linkedInLabel => 'LinkedIn (اختياري)';

  @override
  String get githubLabel => 'GitHub (اختياري)';

  @override
  String get portfolioLabel => 'الموقع الشخصي (اختياري)';

  @override
  String get nameExample => 'اسمك الكامل';

  @override
  String get emailExample => 'name@example.com';

  @override
  String get phoneExample => 'رقم الهاتف';

  @override
  String get countryExample => 'البلد';

  @override
  String get cityExample => 'المدينة';

  @override
  String get useEgypt => 'استخدام مصر';

  @override
  String get exportRequiredHint =>
      'الاسم والبريد والهاتف مطلوبة للتصدير لاحقًا، وليست شرطًا للحفظ أو المغادرة.';

  @override
  String get phoneValidationHint =>
      'التحقق من الصيغة لا يعني التحقق من أن الرقم يعمل.';

  @override
  String get saveAction => 'حفظ';

  @override
  String get leaveAction => 'مغادرة';

  @override
  String get saveLater => 'حفظ والمتابعة لاحقًا';

  @override
  String get discardAction => 'تجاهل التغييرات';

  @override
  String get stayAction => 'متابعة التعديل';

  @override
  String get leaveTitle => 'هل تريد تجاهل التغييرات غير المحفوظة؟';

  @override
  String get discardWarning => 'لم تُحفظ تغييراتك. إذا غادرت الآن، فستفقدها.';

  @override
  String get savedServer => 'تم الحفظ في حسابك.';

  @override
  String get savedDevice =>
      'تم الحفظ على هذا الجهاز. لم يتم الحفظ في حسابك بعد.';

  @override
  String get saveFailed =>
      'لم يكتمل الحفظ على الخادم. مسودتك محفوظة على هذا الجهاز. أعد المحاولة للتحقق من النتيجة.';

  @override
  String get invalidEmail => 'أدخل بريدًا إلكترونيًا صحيحًا.';

  @override
  String get invalidPhone =>
      'أدخل رقم هاتف بصيغة مناسبة باستخدام الأرقام والمسافات والأقواس والشرطات.';

  @override
  String get invalidLink =>
      'استخدم رابط HTTPS كاملًا، مثل https://linkedin.com/in/your-name.';

  @override
  String get conflictTitle => 'تغيّر ملفك المهني في مكان آخر';

  @override
  String get conflictBody =>
      'عملك المحلي محفوظ. احتفظ بنسخة الخادم أو أعد تطبيق عملك المحلي باختيارك.';

  @override
  String get keepServer => 'الاحتفاظ بنسخة الخادم';

  @override
  String get reapplyLocal => 'إعادة تطبيق العمل المحلي';

  @override
  String get outcomeUnknown =>
      'لم تتأكد نتيجة الحفظ السابق بعد. أعد الحفظ قبل التجاهل؛ لا يمكن التراجع هنا عن البيانات المحفوظة على الخادم.';

  @override
  String get showPassword => 'إظهار أو إخفاء كلمة المرور';

  @override
  String get loginAction => 'تسجيل الدخول';

  @override
  String get loginSubtitle => 'مرحبًا بعودتك. سجّل الدخول لمتابعة ملفك المهني.';

  @override
  String get signupSubtitle =>
      'أنشئ حسابًا للاحتفاظ بمعلوماتك المهنية في مكان واحد.';

  @override
  String get providerSettingsUnavailable =>
      'تعذّر التحقق من خيارات الدخول الأخرى. لا يزال الدخول بالبريد الإلكتروني متاحًا.';

  @override
  String get passwordRequired => 'أدخل كلمة المرور.';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get startupStorageFailed =>
      'تعذّر على Jobix فتح التخزين المحلي المحمي. أعد المحاولة للمتابعة؛ لم تُحذف بياناتك.';

  @override
  String get startupSessionFailed =>
      'تعذّر على Jobix استعادة جلسة الدخول الآمنة. تحقّق من الاتصال وأعد المحاولة.';

  @override
  String get startupPolicyFailed =>
      'تعذّر على Jobix التحقق من سياسة التطبيق المطلوبة. تحقّق من الاتصال وأعد المحاولة.';

  @override
  String get haveAccount => 'لديك حساب بالفعل؟ سجّل الدخول';

  @override
  String get needAccount => 'جديد في Jobix؟ أنشئ حسابًا';

  @override
  String get legalLinksUnavailable =>
      'بإنشاء حساب، تقرّ بشروط الخدمة وسياسة الخصوصية. لم يتم إعداد روابطهما بعد.';

  @override
  String get researchLoadError =>
      'تعذّر تحميل سياقك المهني المحفوظ. لم يتم تغيير إجاباتك السابقة.';

  @override
  String researchStep(int number) {
    return 'الخطوة $number من 4';
  }

  @override
  String get locationDataMissing => 'أدخل مدينة أو اختر مدينة سبق أن حفظتها.';

  @override
  String get signOutLocalWarning =>
      'سيؤدي تسجيل الخروج إلى حذف التغييرات غير المحفوظة إلا على هذا الجهاز. ستبقى المعلومات المحفوظة في حسابك كما هي.';

  @override
  String get homeNav => 'الرئيسية';

  @override
  String get careerNav => 'المسيرة المهنية';

  @override
  String get settingsNav => 'الإعدادات';

  @override
  String get balanceUnavailable => 'الرصيد غير متاح مؤقتًا.';

  @override
  String get availableCredits => 'الرصيد المتاح';

  @override
  String get viewHistory => 'السجل';

  @override
  String get careerPageTitle => 'ملفك المهني';

  @override
  String get careerPageSubtitle =>
      'احتفظ بمعلوماتك المهنية دقيقة وجاهزة للاستخدام.';

  @override
  String get activeProfile => 'ملفك الحالي';

  @override
  String get profileTruthNote =>
      'هذا الملف هو معلوماتك المهنية. أدوات السيرة الذاتية والأقسام الأخرى غير متاحة في هذا الإصدار.';

  @override
  String get notEntered => 'لم يُدخَل';

  @override
  String get editPersonalInformation => 'تعديل المعلومات الشخصية';

  @override
  String get careerOtherSectionsUnavailable =>
      'الأقسام المهنية الإضافية غير متاحة في هذا الإصدار.';

  @override
  String get arabicLanguage => 'العربية';

  @override
  String get englishLanguage => 'الإنجليزية';

  @override
  String get accountSection => 'الحساب';

  @override
  String get accountInformation => 'معلومات الحساب';

  @override
  String get accountInfoUnavailable => 'معلومات الحساب غير متاحة مؤقتًا.';

  @override
  String get personalInfoSettingsHint => 'تعديل معلومات التواصل المحفوظة';

  @override
  String get preferencesSection => 'التفضيلات';

  @override
  String get languageSettingsHint => 'تتحكم في لغة واجهة تطبيق Jobix';

  @override
  String get careerDataSection => 'المسيرة المهنية والبيانات';

  @override
  String get creditHistoryTitle => 'سجل الرصيد';

  @override
  String get creditHistorySubtitle =>
      'تغييرات الرصيد المتاح المسجّلة على الخادم.';

  @override
  String get supportSection => 'الدعم';

  @override
  String get contactUs => 'تواصل معنا';

  @override
  String get serviceNotConfigured => 'لم يتم إعداد وسيلة التواصل مع الدعم بعد.';

  @override
  String get legalSection => 'الشؤون القانونية';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get legalUnavailable => 'لم يتم إعداد الرابط بعد.';

  @override
  String get termsOfService => 'شروط الخدمة';

  @override
  String get accountActionsSection => 'إجراءات الحساب';

  @override
  String get settingsFooter =>
      'يحافظ Jobix على دقة معلوماتك المهنية ويترك التحكم بها لك.';

  @override
  String get creditHistoryLoadFailed =>
      'تعذّر تحميل سجل الرصيد. لم يتم افتراض وجود سجل فارغ.';

  @override
  String get creditHistoryEmpty => 'لا توجد معاملات رصيد لهذا الحساب حتى الآن.';

  @override
  String get moreTransactionsFailed => 'تعذّر تحميل المزيد من المعاملات.';

  @override
  String get loadMore => 'تحميل المزيد';

  @override
  String get creditTransaction => 'معاملة رصيد';

  @override
  String stepOf(Object step, Object total) {
    return 'الخطوة $step من $total';
  }

  @override
  String get stepPersonal => 'المعلومات الشخصية والروابط';

  @override
  String get stepSummary => 'الملخص المهني';

  @override
  String get stepExperience => 'الخبرة العملية';

  @override
  String get stepEducation => 'التعليم والشهادات';

  @override
  String get stepSkills => 'المهارات والمشاريع واللغات';

  @override
  String get stepReview => 'مراجعة الملف';

  @override
  String get skipAction => 'تخطي الآن';

  @override
  String itemsAdded(Object count) {
    return 'تمت إضافة $count';
  }

  @override
  String get addRole => 'إضافة دور';

  @override
  String get addEducation => 'إضافة تعليم';

  @override
  String get addCertification => 'إضافة شهادة';

  @override
  String get addAchievement => 'إضافة إنجاز';

  @override
  String get addProject => 'إضافة مشروع';

  @override
  String get addLanguage => 'إضافة لغة';

  @override
  String get sectionEducation => 'التعليم';

  @override
  String get sectionCertifications => 'الشهادات المهنية';

  @override
  String get sectionAchievements => 'الإنجازات';

  @override
  String get sectionSkills => 'المهارات';

  @override
  String get sectionProjects => 'المشاريع';

  @override
  String get sectionLanguages => 'اللغات';

  @override
  String get emptyExperience =>
      'لم تتم إضافة أي دور بعد. أضف دورًا الآن أو تخطَّ هذه الخطوة.';

  @override
  String get emptySection => 'لم تتم إضافة شيء بعد.';

  @override
  String get presentLabel => 'حتى الآن';

  @override
  String get currentRole => 'أعمل هنا حاليًا';

  @override
  String get currentStudy => 'أدرس هنا حاليًا';

  @override
  String get itemIncomplete => 'يحتاج إلى تفاصيل';

  @override
  String get itemComplete => 'مكتمل';

  @override
  String get editAction => 'تعديل';

  @override
  String get removeAction => 'إزالة';

  @override
  String get moreActions => 'إجراءات أخرى';

  @override
  String get removeTitle => 'إزالة هذا العنصر؟';

  @override
  String get removeBody => 'ستتم إزالته من ملفك.';

  @override
  String get cancelAction => 'إلغاء';

  @override
  String get fieldJobTitle => 'المسمى الوظيفي';

  @override
  String get fieldCompany => 'الشركة';

  @override
  String get fieldLocation => 'الموقع (اختياري)';

  @override
  String get fieldStartMonth => 'تاريخ البدء';

  @override
  String get fieldEndMonth => 'تاريخ الانتهاء';

  @override
  String get fieldDescription => 'الوصف';

  @override
  String get fieldDescriptionOptional => 'الوصف (اختياري)';

  @override
  String get fieldDegree => 'الدرجة العلمية';

  @override
  String get fieldInstitution => 'المؤسسة التعليمية';

  @override
  String get fieldStudy => 'التخصص';

  @override
  String get fieldName => 'الاسم';

  @override
  String get fieldIssuer => 'الجهة المانحة';

  @override
  String get fieldIssueMonth => 'تاريخ الإصدار';

  @override
  String get fieldExpiryMonth => 'تاريخ الانتهاء (اختياري)';

  @override
  String get fieldCredential => 'رقم الاعتماد (اختياري)';

  @override
  String get fieldUrl => 'الرابط (اختياري)';

  @override
  String get fieldTitle => 'العنوان';

  @override
  String get fieldMonth => 'التاريخ';

  @override
  String get fieldDegreeTitle => 'عنوان المؤهل';

  @override
  String get fieldDegreeTitleHint => 'أدخل مؤهلك';

  @override
  String creditsCompactCount(int count) {
    return '$count CR';
  }

  @override
  String get fieldRole => 'دورك';

  @override
  String get fieldTechnologies => 'التقنيات (مفصولة بفواصل)';

  @override
  String get fieldLanguage => 'اللغة';

  @override
  String get fieldProficiency => 'مستوى الإتقان';

  @override
  String get monthHint => 'YYYY-MM';

  @override
  String get problemTooLong => 'النص طويل جدًا.';

  @override
  String get problemMonth => 'استخدم الصيغة YYYY-MM.';

  @override
  String get problemUrl => 'أدخل رابطًا آمنًا يبدأ بـ https.';

  @override
  String get problemEndBeforeStart => 'يجب أن يكون الانتهاء بعد البدء.';

  @override
  String get problemRequired => 'هذا الحقل مطلوب.';

  @override
  String get descriptionMinimum =>
      'اكتب 20 حرفًا على الأقل ليُحتسب ضمن اكتمال الملف.';

  @override
  String get incompleteSaveNote =>
      'يمكنك الحفظ الآن وإكمال التفاصيل لاحقًا؛ العناصر غير المكتملة لا تُحتسب ضمن اكتمال الملف.';

  @override
  String get profBasic => 'أساسي';

  @override
  String get profConversational => 'محادثة';

  @override
  String get profProfessional => 'مهني';

  @override
  String get profFluent => 'طلاقة';

  @override
  String get profNative => 'اللغة الأم';

  @override
  String get skillHint => 'اكتب مهارة';

  @override
  String get addAction => 'إضافة';

  @override
  String get duplicateItem => 'هذا موجود بالفعل في قائمتك.';

  @override
  String get suggestedSkills => 'اقتراحات';

  @override
  String get saveConflict =>
      'تم تغيير هذا الملف على جهاز آخر. أعد التحميل لرؤية أحدث نسخة؛ تبقى تعديلاتك على هذا الجهاز.';

  @override
  String get reloadAction => 'إعادة التحميل';

  @override
  String get savePending => 'لم يتم تأكيد حفظ سابق بعد.';

  @override
  String get retrySave => 'إعادة محاولة الحفظ';

  @override
  String get itemNotFound => 'هذا العنصر لم يعد موجودًا.';

  @override
  String get reviewIntro => 'راجع كل قسم. اضغط تعديل لتغيير أي شيء.';

  @override
  String get doneAction => 'تم';

  @override
  String get completenessLabel => 'اكتمال الملف';

  @override
  String get aiAuditSoon => 'مراجعة ATS والذكاء الاصطناعي غير متاحة بعد.';

  @override
  String get aiSoon => 'ميزة التحسين مع JobiX غير متاحة بعد.';

  @override
  String get targetRoleOptional => 'الدور المستهدف (اختياري)';

  @override
  String get notProvided => 'غير مضاف';

  @override
  String profileSlot(Object slot) {
    return 'الملف $slot';
  }

  @override
  String get continueProfile => 'متابعة الملف';

  @override
  String sectionStatusCount(Object complete, Object total) {
    return '$complete من $total مكتمل';
  }

  @override
  String get contactSection => 'بيانات التواصل';

  @override
  String get authRateLimited =>
      'تم طلب عدد كبير من الرسائل. انتظر قليلًا ثم حاول مرة أخرى.';

  @override
  String get authNotConfirmed =>
      'أكّد بريدك الإلكتروني أولًا. تحقق من صندوق الوارد أو أعد إرسال الرابط.';

  @override
  String get authInvalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get authWeakPassword => 'اختر كلمة مرور أقوى (8 أحرف على الأقل).';

  @override
  String get authInvalidEmail => 'أدخل بريدًا إلكترونيًا صالحًا.';

  @override
  String get authUserExists =>
      'يوجد حساب بهذا البريد بالفعل. سجّل الدخول بدلًا من ذلك.';

  @override
  String get authNetwork => 'لا يوجد اتصال. تحقق من الإنترنت وحاول مرة أخرى.';

  @override
  String get resendConfirmation => 'إعادة إرسال رسالة التأكيد';

  @override
  String get confirmationResent => 'تم إرسال رسالة تأكيد جديدة.';

  @override
  String get notSavedYet => 'لم يُحفظ بعد';

  @override
  String get reviewPersonalMissing =>
      'أضف اسمك وبريدك الإلكتروني ورقم هاتفك لتتمكن من تصدير السيرة الذاتية لاحقًا.';

  @override
  String welcomeBack(Object name) {
    return 'مرحبًا بعودتك، $name';
  }

  @override
  String get homeOverview => 'هذه نظرة عامة على مسارك المهني.';

  @override
  String creditsCount(Object count) {
    return 'الرصيد: $count';
  }

  @override
  String moreCount(Object count) {
    return '+$count أخرى';
  }

  @override
  String sectionsRemaining(Object count) {
    return 'أقسام متبقية: $count';
  }

  @override
  String get itemChangedElsewhere =>
      'تم تغيير هذا العنصر على جهاز آخر بعد أن بدأت التعديل. اختر النسخة التي تريد الاحتفاظ بها.';

  @override
  String get itemRemovedElsewhere =>
      'تمت إزالة هذا العنصر على جهاز آخر بعد أن بدأت التعديل. اختر إبقاءه محذوفًا أو إضافته مجددًا بتعديلاتك.';

  @override
  String get keepServerVersion => 'استخدام أحدث نسخة';

  @override
  String get reapplyMyChanges => 'الاحتفاظ بتعديلاتي';

  @override
  String get exportRateLimited =>
      'وصلت إلى الحد المسموح للتصدير. يرجى الانتظار قبل إعادة محاولة الطلب المحفوظ.';

  @override
  String exportRateLimitedRetry(int seconds) {
    return 'وصلت إلى الحد المسموح للتصدير. انتظر $seconds ثانية ثم أعد محاولة الطلب المحفوظ.';
  }

  @override
  String get exportTemporarilyUnavailable =>
      'الخدمة غير متاحة مؤقتًا. يُرجى المحاولة مرة أخرى لاحقًا.';

  @override
  String get exportInProgress =>
      'يوجد تصدير قيد التنفيذ لهذا الملف الشخصي. تحقق من حالته قبل بدء تصدير آخر.';

  @override
  String get backToReview => 'العودة إلى المراجعة';
}
