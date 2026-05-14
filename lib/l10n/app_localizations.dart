import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_my.dart';

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
    Locale('en'),
    Locale('ja'),
    Locale('my')
  ];

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageSection;

  /// No description provided for @settingsAppearanceSection.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceSection;

  /// No description provided for @settingsAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountSection;

  /// No description provided for @settingsNotificationsSection.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationsSection;

  /// No description provided for @settingsAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutSection;

  /// No description provided for @settingsAppLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get settingsAppLanguage;

  /// No description provided for @settingsContentCommunity.
  ///
  /// In en, this message translates to:
  /// **'Content Community'**
  String get settingsContentCommunity;

  /// No description provided for @settingsLearningLanguage.
  ///
  /// In en, this message translates to:
  /// **'Learning Language'**
  String get settingsLearningLanguage;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get settingsComingSoon;

  /// No description provided for @settingsEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get settingsEditProfile;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsSignOutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this account on this device'**
  String get settingsSignOutSubtitle;

  /// No description provided for @settingsSignInRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in required'**
  String get settingsSignInRequiredTitle;

  /// No description provided for @settingsSignInRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'Settings are available after you sign in.'**
  String get settingsSignInRequiredBody;

  /// No description provided for @settingsSignInCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get settingsSignInCta;

  /// No description provided for @settingsAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get settingsAppVersion;

  /// No description provided for @settingsAppVersionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'V1 shell (version integration deferred)'**
  String get settingsAppVersionPlaceholder;

  /// No description provided for @settingsSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsSystem;

  /// No description provided for @settingsEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsEnglish;

  /// No description provided for @settingsJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get settingsJapanese;

  /// No description provided for @settingsMyanmar.
  ///
  /// In en, this message translates to:
  /// **'Myanmar'**
  String get settingsMyanmar;

  /// No description provided for @settingsInternationalEnglish.
  ///
  /// In en, this message translates to:
  /// **'International / English'**
  String get settingsInternationalEnglish;

  /// No description provided for @settingsSignOutDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get settingsSignOutDialogTitle;

  /// No description provided for @settingsSignOutDialogBody.
  ///
  /// In en, this message translates to:
  /// **'You will be signed out on this device and returned to the login screen.'**
  String get settingsSignOutDialogBody;

  /// No description provided for @settingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancel;

  /// No description provided for @settingsReadingSection.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get settingsReadingSection;

  /// No description provided for @settingsReadingTextSize.
  ///
  /// In en, this message translates to:
  /// **'Reading text size'**
  String get settingsReadingTextSize;

  /// No description provided for @settingsReadingTextSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get settingsReadingTextSizeSmall;

  /// No description provided for @settingsReadingTextSizeStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get settingsReadingTextSizeStandard;

  /// No description provided for @settingsReadingTextSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get settingsReadingTextSizeLarge;

  /// No description provided for @settingsShowExplanationSentence.
  ///
  /// In en, this message translates to:
  /// **'Explanation sentence'**
  String get settingsShowExplanationSentence;

  /// No description provided for @settingsShowExplanationSentenceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show per-sentence explanations in the mono reader'**
  String get settingsShowExplanationSentenceSubtitle;

  /// No description provided for @validationPublishSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Before publishing'**
  String get validationPublishSheetTitle;

  /// No description provided for @validationPublishSectionBlocking.
  ///
  /// In en, this message translates to:
  /// **'Blocking'**
  String get validationPublishSectionBlocking;

  /// No description provided for @validationPublishSectionRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get validationPublishSectionRecommended;

  /// No description provided for @validationPublishFixIssuesCta.
  ///
  /// In en, this message translates to:
  /// **'Fix issues'**
  String get validationPublishFixIssuesCta;

  /// No description provided for @validationPublishAnywayCta.
  ///
  /// In en, this message translates to:
  /// **'Publish anyway'**
  String get validationPublishAnywayCta;

  /// No description provided for @validationCtaSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get validationCtaSignIn;

  /// No description provided for @validationCtaNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get validationCtaNotNow;

  /// No description provided for @validationCtaOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get validationCtaOk;

  /// No description provided for @validationMediaUploadGenericImage.
  ///
  /// In en, this message translates to:
  /// **'Could not upload image. Please try again.'**
  String get validationMediaUploadGenericImage;

  /// No description provided for @validationMediaUploadGenericAudio.
  ///
  /// In en, this message translates to:
  /// **'Could not upload audio. Please try again.'**
  String get validationMediaUploadGenericAudio;

  /// No description provided for @validationFieldStoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Story title'**
  String get validationFieldStoryTitle;

  /// No description provided for @validationFieldStoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get validationFieldStoryDescription;

  /// No description provided for @validationFieldStorySentences.
  ///
  /// In en, this message translates to:
  /// **'Sentences'**
  String get validationFieldStorySentences;

  /// No description provided for @validationFieldStoryBody.
  ///
  /// In en, this message translates to:
  /// **'Story body'**
  String get validationFieldStoryBody;

  /// No description provided for @validationFieldStoryLevel.
  ///
  /// In en, this message translates to:
  /// **'JLPT level'**
  String get validationFieldStoryLevel;

  /// No description provided for @validationFieldStoryDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get validationFieldStoryDuration;

  /// No description provided for @validationFieldLearnVocabCount.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary'**
  String get validationFieldLearnVocabCount;

  /// No description provided for @validationFieldLearnGrammarCount.
  ///
  /// In en, this message translates to:
  /// **'Grammar'**
  String get validationFieldLearnGrammarCount;

  /// No description provided for @validationFieldLearnQuizCount.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get validationFieldLearnQuizCount;

  /// No description provided for @validationFieldLearnVocabulary.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary'**
  String get validationFieldLearnVocabulary;

  /// No description provided for @validationFieldLearnGrammar.
  ///
  /// In en, this message translates to:
  /// **'Grammar'**
  String get validationFieldLearnGrammar;

  /// No description provided for @validationFieldLearnQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get validationFieldLearnQuiz;

  /// No description provided for @validationFieldModuleVocabularyKanji.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary / Kanji module'**
  String get validationFieldModuleVocabularyKanji;

  /// No description provided for @validationFieldModuleGrammar.
  ///
  /// In en, this message translates to:
  /// **'Grammar module'**
  String get validationFieldModuleGrammar;

  /// No description provided for @validationFieldModuleQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz module'**
  String get validationFieldModuleQuiz;

  /// No description provided for @validationFieldModuleAudio.
  ///
  /// In en, this message translates to:
  /// **'Listening module'**
  String get validationFieldModuleAudio;

  /// No description provided for @validationFieldLearnModule.
  ///
  /// In en, this message translates to:
  /// **'Learn module'**
  String get validationFieldLearnModule;

  /// No description provided for @validationLearnModuleNotCompletedWithLabel.
  ///
  /// In en, this message translates to:
  /// **'Complete the {moduleLabel} module before publishing.'**
  String validationLearnModuleNotCompletedWithLabel(String moduleLabel);

  /// No description provided for @validationLearnModuleLabelLearn.
  ///
  /// In en, this message translates to:
  /// **'learn'**
  String get validationLearnModuleLabelLearn;

  /// No description provided for @validationLearnModuleLabelVocabularyKanji.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary / Kanji'**
  String get validationLearnModuleLabelVocabularyKanji;

  /// No description provided for @validationLearnModuleLabelGrammar.
  ///
  /// In en, this message translates to:
  /// **'Grammar'**
  String get validationLearnModuleLabelGrammar;

  /// No description provided for @validationLearnModuleLabelQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get validationLearnModuleLabelQuiz;

  /// No description provided for @validationLearnModuleLabelAudio.
  ///
  /// In en, this message translates to:
  /// **'Listening / Audio'**
  String get validationLearnModuleLabelAudio;

  /// No description provided for @validationLearnFuriganaInvalid.
  ///
  /// In en, this message translates to:
  /// **'Furigana for this text is not valid.'**
  String get validationLearnFuriganaInvalid;

  /// No description provided for @validationLearnFuriganaOverlap.
  ///
  /// In en, this message translates to:
  /// **'Furigana ranges cannot overlap.'**
  String get validationLearnFuriganaOverlap;

  /// No description provided for @validationProfileDisplayNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a display name.'**
  String get validationProfileDisplayNameRequired;

  /// No description provided for @validationProfileDisplayNameLength.
  ///
  /// In en, this message translates to:
  /// **'Display name must be between 1 and 30 characters.'**
  String get validationProfileDisplayNameLength;

  /// No description provided for @validationProfileDisplayNameUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Display name contains content that is not allowed.'**
  String get validationProfileDisplayNameUnsafe;

  /// No description provided for @validationProfileHandleNoEmoji.
  ///
  /// In en, this message translates to:
  /// **'Handles cannot include emoji.'**
  String get validationProfileHandleNoEmoji;

  /// No description provided for @validationProfileHandleLength.
  ///
  /// In en, this message translates to:
  /// **'Handle must be between 3 and 24 characters.'**
  String get validationProfileHandleLength;

  /// No description provided for @validationProfileHandleInvalidChars.
  ///
  /// In en, this message translates to:
  /// **'Handles may use lowercase letters, numbers, underscore, and period only.'**
  String get validationProfileHandleInvalidChars;

  /// No description provided for @validationProfileHandlePeriodEdge.
  ///
  /// In en, this message translates to:
  /// **'Handles cannot start or end with a period.'**
  String get validationProfileHandlePeriodEdge;

  /// No description provided for @validationProfileHandlePeriodRepeat.
  ///
  /// In en, this message translates to:
  /// **'Handles cannot contain consecutive periods.'**
  String get validationProfileHandlePeriodRepeat;

  /// No description provided for @validationProfileHandleReserved.
  ///
  /// In en, this message translates to:
  /// **'That handle is reserved.'**
  String get validationProfileHandleReserved;

  /// No description provided for @validationProfileBioTooLong.
  ///
  /// In en, this message translates to:
  /// **'Bio must be at most 150 characters.'**
  String get validationProfileBioTooLong;

  /// No description provided for @validationProfileBioUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Bio contains content that is not allowed.'**
  String get validationProfileBioUnsafe;

  /// No description provided for @validationProfileBioTooManyLines.
  ///
  /// In en, this message translates to:
  /// **'Bio may have at most 3 lines.'**
  String get validationProfileBioTooManyLines;

  /// No description provided for @validationStoryTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required to publish.'**
  String get validationStoryTitleRequired;

  /// No description provided for @validationStoryTitleRecommended.
  ///
  /// In en, this message translates to:
  /// **'Add a title for your story.'**
  String get validationStoryTitleRecommended;

  /// No description provided for @validationStoryTitleTooShort.
  ///
  /// In en, this message translates to:
  /// **'Title must be at least 5 characters.'**
  String get validationStoryTitleTooShort;

  /// No description provided for @validationStoryTitleTooLong.
  ///
  /// In en, this message translates to:
  /// **'Title must be at most 80 characters.'**
  String get validationStoryTitleTooLong;

  /// No description provided for @validationStoryTitleUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Title contains content that is not allowed.'**
  String get validationStoryTitleUnsafe;

  /// No description provided for @validationStoryTitleLineBreak.
  ///
  /// In en, this message translates to:
  /// **'Title cannot contain line breaks.'**
  String get validationStoryTitleLineBreak;

  /// No description provided for @validationStoryTitleTooManyEmoji.
  ///
  /// In en, this message translates to:
  /// **'Title may include at most one emoji.'**
  String get validationStoryTitleTooManyEmoji;

  /// No description provided for @validationStoryTitleOnlyNumbers.
  ///
  /// In en, this message translates to:
  /// **'Title cannot be only numbers.'**
  String get validationStoryTitleOnlyNumbers;

  /// No description provided for @validationStoryTitleOnlySymbols.
  ///
  /// In en, this message translates to:
  /// **'Title cannot be only symbols.'**
  String get validationStoryTitleOnlySymbols;

  /// No description provided for @validationStoryTitleExcessiveRepeat.
  ///
  /// In en, this message translates to:
  /// **'Title has too many repeated characters.'**
  String get validationStoryTitleExcessiveRepeat;

  /// No description provided for @validationStoryDescriptionRecommended.
  ///
  /// In en, this message translates to:
  /// **'Add a short description before publishing.'**
  String get validationStoryDescriptionRecommended;

  /// No description provided for @validationStoryDescriptionTooLong.
  ///
  /// In en, this message translates to:
  /// **'Description must be at most 160 characters.'**
  String get validationStoryDescriptionTooLong;

  /// No description provided for @validationStoryDescriptionUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Description contains content that is not allowed.'**
  String get validationStoryDescriptionUnsafe;

  /// No description provided for @validationStoryDescriptionLineBreak.
  ///
  /// In en, this message translates to:
  /// **'Description cannot contain line breaks.'**
  String get validationStoryDescriptionLineBreak;

  /// No description provided for @validationStoryDescriptionTooManyUrls.
  ///
  /// In en, this message translates to:
  /// **'Description may include at most one link.'**
  String get validationStoryDescriptionTooManyUrls;

  /// No description provided for @validationStoryDescriptionHashtagStuffing.
  ///
  /// In en, this message translates to:
  /// **'Too many hashtags in the description.'**
  String get validationStoryDescriptionHashtagStuffing;

  /// No description provided for @validationStoryDescriptionTooManyEmoji.
  ///
  /// In en, this message translates to:
  /// **'Description may include at most two emoji.'**
  String get validationStoryDescriptionTooManyEmoji;

  /// No description provided for @validationStoryDescriptionExcessiveRepeat.
  ///
  /// In en, this message translates to:
  /// **'Description has too many repeated characters.'**
  String get validationStoryDescriptionExcessiveRepeat;

  /// No description provided for @validationCollectionTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Collection name is required.'**
  String get validationCollectionTitleRequired;

  /// No description provided for @validationCollectionTitleLength.
  ///
  /// In en, this message translates to:
  /// **'Collection name must be between 1 and 40 characters.'**
  String get validationCollectionTitleLength;

  /// No description provided for @validationCollectionTitleUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Collection name contains content that is not allowed.'**
  String get validationCollectionTitleUnsafe;

  /// No description provided for @validationCollectionTitleLineBreak.
  ///
  /// In en, this message translates to:
  /// **'Collection name cannot contain line breaks.'**
  String get validationCollectionTitleLineBreak;

  /// No description provided for @validationCollectionTitleNoUrl.
  ///
  /// In en, this message translates to:
  /// **'Collection name cannot contain links.'**
  String get validationCollectionTitleNoUrl;

  /// No description provided for @validationCollectionTitleTooManyEmoji.
  ///
  /// In en, this message translates to:
  /// **'Collection name may include at most one emoji.'**
  String get validationCollectionTitleTooManyEmoji;

  /// No description provided for @validationCollectionTitleOnlyNumbers.
  ///
  /// In en, this message translates to:
  /// **'Collection name cannot be only numbers.'**
  String get validationCollectionTitleOnlyNumbers;

  /// No description provided for @validationCollectionTitleOnlySymbols.
  ///
  /// In en, this message translates to:
  /// **'Collection name cannot be only symbols.'**
  String get validationCollectionTitleOnlySymbols;

  /// No description provided for @validationCollectionTitleOnlySpaces.
  ///
  /// In en, this message translates to:
  /// **'Collection name needs letters or numbers.'**
  String get validationCollectionTitleOnlySpaces;

  /// No description provided for @validationCollectionTitleExcessiveRepeat.
  ///
  /// In en, this message translates to:
  /// **'Collection name has too many repeated characters.'**
  String get validationCollectionTitleExcessiveRepeat;

  /// No description provided for @validationCollectionNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Collection name is required.'**
  String get validationCollectionNameRequired;

  /// No description provided for @validationCollectionNameLength.
  ///
  /// In en, this message translates to:
  /// **'Collection name must be between 1 and 40 characters.'**
  String get validationCollectionNameLength;

  /// No description provided for @validationCollectionNameUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Collection name contains content that is not allowed.'**
  String get validationCollectionNameUnsafe;

  /// No description provided for @validationCollectionNameLineBreak.
  ///
  /// In en, this message translates to:
  /// **'Collection name cannot contain line breaks.'**
  String get validationCollectionNameLineBreak;

  /// No description provided for @validationCollectionNameNoUrl.
  ///
  /// In en, this message translates to:
  /// **'Collection name cannot contain links.'**
  String get validationCollectionNameNoUrl;

  /// No description provided for @validationCollectionNameTooManyEmoji.
  ///
  /// In en, this message translates to:
  /// **'Collection name may include at most one emoji.'**
  String get validationCollectionNameTooManyEmoji;

  /// No description provided for @validationCollectionNameOnlyNumbers.
  ///
  /// In en, this message translates to:
  /// **'Collection name cannot be only numbers.'**
  String get validationCollectionNameOnlyNumbers;

  /// No description provided for @validationCollectionNameOnlySymbols.
  ///
  /// In en, this message translates to:
  /// **'Collection name cannot be only symbols.'**
  String get validationCollectionNameOnlySymbols;

  /// No description provided for @validationCollectionNameOnlySpaces.
  ///
  /// In en, this message translates to:
  /// **'Collection name needs letters or numbers.'**
  String get validationCollectionNameOnlySpaces;

  /// No description provided for @validationCollectionNameExcessiveRepeat.
  ///
  /// In en, this message translates to:
  /// **'Collection name has too many repeated characters.'**
  String get validationCollectionNameExcessiveRepeat;

  /// No description provided for @validationAuthEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required.'**
  String get validationAuthEmailRequired;

  /// No description provided for @validationAuthEmailLength.
  ///
  /// In en, this message translates to:
  /// **'Email must be between 5 and 254 characters.'**
  String get validationAuthEmailLength;

  /// No description provided for @validationAuthEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get validationAuthEmailInvalid;

  /// No description provided for @validationAuthEmailUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Email contains content that is not allowed.'**
  String get validationAuthEmailUnsafe;

  /// No description provided for @validationAuthPasswordLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be between 8 and 64 characters.'**
  String get validationAuthPasswordLength;

  /// No description provided for @validationAuthPasswordWeak.
  ///
  /// In en, this message translates to:
  /// **'That password is too common. Choose a stronger one.'**
  String get validationAuthPasswordWeak;

  /// No description provided for @validationAuthPasswordLineBreak.
  ///
  /// In en, this message translates to:
  /// **'Password cannot contain line breaks.'**
  String get validationAuthPasswordLineBreak;

  /// No description provided for @validationAuthPasswordRequiredLogin.
  ///
  /// In en, this message translates to:
  /// **'Password is required.'**
  String get validationAuthPasswordRequiredLogin;

  /// No description provided for @validationAuthConfirmPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get validationAuthConfirmPasswordMismatch;

  /// No description provided for @validationAuthLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect.'**
  String get validationAuthLoginFailed;

  /// No description provided for @validationLearnVocabMeaningRequired.
  ///
  /// In en, this message translates to:
  /// **'Meaning is required for this publish mode.'**
  String get validationLearnVocabMeaningRequired;

  /// No description provided for @validationLearnVocabMeaningLength.
  ///
  /// In en, this message translates to:
  /// **'Meaning must be between 1 and 80 characters.'**
  String get validationLearnVocabMeaningLength;

  /// No description provided for @validationLearnVocabMeaningNoEmoji.
  ///
  /// In en, this message translates to:
  /// **'Meaning cannot include emoji.'**
  String get validationLearnVocabMeaningNoEmoji;

  /// No description provided for @validationLearnVocabMeaningLineBreak.
  ///
  /// In en, this message translates to:
  /// **'Meaning cannot contain line breaks.'**
  String get validationLearnVocabMeaningLineBreak;

  /// No description provided for @validationLearnVocabMeaningUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Meaning contains content that is not allowed.'**
  String get validationLearnVocabMeaningUnsafe;

  /// No description provided for @validationLearnVocabMeaningNoUrl.
  ///
  /// In en, this message translates to:
  /// **'Meaning cannot contain links.'**
  String get validationLearnVocabMeaningNoUrl;

  /// No description provided for @validationLearnVocabMeaningNoHashtag.
  ///
  /// In en, this message translates to:
  /// **'Meaning cannot contain hashtags.'**
  String get validationLearnVocabMeaningNoHashtag;

  /// No description provided for @validationLearnVocabReadingRequired.
  ///
  /// In en, this message translates to:
  /// **'Reading is required for this word.'**
  String get validationLearnVocabReadingRequired;

  /// No description provided for @validationLearnVocabReadingTooLong.
  ///
  /// In en, this message translates to:
  /// **'Reading must be at most 40 characters.'**
  String get validationLearnVocabReadingTooLong;

  /// No description provided for @validationLearnVocabReadingTooManyAlternatives.
  ///
  /// In en, this message translates to:
  /// **'Too many alternative readings.'**
  String get validationLearnVocabReadingTooManyAlternatives;

  /// No description provided for @validationLearnVocabReadingInvalidChars.
  ///
  /// In en, this message translates to:
  /// **'Reading may use hiragana, katakana, ・ and / only.'**
  String get validationLearnVocabReadingInvalidChars;

  /// No description provided for @validationLearnVocabReadingUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Reading contains content that is not allowed.'**
  String get validationLearnVocabReadingUnsafe;

  /// No description provided for @validationLearnGrammarTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Grammar title is required.'**
  String get validationLearnGrammarTitleRequired;

  /// No description provided for @validationLearnGrammarTitleLength.
  ///
  /// In en, this message translates to:
  /// **'Grammar title must be between 2 and 40 characters.'**
  String get validationLearnGrammarTitleLength;

  /// No description provided for @validationLearnGrammarTitleNoEmoji.
  ///
  /// In en, this message translates to:
  /// **'Grammar title cannot include emoji.'**
  String get validationLearnGrammarTitleNoEmoji;

  /// No description provided for @validationLearnGrammarTitleLineBreak.
  ///
  /// In en, this message translates to:
  /// **'Grammar title cannot contain line breaks.'**
  String get validationLearnGrammarTitleLineBreak;

  /// No description provided for @validationLearnGrammarTitleUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Grammar title contains content that is not allowed.'**
  String get validationLearnGrammarTitleUnsafe;

  /// No description provided for @validationLearnGrammarTitleNoUrl.
  ///
  /// In en, this message translates to:
  /// **'Grammar title cannot contain links.'**
  String get validationLearnGrammarTitleNoUrl;

  /// No description provided for @validationLearnQuizCategoryInvalid.
  ///
  /// In en, this message translates to:
  /// **'Choose a quiz category.'**
  String get validationLearnQuizCategoryInvalid;

  /// No description provided for @validationLearnQuizQuestionRequired.
  ///
  /// In en, this message translates to:
  /// **'Question is required.'**
  String get validationLearnQuizQuestionRequired;

  /// No description provided for @validationLearnQuizQuestionLength.
  ///
  /// In en, this message translates to:
  /// **'Question must be between 5 and 120 characters.'**
  String get validationLearnQuizQuestionLength;

  /// No description provided for @validationLearnQuizQuestionUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Question contains content that is not allowed.'**
  String get validationLearnQuizQuestionUnsafe;

  /// No description provided for @validationLearnQuizQuestionDuplicate.
  ///
  /// In en, this message translates to:
  /// **'That question is already in this story.'**
  String get validationLearnQuizQuestionDuplicate;

  /// No description provided for @validationLearnQuizOptionsCount.
  ///
  /// In en, this message translates to:
  /// **'Provide between 2 and 4 answer options.'**
  String get validationLearnQuizOptionsCount;

  /// No description provided for @validationLearnQuizOptionsDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Answer options must be unique.'**
  String get validationLearnQuizOptionsDuplicate;

  /// No description provided for @validationLearnQuizAnswerRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the correct answer.'**
  String get validationLearnQuizAnswerRequired;

  /// No description provided for @validationLearnQuizAnswerNotInOptions.
  ///
  /// In en, this message translates to:
  /// **'Correct answer must match one of the options.'**
  String get validationLearnQuizAnswerNotInOptions;

  /// No description provided for @validationLearnQuizAnswerSingleCorrect.
  ///
  /// In en, this message translates to:
  /// **'Exactly one option must be marked correct.'**
  String get validationLearnQuizAnswerSingleCorrect;

  /// No description provided for @validationStorySentencesRequired.
  ///
  /// In en, this message translates to:
  /// **'Add at least one Japanese sentence.'**
  String get validationStorySentencesRequired;

  /// No description provided for @validationStorySentencesTooFew.
  ///
  /// In en, this message translates to:
  /// **'Not enough sentences for this level and duration (minimum {min}; you have {actual}).'**
  String validationStorySentencesTooFew(int min, int actual);

  /// No description provided for @validationStorySentencesTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many sentences for this level and duration (maximum {max}; you have {actual}).'**
  String validationStorySentencesTooMany(int max, int actual);

  /// No description provided for @validationStoryBodyTooLong.
  ///
  /// In en, this message translates to:
  /// **'Story text is too long (maximum {max} characters; you have {actual}).'**
  String validationStoryBodyTooLong(int max, int actual);

  /// No description provided for @validationStoryLimitsSkippedNoJlpt.
  ///
  /// In en, this message translates to:
  /// **'JLPT level is not set; sentence length limits were not applied.'**
  String get validationStoryLimitsSkippedNoJlpt;

  /// No description provided for @validationStoryLimitsSkippedNoBand.
  ///
  /// In en, this message translates to:
  /// **'Duration band is not set; sentence length limits were not applied.'**
  String get validationStoryLimitsSkippedNoBand;

  /// No description provided for @validationLearnCountVocabRange.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary count must be between {min} and {max} (you have {actual}).'**
  String validationLearnCountVocabRange(int min, int max, int actual);

  /// No description provided for @validationLearnCountGrammarRange.
  ///
  /// In en, this message translates to:
  /// **'Grammar count must be between {min} and {max} (you have {actual}).'**
  String validationLearnCountGrammarRange(int min, int max, int actual);

  /// No description provided for @validationLearnCountQuizRange.
  ///
  /// In en, this message translates to:
  /// **'Quiz count must be between {min} and {max} (you have {actual}).'**
  String validationLearnCountQuizRange(int min, int max, int actual);

  /// No description provided for @validationProtectedReactLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in to react to stories.'**
  String get validationProtectedReactLogin;

  /// No description provided for @validationProtectedFollowLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in to follow creators.'**
  String get validationProtectedFollowLogin;

  /// No description provided for @validationProtectedSaveLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save stories.'**
  String get validationProtectedSaveLogin;

  /// No description provided for @validationProtectedCreateStoryLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in to create and publish Monos.'**
  String get validationProtectedCreateStoryLogin;

  /// No description provided for @validationProtectedPublishStoryLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in to publish your story.'**
  String get validationProtectedPublishStoryLogin;

  /// No description provided for @validationProtectedCreateCollectionLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in to create collections.'**
  String get validationProtectedCreateCollectionLogin;

  /// No description provided for @validationProtectedUploadMediaLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in to upload media.'**
  String get validationProtectedUploadMediaLogin;

  /// No description provided for @validationProtectedEditProfileLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view and manage your profile.'**
  String get validationProtectedEditProfileLogin;

  /// No description provided for @validationProtectedGenericForbidden.
  ///
  /// In en, this message translates to:
  /// **'This action is not available.'**
  String get validationProtectedGenericForbidden;

  /// No description provided for @validationProtectedGenericDisabled.
  ///
  /// In en, this message translates to:
  /// **'This action is disabled for your account.'**
  String get validationProtectedGenericDisabled;

  /// No description provided for @validationMediaFileRequired.
  ///
  /// In en, this message translates to:
  /// **'Please choose a file to upload.'**
  String get validationMediaFileRequired;

  /// No description provided for @validationMediaFileEmpty.
  ///
  /// In en, this message translates to:
  /// **'This file is empty. Please choose another file.'**
  String get validationMediaFileEmpty;

  /// No description provided for @validationMediaFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is too large.'**
  String get validationMediaFileTooLarge;

  /// No description provided for @validationMediaFileInvalidType.
  ///
  /// In en, this message translates to:
  /// **'This file type is not supported.'**
  String get validationMediaFileInvalidType;

  /// No description provided for @validationMediaFileInvalidExtension.
  ///
  /// In en, this message translates to:
  /// **'This file extension is not supported.'**
  String get validationMediaFileInvalidExtension;

  /// No description provided for @validationMediaFileInvalidField.
  ///
  /// In en, this message translates to:
  /// **'Upload request was missing a required field.'**
  String get validationMediaFileInvalidField;

  /// No description provided for @validationMediaImageInvalidType.
  ///
  /// In en, this message translates to:
  /// **'Please choose a JPG, PNG, or WebP image.'**
  String get validationMediaImageInvalidType;

  /// No description provided for @validationMediaImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This image is too large.'**
  String get validationMediaImageTooLarge;

  /// No description provided for @validationMediaAudioInvalidType.
  ///
  /// In en, this message translates to:
  /// **'Please choose a supported audio file.'**
  String get validationMediaAudioInvalidType;

  /// No description provided for @validationMediaAudioTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This audio file is too large.'**
  String get validationMediaAudioTooLarge;

  /// No description provided for @validationNetworkOffline.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check your network and try again.'**
  String get validationNetworkOffline;

  /// No description provided for @quotaDialogOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get quotaDialogOk;

  /// No description provided for @quotaPremiumComingLaterCta.
  ///
  /// In en, this message translates to:
  /// **'Premium later'**
  String get quotaPremiumComingLaterCta;

  /// No description provided for @quotaUnknownLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Free limit reached'**
  String get quotaUnknownLimitTitle;

  /// No description provided for @quotaUnknownLimitMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached a free plan limit. Please remove an older item and try again.'**
  String get quotaUnknownLimitMessage;

  /// No description provided for @publishedMonoLimitReachedTitle.
  ///
  /// In en, this message translates to:
  /// **'Free limit reached'**
  String get publishedMonoLimitReachedTitle;

  /// No description provided for @publishedMonoLimitReachedMessage.
  ///
  /// In en, this message translates to:
  /// **'You can publish up to {limit} Monos on the free plan. Remove an old Mono or upgrade when Premium becomes available.'**
  String publishedMonoLimitReachedMessage(int limit);

  /// No description provided for @savedMonoLimitReachedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved limit reached'**
  String get savedMonoLimitReachedTitle;

  /// No description provided for @savedMonoLimitReachedMessage.
  ///
  /// In en, this message translates to:
  /// **'You can save up to {limit} Monos on the free plan. Remove a saved Mono before saving a new one.'**
  String savedMonoLimitReachedMessage(int limit);

  /// No description provided for @collectionLimitReachedTitle.
  ///
  /// In en, this message translates to:
  /// **'Collection limit reached'**
  String get collectionLimitReachedTitle;

  /// No description provided for @collectionLimitReachedMessage.
  ///
  /// In en, this message translates to:
  /// **'You can create up to {limit} collections on the free plan. Premium collections are coming in V2.'**
  String collectionLimitReachedMessage(int limit);

  /// No description provided for @collectionItemLimitReachedTitle.
  ///
  /// In en, this message translates to:
  /// **'Collection is full'**
  String get collectionItemLimitReachedTitle;

  /// No description provided for @collectionItemLimitReachedMessage.
  ///
  /// In en, this message translates to:
  /// **'A collection can contain up to {limit} Monos on the free plan. Remove an item before adding another.'**
  String collectionItemLimitReachedMessage(int limit);

  /// No description provided for @draftStoryLimitReachedTitle.
  ///
  /// In en, this message translates to:
  /// **'Draft limit reached'**
  String get draftStoryLimitReachedTitle;

  /// No description provided for @draftStoryLimitReachedMessage.
  ///
  /// In en, this message translates to:
  /// **'You can keep up to {limit} drafts on the free plan. Delete an old draft before creating a new one.'**
  String draftStoryLimitReachedMessage(int limit);

  /// No description provided for @monoFollowingGuestTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see Following'**
  String get monoFollowingGuestTitle;

  /// No description provided for @monoFollowingGuestBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see stories from people you follow.'**
  String get monoFollowingGuestBody;

  /// No description provided for @monoGuestRemoteDraftsBanner.
  ///
  /// In en, this message translates to:
  /// **'Remote drafts require sign-in.'**
  String get monoGuestRemoteDraftsBanner;

  /// No description provided for @learnPackageManualBadge.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get learnPackageManualBadge;

  /// No description provided for @learnPackageCreatorMadeBadge.
  ///
  /// In en, this message translates to:
  /// **'Creator-made'**
  String get learnPackageCreatorMadeBadge;

  /// No description provided for @shareProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Share Profile'**
  String get shareProfileTitle;

  /// No description provided for @shareProfileCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get shareProfileCopyLink;

  /// No description provided for @shareProfileShareProfile.
  ///
  /// In en, this message translates to:
  /// **'Share profile'**
  String get shareProfileShareProfile;

  /// No description provided for @shareProfileLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get shareProfileLinkCopied;

  /// No description provided for @shareProfileScanToOpen.
  ///
  /// In en, this message translates to:
  /// **'Scan to open profile'**
  String get shareProfileScanToOpen;

  /// No description provided for @shareProfilePublicHint.
  ///
  /// In en, this message translates to:
  /// **'Anyone with this link can view your public profile.'**
  String get shareProfilePublicHint;

  /// No description provided for @shareProfileLinkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Profile link is not available on this device yet.'**
  String get shareProfileLinkUnavailable;

  /// No description provided for @shareProfileFallbackDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get shareProfileFallbackDisplayName;
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
      <String>['en', 'ja', 'my'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'my':
      return AppLocalizationsMy();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
