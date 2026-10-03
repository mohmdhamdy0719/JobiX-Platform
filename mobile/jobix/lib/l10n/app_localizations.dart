import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Jobix'**
  String get appTitle;

  /// No description provided for @boot.
  ///
  /// In en, this message translates to:
  /// **'Starting Jobix'**
  String get boot;

  /// No description provided for @signedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed-out foundation'**
  String get signedOut;

  /// No description provided for @signedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed-in foundation'**
  String get signedIn;

  /// No description provided for @placeholder.
  ///
  /// In en, this message translates to:
  /// **'Foundation placeholder. Product screens are not implemented.'**
  String get placeholder;

  /// No description provided for @updateRequired.
  ///
  /// In en, this message translates to:
  /// **'An app update is required.'**
  String get updateRequired;

  /// No description provided for @startupFailed.
  ///
  /// In en, this message translates to:
  /// **'Jobix could not start. Check configuration and connectivity, then retry.'**
  String get startupFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-out could not complete. Please retry.'**
  String get signOutFailed;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @backAction.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backAction;

  /// No description provided for @skipOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Skip introduction'**
  String get skipOnboarding;

  /// No description provided for @skipShort.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipShort;

  /// No description provided for @languageSwitch.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get languageSwitch;

  /// No description provided for @onboardingTitleOne.
  ///
  /// In en, this message translates to:
  /// **'Build a professional, ATS-friendly CV'**
  String get onboardingTitleOne;

  /// No description provided for @onboardingTitleTwo.
  ///
  /// In en, this message translates to:
  /// **'Turn your experience into professional content'**
  String get onboardingTitleTwo;

  /// No description provided for @onboardingTitleThree.
  ///
  /// In en, this message translates to:
  /// **'Create it once. Update it anytime.'**
  String get onboardingTitleThree;

  /// No description provided for @onboardingBodyOne.
  ///
  /// In en, this message translates to:
  /// **'Create a CV that clearly presents your experience, skills, and strengths — without the hassle of starting from scratch.'**
  String get onboardingBodyOne;

  /// No description provided for @onboardingBodyTwo.
  ///
  /// In en, this message translates to:
  /// **'Describe your experience in your own words. Jobix can help refine it into clear, professional CV-ready content — without inventing information.'**
  String get onboardingBodyTwo;

  /// No description provided for @onboardingBodyThree.
  ///
  /// In en, this message translates to:
  /// **'Choose your CV template, export it as a PDF, and keep your information ready to update whenever your career changes.'**
  String get onboardingBodyThree;

  /// No description provided for @researchHeading.
  ///
  /// In en, this message translates to:
  /// **'A little about your career'**
  String get researchHeading;

  /// No description provided for @contextOnly.
  ///
  /// In en, this message translates to:
  /// **'These answers are context only. They do not become CV content or change your access to Jobix.'**
  String get contextOnly;

  /// No description provided for @questionStage.
  ///
  /// In en, this message translates to:
  /// **'Which best describes your current career stage?'**
  String get questionStage;

  /// No description provided for @questionGoal.
  ///
  /// In en, this message translates to:
  /// **'What are you currently looking to achieve in your career?'**
  String get questionGoal;

  /// No description provided for @questionLocation.
  ///
  /// In en, this message translates to:
  /// **'Where are you currently looking for job opportunities?'**
  String get questionLocation;

  /// No description provided for @questionHelp.
  ///
  /// In en, this message translates to:
  /// **'What would you most like help with in your career?'**
  String get questionHelp;

  /// No description provided for @helpLimit.
  ///
  /// In en, this message translates to:
  /// **'Select up to 3'**
  String get helpLimit;

  /// No description provided for @stageStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get stageStudent;

  /// No description provided for @stageGraduate.
  ///
  /// In en, this message translates to:
  /// **'Recent Graduate (0–1 year of experience)'**
  String get stageGraduate;

  /// No description provided for @stageEarly.
  ///
  /// In en, this message translates to:
  /// **'Early-Career Professional (1–3 years of experience)'**
  String get stageEarly;

  /// No description provided for @stageMid.
  ///
  /// In en, this message translates to:
  /// **'Mid-Career Professional (4–7 years of experience)'**
  String get stageMid;

  /// No description provided for @stageExperienced.
  ///
  /// In en, this message translates to:
  /// **'Experienced Professional (8+ years of experience)'**
  String get stageExperienced;

  /// No description provided for @stageReturning.
  ///
  /// In en, this message translates to:
  /// **'Return to work after a break'**
  String get stageReturning;

  /// No description provided for @stageChanger.
  ///
  /// In en, this message translates to:
  /// **'Career Changer'**
  String get stageChanger;

  /// No description provided for @goalFirst.
  ///
  /// In en, this message translates to:
  /// **'Find my first job'**
  String get goalFirst;

  /// No description provided for @goalBetter.
  ///
  /// In en, this message translates to:
  /// **'Find a new or better job'**
  String get goalBetter;

  /// No description provided for @goalChange.
  ///
  /// In en, this message translates to:
  /// **'Change my career'**
  String get goalChange;

  /// No description provided for @goalAdvance.
  ///
  /// In en, this message translates to:
  /// **'Advance in my current career'**
  String get goalAdvance;

  /// No description provided for @goalPrepare.
  ///
  /// In en, this message translates to:
  /// **'Prepare for future opportunities'**
  String get goalPrepare;

  /// No description provided for @notSure.
  ///
  /// In en, this message translates to:
  /// **'I\'m not sure yet'**
  String get notSure;

  /// No description provided for @locationCity.
  ///
  /// In en, this message translates to:
  /// **'In my current city'**
  String get locationCity;

  /// No description provided for @locationCountry.
  ///
  /// In en, this message translates to:
  /// **'Elsewhere in my country'**
  String get locationCountry;

  /// No description provided for @locationRemote.
  ///
  /// In en, this message translates to:
  /// **'Remotely'**
  String get locationRemote;

  /// No description provided for @locationAbroad.
  ///
  /// In en, this message translates to:
  /// **'Abroad'**
  String get locationAbroad;

  /// No description provided for @locationMultiple.
  ///
  /// In en, this message translates to:
  /// **'Open to multiple options'**
  String get locationMultiple;

  /// No description provided for @helpCv.
  ///
  /// In en, this message translates to:
  /// **'Create a stronger CV'**
  String get helpCv;

  /// No description provided for @helpOpportunities.
  ///
  /// In en, this message translates to:
  /// **'Find better career opportunities'**
  String get helpOpportunities;

  /// No description provided for @helpPaths.
  ///
  /// In en, this message translates to:
  /// **'Discover suitable career paths'**
  String get helpPaths;

  /// No description provided for @helpOnline.
  ///
  /// In en, this message translates to:
  /// **'Work Online'**
  String get helpOnline;

  /// No description provided for @helpSkills.
  ///
  /// In en, this message translates to:
  /// **'Learn New Skills'**
  String get helpSkills;

  /// No description provided for @helpInterviews.
  ///
  /// In en, this message translates to:
  /// **'Prepare for job interviews'**
  String get helpInterviews;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Jobix'**
  String get welcome;

  /// No description provided for @authSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your career, in your own words. Create an account or sign in to continue.'**
  String get authSubtitle;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @existingAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to an existing account'**
  String get existingAccount;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @googleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get googleSignIn;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @sendReset.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendReset;

  /// No description provided for @resetSent.
  ///
  /// In en, this message translates to:
  /// **'If an account exists, a password reset link has been sent. Open the link to choose a new password.'**
  String get resetSent;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @updatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get updatePassword;

  /// No description provided for @passwordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Your password was updated.'**
  String get passwordUpdated;

  /// No description provided for @confirmEmail.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get confirmEmail;

  /// No description provided for @confirmEmailBody.
  ///
  /// In en, this message translates to:
  /// **'Open the confirmation link in your email, then sign in. You are not signed in until your email is confirmed.'**
  String get confirmEmailBody;

  /// No description provided for @authError.
  ///
  /// In en, this message translates to:
  /// **'We could not complete authentication. Check your details, confirmation status and connection, then retry.'**
  String get authError;

  /// No description provided for @googleUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in could not open. Please retry or use email and password.'**
  String get googleUnavailable;

  /// No description provided for @localWriteError.
  ///
  /// In en, this message translates to:
  /// **'Your changes could not be saved on this device. Please retry before leaving.'**
  String get localWriteError;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your career starts here'**
  String get homeTitle;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your information ready for your next opportunity.'**
  String get homeSubtitle;

  /// No description provided for @careerTitle.
  ///
  /// In en, this message translates to:
  /// **'Career Profile #1'**
  String get careerTitle;

  /// No description provided for @nextAction.
  ///
  /// In en, this message translates to:
  /// **'Your next Career action'**
  String get nextAction;

  /// No description provided for @continueCareer.
  ///
  /// In en, this message translates to:
  /// **'Continue Career'**
  String get continueCareer;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @personalIntro.
  ///
  /// In en, this message translates to:
  /// **'Start with your contact details. You can save or leave at any time, even if this section is incomplete.'**
  String get personalIntro;

  /// No description provided for @moreStepsLater.
  ///
  /// In en, this message translates to:
  /// **'Other Career steps are not available in this slice yet.'**
  String get moreStepsLater;

  /// No description provided for @draftAvailable.
  ///
  /// In en, this message translates to:
  /// **'You have unfinished work saved on this device.'**
  String get draftAvailable;

  /// No description provided for @contextPending.
  ///
  /// In en, this message translates to:
  /// **'Your research answers are saved on this device. Retry to save them to your account.'**
  String get contextPending;

  /// No description provided for @profileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your first Profile could not be loaded. Please retry. No local substitute Profile has been created.'**
  String get profileUnavailable;

  /// No description provided for @resumeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Resume Language'**
  String get resumeLanguage;

  /// No description provided for @resumeLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the language for Profile labels and examples. Your app language and existing content will not change.'**
  String get resumeLanguageHint;

  /// No description provided for @chooseResumeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose a Resume Language to start entering your information.'**
  String get chooseResumeLanguage;

  /// No description provided for @contactHeading.
  ///
  /// In en, this message translates to:
  /// **'Contact Essentials'**
  String get contactHeading;

  /// No description provided for @optionalHeading.
  ///
  /// In en, this message translates to:
  /// **'Professional Links'**
  String get optionalHeading;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @countryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country (optional)'**
  String get countryLabel;

  /// No description provided for @cityLabel.
  ///
  /// In en, this message translates to:
  /// **'City (optional)'**
  String get cityLabel;

  /// No description provided for @linkedInLabel.
  ///
  /// In en, this message translates to:
  /// **'LinkedIn (optional)'**
  String get linkedInLabel;

  /// No description provided for @githubLabel.
  ///
  /// In en, this message translates to:
  /// **'GitHub (optional)'**
  String get githubLabel;

  /// No description provided for @portfolioLabel.
  ///
  /// In en, this message translates to:
  /// **'Portfolio (optional)'**
  String get portfolioLabel;

  /// No description provided for @nameExample.
  ///
  /// In en, this message translates to:
  /// **'Your full name'**
  String get nameExample;

  /// No description provided for @emailExample.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get emailExample;

  /// No description provided for @phoneExample.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneExample;

  /// No description provided for @countryExample.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get countryExample;

  /// No description provided for @cityExample.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityExample;

  /// No description provided for @useEgypt.
  ///
  /// In en, this message translates to:
  /// **'Use Egypt'**
  String get useEgypt;

  /// No description provided for @exportRequiredHint.
  ///
  /// In en, this message translates to:
  /// **'Name, email and phone are required for eventual export, not for saving or leaving.'**
  String get exportRequiredHint;

  /// No description provided for @phoneValidationHint.
  ///
  /// In en, this message translates to:
  /// **'Format checks do not verify that a phone number is active.'**
  String get phoneValidationHint;

  /// No description provided for @saveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAction;

  /// No description provided for @leaveAction.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leaveAction;

  /// No description provided for @saveLater.
  ///
  /// In en, this message translates to:
  /// **'Save & Continue Later'**
  String get saveLater;

  /// No description provided for @discardAction.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardAction;

  /// No description provided for @stayAction.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get stayAction;

  /// No description provided for @leaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your unfinished work?'**
  String get leaveTitle;

  /// No description provided for @discardWarning.
  ///
  /// In en, this message translates to:
  /// **'Save your draft to continue later, or discard only the unsynced local draft. Discarded work cannot be recovered. Saved server data will not be deleted.'**
  String get discardWarning;

  /// No description provided for @savedServer.
  ///
  /// In en, this message translates to:
  /// **'Saved to your account.'**
  String get savedServer;

  /// No description provided for @savedDevice.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device. It has not been saved to your account yet.'**
  String get savedDevice;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Server save did not complete. Your draft is retained on this device. Retry to reconcile the result.'**
  String get saveFailed;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get invalidEmail;

  /// No description provided for @invalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a plausible phone number using digits, spaces, parentheses or hyphens.'**
  String get invalidPhone;

  /// No description provided for @invalidLink.
  ///
  /// In en, this message translates to:
  /// **'Use a full HTTPS link, for example https://linkedin.com/in/your-name.'**
  String get invalidLink;

  /// No description provided for @conflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Profile changed elsewhere'**
  String get conflictTitle;

  /// No description provided for @conflictBody.
  ///
  /// In en, this message translates to:
  /// **'Your local work is still safe. Keep the saved server version or explicitly reapply your local work.'**
  String get conflictBody;

  /// No description provided for @keepServer.
  ///
  /// In en, this message translates to:
  /// **'Keep server version'**
  String get keepServer;

  /// No description provided for @reapplyLocal.
  ///
  /// In en, this message translates to:
  /// **'Reapply local work'**
  String get reapplyLocal;

  /// No description provided for @outcomeUnknown.
  ///
  /// In en, this message translates to:
  /// **'The previous save result is not yet confirmed. Retry the save before discarding; already-saved server data cannot be undone here.'**
  String get outcomeUnknown;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show or hide password'**
  String get showPassword;

  /// No description provided for @locationDataMissing.
  ///
  /// In en, this message translates to:
  /// **'Enter a city, or choose one you have saved before.'**
  String get locationDataMissing;

  /// No description provided for @signOutLocalWarning.
  ///
  /// In en, this message translates to:
  /// **'Signing out removes unsaved local work from this device. Data already saved to your account is kept.'**
  String get signOutLocalWarning;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
