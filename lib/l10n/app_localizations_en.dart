// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguageSection => 'Language';

  @override
  String get settingsAppearanceSection => 'Appearance';

  @override
  String get settingsAccountSection => 'Account';

  @override
  String get settingsNotificationsSection => 'Notifications';

  @override
  String get settingsAboutSection => 'About';

  @override
  String get settingsAppLanguage => 'App Language';

  @override
  String get settingsContentCommunity => 'Content Community';

  @override
  String get settingsLearningLanguage => 'Learning Language';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsComingSoon => 'Coming soon';

  @override
  String get settingsEditProfile => 'Edit profile';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsSignOutSubtitle => 'Leave this account on this device';

  @override
  String get settingsSignInRequiredTitle => 'Sign in required';

  @override
  String get settingsSignInRequiredBody =>
      'Settings are available after you sign in.';

  @override
  String get settingsSignInCta => 'Sign in';

  @override
  String get settingsAppVersion => 'App version';

  @override
  String get settingsAppVersionPlaceholder =>
      'V1 shell (version integration deferred)';

  @override
  String get settingsSystem => 'System';

  @override
  String get settingsEnglish => 'English';

  @override
  String get settingsJapanese => 'Japanese';

  @override
  String get settingsMyanmar => 'Myanmar';

  @override
  String get settingsInternationalEnglish => 'International / English';

  @override
  String get settingsSignOutDialogTitle => 'Sign out?';

  @override
  String get settingsSignOutDialogBody =>
      'You will be signed out on this device and returned to the login screen.';

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsReadingSection => 'Reading';

  @override
  String get settingsReadingTextSize => 'Reading text size';

  @override
  String get settingsReadingTextSizeSmall => 'Small';

  @override
  String get settingsReadingTextSizeStandard => 'Standard';

  @override
  String get settingsReadingTextSizeLarge => 'Large';

  @override
  String get settingsShowExplanationSentence => 'Explanation sentence';

  @override
  String get settingsShowExplanationSentenceSubtitle =>
      'Show per-sentence explanations in the mono reader';

  @override
  String get validationPublishSheetTitle => 'Before publishing';

  @override
  String get validationPublishSectionBlocking => 'Blocking';

  @override
  String get validationPublishSectionRecommended => 'Recommended';

  @override
  String get validationPublishFixIssuesCta => 'Fix issues';

  @override
  String get validationPublishAnywayCta => 'Publish anyway';

  @override
  String get validationCtaSignIn => 'Sign in';

  @override
  String get validationCtaNotNow => 'Not now';

  @override
  String get validationCtaOk => 'OK';

  @override
  String get validationMediaUploadGenericImage =>
      'Could not upload image. Please try again.';

  @override
  String get validationMediaUploadGenericAudio =>
      'Could not upload audio. Please try again.';

  @override
  String get validationFieldStoryTitle => 'Story title';

  @override
  String get validationFieldStoryDescription => 'Description';

  @override
  String get validationFieldStorySentences => 'Sentences';

  @override
  String get validationFieldStoryBody => 'Story body';

  @override
  String get validationFieldStoryLevel => 'JLPT level';

  @override
  String get validationFieldStoryDuration => 'Duration';

  @override
  String get validationFieldLearnVocabCount => 'Vocabulary';

  @override
  String get validationFieldLearnGrammarCount => 'Grammar';

  @override
  String get validationFieldLearnQuizCount => 'Quiz';

  @override
  String get validationFieldLearnVocabulary => 'Vocabulary';

  @override
  String get validationFieldLearnGrammar => 'Grammar';

  @override
  String get validationFieldLearnQuiz => 'Quiz';

  @override
  String get validationFieldModuleVocabularyKanji =>
      'Vocabulary / Kanji module';

  @override
  String get validationFieldModuleGrammar => 'Grammar module';

  @override
  String get validationFieldModuleQuiz => 'Quiz module';

  @override
  String get validationFieldModuleAudio => 'Listening module';

  @override
  String get validationFieldLearnModule => 'Learn module';

  @override
  String validationLearnModuleNotCompletedWithLabel(String moduleLabel) {
    return 'Complete the $moduleLabel module before publishing.';
  }

  @override
  String get validationLearnModuleLabelLearn => 'learn';

  @override
  String get validationLearnModuleLabelVocabularyKanji => 'Vocabulary / Kanji';

  @override
  String get validationLearnModuleLabelGrammar => 'Grammar';

  @override
  String get validationLearnModuleLabelQuiz => 'Quiz';

  @override
  String get validationLearnModuleLabelAudio => 'Listening / Audio';

  @override
  String get validationLearnFuriganaInvalid =>
      'Furigana for this text is not valid.';

  @override
  String get validationLearnFuriganaOverlap =>
      'Furigana ranges cannot overlap.';

  @override
  String get validationProfileDisplayNameRequired => 'Enter a display name.';

  @override
  String get validationProfileDisplayNameLength =>
      'Display name must be between 1 and 30 characters.';

  @override
  String get validationProfileDisplayNameUnsafe =>
      'Display name contains content that is not allowed.';

  @override
  String get validationProfileHandleNoEmoji => 'Handles cannot include emoji.';

  @override
  String get validationProfileHandleLength =>
      'Handle must be between 3 and 24 characters.';

  @override
  String get validationProfileHandleInvalidChars =>
      'Handles may use lowercase letters, numbers, underscore, and period only.';

  @override
  String get validationProfileHandlePeriodEdge =>
      'Handles cannot start or end with a period.';

  @override
  String get validationProfileHandlePeriodRepeat =>
      'Handles cannot contain consecutive periods.';

  @override
  String get validationProfileHandleReserved => 'That handle is reserved.';

  @override
  String get validationProfileBioTooLong =>
      'Bio must be at most 150 characters.';

  @override
  String get validationProfileBioUnsafe =>
      'Bio contains content that is not allowed.';

  @override
  String get validationProfileBioTooManyLines =>
      'Bio may have at most 3 lines.';

  @override
  String get validationStoryTitleRequired => 'Title is required to publish.';

  @override
  String get validationStoryTitleRecommended => 'Add a title for your story.';

  @override
  String get validationStoryTitleTooShort =>
      'Title must be at least 5 characters.';

  @override
  String get validationStoryTitleTooLong =>
      'Title must be at most 80 characters.';

  @override
  String get validationStoryTitleUnsafe =>
      'Title contains content that is not allowed.';

  @override
  String get validationStoryTitleLineBreak =>
      'Title cannot contain line breaks.';

  @override
  String get validationStoryTitleTooManyEmoji =>
      'Title may include at most one emoji.';

  @override
  String get validationStoryTitleOnlyNumbers => 'Title cannot be only numbers.';

  @override
  String get validationStoryTitleOnlySymbols => 'Title cannot be only symbols.';

  @override
  String get validationStoryTitleExcessiveRepeat =>
      'Title has too many repeated characters.';

  @override
  String get validationStoryDescriptionRecommended =>
      'Add a short description before publishing.';

  @override
  String get validationStoryDescriptionTooLong =>
      'Description must be at most 160 characters.';

  @override
  String get validationStoryDescriptionUnsafe =>
      'Description contains content that is not allowed.';

  @override
  String get validationStoryDescriptionLineBreak =>
      'Description cannot contain line breaks.';

  @override
  String get validationStoryDescriptionTooManyUrls =>
      'Description may include at most one link.';

  @override
  String get validationStoryDescriptionHashtagStuffing =>
      'Too many hashtags in the description.';

  @override
  String get validationStoryDescriptionTooManyEmoji =>
      'Description may include at most two emoji.';

  @override
  String get validationStoryDescriptionExcessiveRepeat =>
      'Description has too many repeated characters.';

  @override
  String get validationCollectionTitleRequired =>
      'Collection name is required.';

  @override
  String get validationCollectionTitleLength =>
      'Collection name must be between 1 and 40 characters.';

  @override
  String get validationCollectionTitleUnsafe =>
      'Collection name contains content that is not allowed.';

  @override
  String get validationCollectionTitleLineBreak =>
      'Collection name cannot contain line breaks.';

  @override
  String get validationCollectionTitleNoUrl =>
      'Collection name cannot contain links.';

  @override
  String get validationCollectionTitleTooManyEmoji =>
      'Collection name may include at most one emoji.';

  @override
  String get validationCollectionTitleOnlyNumbers =>
      'Collection name cannot be only numbers.';

  @override
  String get validationCollectionTitleOnlySymbols =>
      'Collection name cannot be only symbols.';

  @override
  String get validationCollectionTitleOnlySpaces =>
      'Collection name needs letters or numbers.';

  @override
  String get validationCollectionTitleExcessiveRepeat =>
      'Collection name has too many repeated characters.';

  @override
  String get validationCollectionNameRequired => 'Collection name is required.';

  @override
  String get validationCollectionNameLength =>
      'Collection name must be between 1 and 40 characters.';

  @override
  String get validationCollectionNameUnsafe =>
      'Collection name contains content that is not allowed.';

  @override
  String get validationCollectionNameLineBreak =>
      'Collection name cannot contain line breaks.';

  @override
  String get validationCollectionNameNoUrl =>
      'Collection name cannot contain links.';

  @override
  String get validationCollectionNameTooManyEmoji =>
      'Collection name may include at most one emoji.';

  @override
  String get validationCollectionNameOnlyNumbers =>
      'Collection name cannot be only numbers.';

  @override
  String get validationCollectionNameOnlySymbols =>
      'Collection name cannot be only symbols.';

  @override
  String get validationCollectionNameOnlySpaces =>
      'Collection name needs letters or numbers.';

  @override
  String get validationCollectionNameExcessiveRepeat =>
      'Collection name has too many repeated characters.';

  @override
  String get validationAuthEmailRequired => 'Email is required.';

  @override
  String get validationAuthEmailLength =>
      'Email must be between 5 and 254 characters.';

  @override
  String get validationAuthEmailInvalid => 'Enter a valid email address.';

  @override
  String get validationAuthEmailUnsafe =>
      'Email contains content that is not allowed.';

  @override
  String get validationAuthPasswordLength =>
      'Password must be between 8 and 64 characters.';

  @override
  String get validationAuthPasswordWeak =>
      'That password is too common. Choose a stronger one.';

  @override
  String get validationAuthPasswordLineBreak =>
      'Password cannot contain line breaks.';

  @override
  String get validationAuthPasswordRequiredLogin => 'Password is required.';

  @override
  String get validationAuthConfirmPasswordMismatch => 'Passwords do not match.';

  @override
  String get validationAuthLoginFailed => 'Email or password is incorrect.';

  @override
  String get validationLearnVocabMeaningRequired =>
      'Meaning is required for this publish mode.';

  @override
  String get validationLearnVocabMeaningLength =>
      'Meaning must be between 1 and 80 characters.';

  @override
  String get validationLearnVocabMeaningNoEmoji =>
      'Meaning cannot include emoji.';

  @override
  String get validationLearnVocabMeaningLineBreak =>
      'Meaning cannot contain line breaks.';

  @override
  String get validationLearnVocabMeaningUnsafe =>
      'Meaning contains content that is not allowed.';

  @override
  String get validationLearnVocabMeaningNoUrl =>
      'Meaning cannot contain links.';

  @override
  String get validationLearnVocabMeaningNoHashtag =>
      'Meaning cannot contain hashtags.';

  @override
  String get validationLearnVocabReadingRequired =>
      'Reading is required for this word.';

  @override
  String get validationLearnVocabReadingTooLong =>
      'Reading must be at most 40 characters.';

  @override
  String get validationLearnVocabReadingTooManyAlternatives =>
      'Too many alternative readings.';

  @override
  String get validationLearnVocabReadingInvalidChars =>
      'Reading may use hiragana, katakana, ・ and / only.';

  @override
  String get validationLearnVocabReadingUnsafe =>
      'Reading contains content that is not allowed.';

  @override
  String get validationLearnGrammarTitleRequired =>
      'Grammar title is required.';

  @override
  String get validationLearnGrammarTitleLength =>
      'Grammar title must be between 2 and 40 characters.';

  @override
  String get validationLearnGrammarTitleNoEmoji =>
      'Grammar title cannot include emoji.';

  @override
  String get validationLearnGrammarTitleLineBreak =>
      'Grammar title cannot contain line breaks.';

  @override
  String get validationLearnGrammarTitleUnsafe =>
      'Grammar title contains content that is not allowed.';

  @override
  String get validationLearnGrammarTitleNoUrl =>
      'Grammar title cannot contain links.';

  @override
  String get validationLearnQuizCategoryInvalid => 'Choose a quiz category.';

  @override
  String get validationLearnQuizQuestionRequired => 'Question is required.';

  @override
  String get validationLearnQuizQuestionLength =>
      'Question must be between 5 and 120 characters.';

  @override
  String get validationLearnQuizQuestionUnsafe =>
      'Question contains content that is not allowed.';

  @override
  String get validationLearnQuizQuestionDuplicate =>
      'That question is already in this story.';

  @override
  String get validationLearnQuizOptionsCount =>
      'Provide between 2 and 4 answer options.';

  @override
  String get validationLearnQuizOptionsDuplicate =>
      'Answer options must be unique.';

  @override
  String get validationLearnQuizAnswerRequired => 'Choose the correct answer.';

  @override
  String get validationLearnQuizAnswerNotInOptions =>
      'Correct answer must match one of the options.';

  @override
  String get validationLearnQuizAnswerSingleCorrect =>
      'Exactly one option must be marked correct.';

  @override
  String get validationStorySentencesRequired =>
      'Add at least one Japanese sentence.';

  @override
  String validationStorySentencesTooFew(int min, int actual) {
    return 'Not enough sentences for this level and duration (minimum $min; you have $actual).';
  }

  @override
  String validationStorySentencesTooMany(int max, int actual) {
    return 'Too many sentences for this level and duration (maximum $max; you have $actual).';
  }

  @override
  String validationStoryBodyTooLong(int max, int actual) {
    return 'Story text is too long (maximum $max characters; you have $actual).';
  }

  @override
  String get validationStoryLimitsSkippedNoJlpt =>
      'JLPT level is not set; sentence length limits were not applied.';

  @override
  String get validationStoryLimitsSkippedNoBand =>
      'Duration band is not set; sentence length limits were not applied.';

  @override
  String validationLearnCountVocabRange(int min, int max, int actual) {
    return 'Vocabulary count must be between $min and $max (you have $actual).';
  }

  @override
  String validationLearnCountGrammarRange(int min, int max, int actual) {
    return 'Grammar count must be between $min and $max (you have $actual).';
  }

  @override
  String validationLearnCountQuizRange(int min, int max, int actual) {
    return 'Quiz count must be between $min and $max (you have $actual).';
  }

  @override
  String get validationProtectedReactLogin => 'Sign in to react to stories.';

  @override
  String get validationProtectedFollowLogin => 'Sign in to follow creators.';

  @override
  String get validationProtectedSaveLogin => 'Sign in to save stories.';

  @override
  String get validationProtectedCreateStoryLogin =>
      'Sign in to create and publish Monos.';

  @override
  String get validationProtectedPublishStoryLogin =>
      'Sign in to publish your story.';

  @override
  String get validationProtectedCreateCollectionLogin =>
      'Sign in to create collections.';

  @override
  String get validationProtectedUploadMediaLogin => 'Sign in to upload media.';

  @override
  String get validationProtectedEditProfileLogin =>
      'Sign in to view and manage your profile.';

  @override
  String get validationProtectedGenericForbidden =>
      'This action is not available.';

  @override
  String get validationProtectedGenericDisabled =>
      'This action is disabled for your account.';

  @override
  String get validationMediaFileRequired => 'Please choose a file to upload.';

  @override
  String get validationMediaFileEmpty =>
      'This file is empty. Please choose another file.';

  @override
  String get validationMediaFileTooLarge => 'This file is too large.';

  @override
  String get validationMediaFileInvalidType =>
      'This file type is not supported.';

  @override
  String get validationMediaFileInvalidExtension =>
      'This file extension is not supported.';

  @override
  String get validationMediaFileInvalidField =>
      'Upload request was missing a required field.';

  @override
  String get validationMediaImageInvalidType =>
      'Please choose a JPG, PNG, or WebP image.';

  @override
  String get validationMediaImageTooLarge => 'This image is too large.';

  @override
  String get validationMediaAudioInvalidType =>
      'Please choose a supported audio file.';

  @override
  String get validationMediaAudioTooLarge => 'This audio file is too large.';

  @override
  String get validationNetworkOffline =>
      'No internet connection. Please check your network and try again.';

  @override
  String get quotaDialogOk => 'OK';

  @override
  String get quotaPremiumComingLaterCta => 'Premium later';

  @override
  String get quotaUnknownLimitTitle => 'Free limit reached';

  @override
  String get quotaUnknownLimitMessage =>
      'You\'ve reached a free plan limit. Please remove an older item and try again.';

  @override
  String get publishedMonoLimitReachedTitle => 'Free limit reached';

  @override
  String publishedMonoLimitReachedMessage(int limit) {
    return 'You can publish up to $limit Monos on the free plan. Remove an old Mono or upgrade when Premium becomes available.';
  }

  @override
  String get savedMonoLimitReachedTitle => 'Saved limit reached';

  @override
  String savedMonoLimitReachedMessage(int limit) {
    return 'You can save up to $limit Monos on the free plan. Remove a saved Mono before saving a new one.';
  }

  @override
  String get collectionLimitReachedTitle => 'Collection limit reached';

  @override
  String collectionLimitReachedMessage(int limit) {
    return 'You can create up to $limit collections on the free plan. Premium collections are coming in V2.';
  }

  @override
  String get collectionItemLimitReachedTitle => 'Collection is full';

  @override
  String collectionItemLimitReachedMessage(int limit) {
    return 'A collection can contain up to $limit Monos on the free plan. Remove an item before adding another.';
  }

  @override
  String get draftStoryLimitReachedTitle => 'Draft limit reached';

  @override
  String draftStoryLimitReachedMessage(int limit) {
    return 'You can keep up to $limit drafts on the free plan. Delete an old draft before creating a new one.';
  }

  @override
  String get monoFollowingGuestTitle => 'Sign in to see Following';

  @override
  String get monoFollowingGuestBody =>
      'Sign in to see stories from people you follow.';

  @override
  String get monoGuestRemoteDraftsBanner => 'Remote drafts require sign-in.';

  @override
  String get learnPackageManualBadge => 'Manual';

  @override
  String get learnPackageCreatorMadeBadge => 'Creator-made';

  @override
  String get shareProfileTitle => 'Share Profile';

  @override
  String get shareProfileCopyLink => 'Copy link';

  @override
  String get shareProfileShareProfile => 'Share profile';

  @override
  String get shareProfileLinkCopied => 'Link copied';

  @override
  String get shareProfileScanToOpen => 'Scan to open profile';

  @override
  String get shareProfilePublicHint =>
      'Anyone with this link can view your public profile.';

  @override
  String get shareProfileLinkUnavailable =>
      'Profile link is not available on this device yet.';

  @override
  String get shareProfileFallbackDisplayName => 'Creator';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchInputHint => 'Search Monos';

  @override
  String get searchInitialTitle => 'Search Monos';

  @override
  String get searchInitialBody =>
      'Find stories by title, topic, creator, level, or category.';

  @override
  String get searchNoResultsTitle => 'No results found';

  @override
  String get searchNoResultsBody => 'Try another keyword or filter.';

  @override
  String get searchRetry => 'Retry';

  @override
  String get searchAll => 'All';

  @override
  String get searchLatest => 'Latest';

  @override
  String get searchClearFiltersTooltip => 'Clear search and filters';

  @override
  String get searchErrorTitle => 'Could not search';

  @override
  String get searchLevelLabel => 'Level';

  @override
  String get searchCategoryLabel => 'Category';
}
