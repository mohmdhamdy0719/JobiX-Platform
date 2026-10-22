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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @sectionVolunteer.
  ///
  /// In en, this message translates to:
  /// **'Volunteer Experience'**
  String get sectionVolunteer;

  /// No description provided for @addVolunteer.
  ///
  /// In en, this message translates to:
  /// **'Add volunteer role'**
  String get addVolunteer;

  /// No description provided for @fieldOrganization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get fieldOrganization;

  /// No description provided for @currentVolunteer.
  ///
  /// In en, this message translates to:
  /// **'Currently volunteering'**
  String get currentVolunteer;

  /// No description provided for @exitTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit Jobix?'**
  String get exitTitle;

  /// No description provided for @exitMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to close Jobix?'**
  String get exitMessage;

  /// No description provided for @exitAction.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exitAction;

  /// No description provided for @itemSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get itemSaved;

  /// No description provided for @pendingBackWarning.
  ///
  /// In en, this message translates to:
  /// **'The earlier Save may already have reached the server. Back discards only unsubmitted edits, not that request. Its exact request is retained for Retry; no new Save will be sent.'**
  String get pendingBackWarning;

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
  /// **'Your preferences help us tailor your future JobiX experience. You can change them anytime in Settings.'**
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

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Build your career profile and prepare for your next opportunity.'**
  String get welcomeSubtitle;

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

  /// No description provided for @googleCheckingAvailability.
  ///
  /// In en, this message translates to:
  /// **'Checking Google sign-in availability…'**
  String get googleCheckingAvailability;

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
  /// **'Start with your contact details. You can save or leave at any time.'**
  String get personalIntro;

  /// No description provided for @moreStepsLater.
  ///
  /// In en, this message translates to:
  /// **'Other Career steps are not available in this slice yet.'**
  String get moreStepsLater;

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
  /// **'Choose the language for your Resume. Your app language and existing content will stay unchanged.'**
  String get resumeLanguageHint;

  /// No description provided for @chooseResumeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose a Resume language before editing your information.'**
  String get chooseResumeLanguage;

  /// No description provided for @changeResumeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change Resume language'**
  String get changeResumeLanguage;

  /// No description provided for @resumeLanguageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The Resume language could not be saved. Check your connection and try again.'**
  String get resumeLanguageSaveFailed;

  /// No description provided for @resumeLanguageChanged.
  ///
  /// In en, this message translates to:
  /// **'Resume language updated.'**
  String get resumeLanguageChanged;

  /// No description provided for @doneAction.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneAction;

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
  /// **'Discard changes'**
  String get discardAction;

  /// No description provided for @stayAction.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get stayAction;

  /// No description provided for @leaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get leaveTitle;

  /// No description provided for @discardWarning.
  ///
  /// In en, this message translates to:
  /// **'Your changes haven\'t been saved. If you leave now, you\'ll lose them.'**
  String get discardWarning;

  /// No description provided for @savedServer.
  ///
  /// In en, this message translates to:
  /// **'Saved to your account.'**
  String get savedServer;

  /// No description provided for @savedDevice.
  ///
  /// In en, this message translates to:
  /// **'Draft saved. You can finish it later; drafts don\'t appear in your Resume.'**
  String get savedDevice;

  /// No description provided for @draftNeedsInformation.
  ///
  /// In en, this message translates to:
  /// **'Add some information before saving a draft.'**
  String get draftNeedsInformation;

  /// No description provided for @saveDraftPrompt.
  ///
  /// In en, this message translates to:
  /// **'Some required details are missing. Save this as a draft and finish it later.'**
  String get saveDraftPrompt;

  /// No description provided for @incompleteEntry.
  ///
  /// In en, this message translates to:
  /// **'This entry is incomplete. Complete the required fields before adding it to your Resume.'**
  String get incompleteEntry;

  /// No description provided for @resumeChangedSincePreview.
  ///
  /// In en, this message translates to:
  /// **'The saved Resume changed since this preview. Review the updated version before exporting.'**
  String get resumeChangedSincePreview;

  /// No description provided for @reviewUpdatedResume.
  ///
  /// In en, this message translates to:
  /// **'Review this version'**
  String get reviewUpdatedResume;

  /// No description provided for @skillsAndLanguages.
  ///
  /// In en, this message translates to:
  /// **'Skills and Languages'**
  String get skillsAndLanguages;

  /// No description provided for @localDraftsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Drafts on this device could not be read. Your saved account data is unchanged.'**
  String get localDraftsUnavailable;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not confirm a save to your account. Keep your edits here and try again.'**
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

  /// No description provided for @loginAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginAction;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back. Sign in to continue your career profile.'**
  String get loginSubtitle;

  /// No description provided for @signupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account to keep your career information together.'**
  String get signupSubtitle;

  /// No description provided for @providerSettingsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Other sign-in options could not be verified. Email sign-in is still available.'**
  String get providerSettingsUnavailable;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get passwordRequired;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @startupStorageFailed.
  ///
  /// In en, this message translates to:
  /// **'Jobix could not open the protected local store. Retry to continue; your data has not been reset.'**
  String get startupStorageFailed;

  /// No description provided for @startupSessionFailed.
  ///
  /// In en, this message translates to:
  /// **'Jobix could not restore your secure session. Check your connection and retry.'**
  String get startupSessionFailed;

  /// No description provided for @startupPolicyFailed.
  ///
  /// In en, this message translates to:
  /// **'Jobix could not verify the required app policy. Check your connection and retry.'**
  String get startupPolicyFailed;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get haveAccount;

  /// No description provided for @needAccount.
  ///
  /// In en, this message translates to:
  /// **'New to Jobix? Create an account'**
  String get needAccount;

  /// No description provided for @legalLinksUnavailable.
  ///
  /// In en, this message translates to:
  /// **'By creating an account, you acknowledge the Terms of Service and Privacy Policy. Their links are not configured yet.'**
  String get legalLinksUnavailable;

  /// No description provided for @researchLoadError.
  ///
  /// In en, this message translates to:
  /// **'Your saved career context could not be loaded. Your existing answers have not been changed.'**
  String get researchLoadError;

  /// No description provided for @researchStep.
  ///
  /// In en, this message translates to:
  /// **'STEP {number} OF 4'**
  String researchStep(int number);

  /// No description provided for @locationDataMissing.
  ///
  /// In en, this message translates to:
  /// **'Enter a city, or choose one you have saved before.'**
  String get locationDataMissing;

  /// No description provided for @signOutLocalWarning.
  ///
  /// In en, this message translates to:
  /// **'Signing out removes unsaved changes kept only on this device. Information already saved to your account will remain.'**
  String get signOutLocalWarning;

  /// No description provided for @homeNav.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeNav;

  /// No description provided for @careerNav.
  ///
  /// In en, this message translates to:
  /// **'Career'**
  String get careerNav;

  /// No description provided for @settingsNav.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsNav;

  /// No description provided for @balanceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Credit balance is temporarily unavailable.'**
  String get balanceUnavailable;

  /// No description provided for @availableCredits.
  ///
  /// In en, this message translates to:
  /// **'Available Credits'**
  String get availableCredits;

  /// No description provided for @viewHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get viewHistory;

  /// No description provided for @careerPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Career Profile'**
  String get careerPageTitle;

  /// No description provided for @careerPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your professional information accurate and ready to use.'**
  String get careerPageSubtitle;

  /// No description provided for @activeProfile.
  ///
  /// In en, this message translates to:
  /// **'Your current profile'**
  String get activeProfile;

  /// No description provided for @profileTruthNote.
  ///
  /// In en, this message translates to:
  /// **'This profile is your career information. Resume tools and other profile sections are not available in this release.'**
  String get profileTruthNote;

  /// No description provided for @notEntered.
  ///
  /// In en, this message translates to:
  /// **'Not entered'**
  String get notEntered;

  /// No description provided for @editPersonalInformation.
  ///
  /// In en, this message translates to:
  /// **'Edit Personal Information'**
  String get editPersonalInformation;

  /// No description provided for @careerOtherSectionsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Additional profile sections are not available in this release.'**
  String get careerOtherSectionsUnavailable;

  /// No description provided for @arabicLanguage.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabicLanguage;

  /// No description provided for @englishLanguage.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishLanguage;

  /// No description provided for @accountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSection;

  /// No description provided for @accountInformation.
  ///
  /// In en, this message translates to:
  /// **'Account Information'**
  String get accountInformation;

  /// No description provided for @accountInfoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Account information is temporarily unavailable.'**
  String get accountInfoUnavailable;

  /// No description provided for @personalInfoSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Edit your saved contact information'**
  String get personalInfoSettingsHint;

  /// No description provided for @preferencesSection.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferencesSection;

  /// No description provided for @languageSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Controls the Jobix app interface'**
  String get languageSettingsHint;

  /// No description provided for @careerDataSection.
  ///
  /// In en, this message translates to:
  /// **'Career & Data'**
  String get careerDataSection;

  /// No description provided for @creditHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Credit History'**
  String get creditHistoryTitle;

  /// No description provided for @creditHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Server-recorded changes to your available Credits.'**
  String get creditHistorySubtitle;

  /// No description provided for @supportSection.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get supportSection;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @serviceNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Support contact is not configured yet.'**
  String get serviceNotConfigured;

  /// No description provided for @legalSection.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legalSection;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @legalUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Link not configured yet.'**
  String get legalUnavailable;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @accountActionsSection.
  ///
  /// In en, this message translates to:
  /// **'Account Actions'**
  String get accountActionsSection;

  /// No description provided for @settingsFooter.
  ///
  /// In en, this message translates to:
  /// **'Jobix keeps your career information factual and under your control.'**
  String get settingsFooter;

  /// No description provided for @creditHistoryLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Credit history could not be loaded. No history has been assumed.'**
  String get creditHistoryLoadFailed;

  /// No description provided for @creditHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No credit transactions are available for this account yet.'**
  String get creditHistoryEmpty;

  /// No description provided for @moreTransactionsFailed.
  ///
  /// In en, this message translates to:
  /// **'More transactions could not be loaded.'**
  String get moreTransactionsFailed;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @creditTransaction.
  ///
  /// In en, this message translates to:
  /// **'Credit transaction'**
  String get creditTransaction;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String stepOf(Object step, Object total);

  /// No description provided for @stepPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal Info & Links'**
  String get stepPersonal;

  /// No description provided for @stepSummary.
  ///
  /// In en, this message translates to:
  /// **'Professional Summary'**
  String get stepSummary;

  /// No description provided for @stepExperience.
  ///
  /// In en, this message translates to:
  /// **'Work Experience'**
  String get stepExperience;

  /// No description provided for @stepEducation.
  ///
  /// In en, this message translates to:
  /// **'Education & Credentials'**
  String get stepEducation;

  /// No description provided for @stepSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills, Projects & Languages'**
  String get stepSkills;

  /// No description provided for @stepReview.
  ///
  /// In en, this message translates to:
  /// **'Review Profile'**
  String get stepReview;

  /// No description provided for @skipAction.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipAction;

  /// No description provided for @itemsAdded.
  ///
  /// In en, this message translates to:
  /// **'{count} added'**
  String itemsAdded(Object count);

  /// No description provided for @addRole.
  ///
  /// In en, this message translates to:
  /// **'Add Role'**
  String get addRole;

  /// No description provided for @addEducation.
  ///
  /// In en, this message translates to:
  /// **'Add Education'**
  String get addEducation;

  /// No description provided for @addCertification.
  ///
  /// In en, this message translates to:
  /// **'Add Certification'**
  String get addCertification;

  /// No description provided for @addAchievement.
  ///
  /// In en, this message translates to:
  /// **'Add Achievement'**
  String get addAchievement;

  /// No description provided for @addProject.
  ///
  /// In en, this message translates to:
  /// **'Add Project'**
  String get addProject;

  /// No description provided for @addLanguage.
  ///
  /// In en, this message translates to:
  /// **'Add Language'**
  String get addLanguage;

  /// No description provided for @sectionEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get sectionEducation;

  /// No description provided for @sectionCertifications.
  ///
  /// In en, this message translates to:
  /// **'Certifications'**
  String get sectionCertifications;

  /// No description provided for @sectionAchievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get sectionAchievements;

  /// No description provided for @sectionSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get sectionSkills;

  /// No description provided for @sectionProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get sectionProjects;

  /// No description provided for @sectionLanguages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get sectionLanguages;

  /// No description provided for @emptyExperience.
  ///
  /// In en, this message translates to:
  /// **'No roles added yet. Add one now or skip this step.'**
  String get emptyExperience;

  /// No description provided for @emptySection.
  ///
  /// In en, this message translates to:
  /// **'Nothing added yet.'**
  String get emptySection;

  /// No description provided for @presentLabel.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get presentLabel;

  /// No description provided for @currentRole.
  ///
  /// In en, this message translates to:
  /// **'I currently work here'**
  String get currentRole;

  /// No description provided for @currentStudy.
  ///
  /// In en, this message translates to:
  /// **'I currently study here'**
  String get currentStudy;

  /// No description provided for @itemIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Needs details'**
  String get itemIncomplete;

  /// No description provided for @itemComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get itemComplete;

  /// No description provided for @editAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editAction;

  /// No description provided for @removeAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeAction;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// No description provided for @removeTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this item?'**
  String get removeTitle;

  /// No description provided for @removeBody.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from your profile.'**
  String get removeBody;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// No description provided for @fieldJobTitle.
  ///
  /// In en, this message translates to:
  /// **'Job title'**
  String get fieldJobTitle;

  /// No description provided for @fieldCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get fieldCompany;

  /// No description provided for @fieldLocation.
  ///
  /// In en, this message translates to:
  /// **'Location (optional)'**
  String get fieldLocation;

  /// No description provided for @fieldStartMonth.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get fieldStartMonth;

  /// No description provided for @fieldEndMonth.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get fieldEndMonth;

  /// No description provided for @fieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get fieldDescription;

  /// No description provided for @fieldDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get fieldDescriptionOptional;

  /// No description provided for @fieldDegree.
  ///
  /// In en, this message translates to:
  /// **'Degree'**
  String get fieldDegree;

  /// No description provided for @fieldInstitution.
  ///
  /// In en, this message translates to:
  /// **'Institution'**
  String get fieldInstitution;

  /// No description provided for @institutionAutocompleteHint.
  ///
  /// In en, this message translates to:
  /// **'Type an institution name or enter your own.'**
  String get institutionAutocompleteHint;

  /// No description provided for @fieldStudy.
  ///
  /// In en, this message translates to:
  /// **'Field of study'**
  String get fieldStudy;

  /// No description provided for @studyFieldAutocompleteHint.
  ///
  /// In en, this message translates to:
  /// **'Search or enter your own field of study.'**
  String get studyFieldAutocompleteHint;

  /// No description provided for @educationSuggestionsFallback.
  ///
  /// In en, this message translates to:
  /// **'Common suggestions only; you can still enter any value.'**
  String get educationSuggestionsFallback;

  /// No description provided for @clearField.
  ///
  /// In en, this message translates to:
  /// **'Clear field'**
  String get clearField;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @fieldIssuer.
  ///
  /// In en, this message translates to:
  /// **'Issuer'**
  String get fieldIssuer;

  /// No description provided for @fieldIssueMonth.
  ///
  /// In en, this message translates to:
  /// **'Issue date'**
  String get fieldIssueMonth;

  /// No description provided for @fieldExpiryMonth.
  ///
  /// In en, this message translates to:
  /// **'Expiry date (optional)'**
  String get fieldExpiryMonth;

  /// No description provided for @fieldCredential.
  ///
  /// In en, this message translates to:
  /// **'Credential ID (optional)'**
  String get fieldCredential;

  /// No description provided for @fieldUrl.
  ///
  /// In en, this message translates to:
  /// **'Link (optional)'**
  String get fieldUrl;

  /// No description provided for @fieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get fieldTitle;

  /// No description provided for @fieldMonth.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get fieldMonth;

  /// No description provided for @fieldDegreeTitle.
  ///
  /// In en, this message translates to:
  /// **'Degree title'**
  String get fieldDegreeTitle;

  /// No description provided for @fieldDegreeTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your qualification'**
  String get fieldDegreeTitleHint;

  /// No description provided for @creditsCompactCount.
  ///
  /// In en, this message translates to:
  /// **'{count} CR'**
  String creditsCompactCount(int count);

  /// No description provided for @fieldRole.
  ///
  /// In en, this message translates to:
  /// **'Your role'**
  String get fieldRole;

  /// No description provided for @fieldTechnologies.
  ///
  /// In en, this message translates to:
  /// **'Technologies (comma separated)'**
  String get fieldTechnologies;

  /// No description provided for @fieldLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get fieldLanguage;

  /// No description provided for @fieldProficiency.
  ///
  /// In en, this message translates to:
  /// **'Proficiency'**
  String get fieldProficiency;

  /// No description provided for @monthHint.
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM'**
  String get monthHint;

  /// No description provided for @problemTooLong.
  ///
  /// In en, this message translates to:
  /// **'This is too long.'**
  String get problemTooLong;

  /// No description provided for @problemMonth.
  ///
  /// In en, this message translates to:
  /// **'Use the format YYYY-MM.'**
  String get problemMonth;

  /// No description provided for @problemUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a secure https link.'**
  String get problemUrl;

  /// No description provided for @problemEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'The end must be after the start.'**
  String get problemEndBeforeStart;

  /// No description provided for @problemRequired.
  ///
  /// In en, this message translates to:
  /// **'This is required.'**
  String get problemRequired;

  /// No description provided for @descriptionMinimum.
  ///
  /// In en, this message translates to:
  /// **'Write at least 20 characters for this to count toward completeness.'**
  String get descriptionMinimum;

  /// No description provided for @incompleteSaveNote.
  ///
  /// In en, this message translates to:
  /// **'You can save now and finish the details later; incomplete items don\'t count toward completeness.'**
  String get incompleteSaveNote;

  /// No description provided for @profBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get profBasic;

  /// No description provided for @profConversational.
  ///
  /// In en, this message translates to:
  /// **'Conversational'**
  String get profConversational;

  /// No description provided for @profProfessional.
  ///
  /// In en, this message translates to:
  /// **'Professional'**
  String get profProfessional;

  /// No description provided for @profFluent.
  ///
  /// In en, this message translates to:
  /// **'Fluent'**
  String get profFluent;

  /// No description provided for @profNative.
  ///
  /// In en, this message translates to:
  /// **'Native'**
  String get profNative;

  /// No description provided for @skillHint.
  ///
  /// In en, this message translates to:
  /// **'Type a skill'**
  String get skillHint;

  /// No description provided for @addAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addAction;

  /// No description provided for @duplicateItem.
  ///
  /// In en, this message translates to:
  /// **'This is already in your list.'**
  String get duplicateItem;

  /// No description provided for @suggestedSkills.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get suggestedSkills;

  /// No description provided for @saveConflict.
  ///
  /// In en, this message translates to:
  /// **'This profile changed on another device. Reload to see the latest version; your edits stay on this device.'**
  String get saveConflict;

  /// No description provided for @reloadAction.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reloadAction;

  /// No description provided for @savePending.
  ///
  /// In en, this message translates to:
  /// **'A previous save hasn\'t been confirmed yet.'**
  String get savePending;

  /// No description provided for @retrySave.
  ///
  /// In en, this message translates to:
  /// **'Retry save'**
  String get retrySave;

  /// No description provided for @itemNotFound.
  ///
  /// In en, this message translates to:
  /// **'This item no longer exists.'**
  String get itemNotFound;

  /// No description provided for @reviewIntro.
  ///
  /// In en, this message translates to:
  /// **'Check each section. Tap Edit to change anything.'**
  String get reviewIntro;

  /// No description provided for @completenessLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile completeness'**
  String get completenessLabel;

  /// No description provided for @aiAuditSoon.
  ///
  /// In en, this message translates to:
  /// **'ATS and AI review aren\'t available yet.'**
  String get aiAuditSoon;

  /// No description provided for @aiSoon.
  ///
  /// In en, this message translates to:
  /// **'Improve with JobiX isn\'t available yet.'**
  String get aiSoon;

  /// No description provided for @targetRoleOptional.
  ///
  /// In en, this message translates to:
  /// **'Target role (optional)'**
  String get targetRoleOptional;

  /// No description provided for @notProvided.
  ///
  /// In en, this message translates to:
  /// **'Not added'**
  String get notProvided;

  /// No description provided for @profileSlot.
  ///
  /// In en, this message translates to:
  /// **'Profile {slot}'**
  String profileSlot(Object slot);

  /// No description provided for @continueProfile.
  ///
  /// In en, this message translates to:
  /// **'Continue Profile'**
  String get continueProfile;

  /// No description provided for @sectionStatusCount.
  ///
  /// In en, this message translates to:
  /// **'{complete} of {total} complete'**
  String sectionStatusCount(Object complete, Object total);

  /// No description provided for @contactSection.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contactSection;

  /// No description provided for @authRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many emails were requested. Wait a while, then try again.'**
  String get authRateLimited;

  /// No description provided for @authNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email first. Check your inbox or resend the link.'**
  String get authNotConfirmed;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect.'**
  String get authInvalidCredentials;

  /// No description provided for @authWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a stronger password (at least 8 characters).'**
  String get authWeakPassword;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authInvalidEmail;

  /// No description provided for @authUserExists.
  ///
  /// In en, this message translates to:
  /// **'An account already exists for this email. Sign in instead.'**
  String get authUserExists;

  /// No description provided for @authNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get authNetwork;

  /// No description provided for @resendConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Resend confirmation email'**
  String get resendConfirmation;

  /// No description provided for @confirmationResent.
  ///
  /// In en, this message translates to:
  /// **'A new confirmation email was sent.'**
  String get confirmationResent;

  /// No description provided for @notSavedYet.
  ///
  /// In en, this message translates to:
  /// **'Not saved yet'**
  String get notSavedYet;

  /// No description provided for @reviewPersonalMissing.
  ///
  /// In en, this message translates to:
  /// **'Add your name, email and phone to export a resume later.'**
  String get reviewPersonalMissing;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String welcomeBack(Object name);

  /// No description provided for @homeOverview.
  ///
  /// In en, this message translates to:
  /// **'Here is your career overview.'**
  String get homeOverview;

  /// No description provided for @creditsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} credits'**
  String creditsCount(Object count);

  /// No description provided for @moreCount.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String moreCount(Object count);

  /// No description provided for @sectionsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} sections to finish'**
  String sectionsRemaining(Object count);

  /// No description provided for @itemChangedElsewhere.
  ///
  /// In en, this message translates to:
  /// **'This item was changed on another device after you started editing. Choose which version to keep.'**
  String get itemChangedElsewhere;

  /// No description provided for @itemRemovedElsewhere.
  ///
  /// In en, this message translates to:
  /// **'This item was removed on another device after you started editing. Choose whether to keep it removed or add it back with your changes.'**
  String get itemRemovedElsewhere;

  /// No description provided for @keepServerVersion.
  ///
  /// In en, this message translates to:
  /// **'Use the latest version'**
  String get keepServerVersion;

  /// No description provided for @reapplyMyChanges.
  ///
  /// In en, this message translates to:
  /// **'Keep my changes'**
  String get reapplyMyChanges;

  /// No description provided for @exportRateLimited.
  ///
  /// In en, this message translates to:
  /// **'You have reached the export limit. Please wait before retrying the saved request.'**
  String get exportRateLimited;

  /// No description provided for @exportRateLimitedRetry.
  ///
  /// In en, this message translates to:
  /// **'You have reached the export limit. Wait {seconds} seconds, then retry the saved request.'**
  String exportRateLimitedRetry(int seconds);

  /// No description provided for @exportTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Service is temporarily unavailable. Please try again later.'**
  String get exportTemporarilyUnavailable;

  /// No description provided for @exportInProgress.
  ///
  /// In en, this message translates to:
  /// **'An export for this profile is already in progress. Check its status before starting another.'**
  String get exportInProgress;

  /// No description provided for @backToReview.
  ///
  /// In en, this message translates to:
  /// **'Back to Review'**
  String get backToReview;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
