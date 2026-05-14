import 'package:flutter/widgets.dart';
import 'package:nimon/l10n/app_localizations.dart';
import 'package:nimon/core/validation/validation_fallback_messages.dart';
import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/core/validation/validation_severity.dart';

/// Final message shown for unknown validation keys when no English fallback exists.
const String validationUnknownFieldMessage = 'Please check this field.';

int _i(Object? o) {
  if (o == null) return 0;
  if (o is int) return o;
  return int.tryParse(o.toString()) ?? 0;
}

/// Localizes [ValidationIssue.messageKey] with optional [ValidationIssue.params].
String validationIssueDisplayMessageLocalized(
  BuildContext context,
  ValidationIssue issue,
) {
  if (issue.messageKey == 'learn.module.notCompleted') {
    final l10n = AppLocalizations.of(context);
    final k = issue.params?['module']?.toString() ?? '';
    final moduleLabel = learnModuleLabelLocalized(context, k);
    if (l10n != null) {
      return l10n.validationLearnModuleNotCompletedWithLabel(moduleLabel);
    }
    return validationIssueDisplayMessage(issue);
  }
  return validationMessageKeyLocalized(
    context,
    issue.messageKey,
    params: issue.params ?? const {},
  );
}

/// Maps stable module codes from validators to localized short labels.
String learnModuleLabelLocalized(BuildContext context, String moduleKey) {
  final l10n = AppLocalizations.of(context);
  if (l10n == null) {
    return switch (moduleKey) {
      'vocabulary_kanji' => 'Vocabulary / Kanji',
      'grammar' => 'Grammar',
      'quiz' => 'Quiz',
      'audio' => 'Listening / Audio',
      _ when moduleKey.isNotEmpty => moduleKey,
      _ => 'learn',
    };
  }
  return switch (moduleKey) {
    'vocabulary_kanji' => l10n.validationLearnModuleLabelVocabularyKanji,
    'grammar' => l10n.validationLearnModuleLabelGrammar,
    'quiz' => l10n.validationLearnModuleLabelQuiz,
    'audio' => l10n.validationLearnModuleLabelAudio,
    _ when moduleKey.isNotEmpty => moduleKey,
    _ => l10n.validationLearnModuleLabelLearn,
  };
}

/// Localized counterpart of [validationFieldLabelForPublish].
String validationFieldLabelLocalized(BuildContext context, String field) {
  final l10n = AppLocalizations.of(context);
  if (l10n == null) return validationFieldLabelForPublish(field);
  switch (field) {
    case 'story.title':
      return l10n.validationFieldStoryTitle;
    case 'story.description':
      return l10n.validationFieldStoryDescription;
    case 'story.sentences':
      return l10n.validationFieldStorySentences;
    case 'story.body':
      return l10n.validationFieldStoryBody;
    case 'story.level':
      return l10n.validationFieldStoryLevel;
    case 'story.duration':
      return l10n.validationFieldStoryDuration;
    case 'learn.vocab.count':
      return l10n.validationFieldLearnVocabCount;
    case 'learn.grammar.count':
      return l10n.validationFieldLearnGrammarCount;
    case 'learn.quiz.count':
      return l10n.validationFieldLearnQuizCount;
    default:
      if (field.startsWith('module.')) {
        final key = field.substring('module.'.length);
        return switch (key) {
          'vocabulary_kanji' => l10n.validationFieldModuleVocabularyKanji,
          'grammar' => l10n.validationFieldModuleGrammar,
          'quiz' => l10n.validationFieldModuleQuiz,
          'audio' => l10n.validationFieldModuleAudio,
          _ => l10n.validationFieldLearnModule,
        };
      }
      if (field.startsWith('learn.vocab')) {
        return l10n.validationFieldLearnVocabulary;
      }
      if (field.startsWith('learn.grammar')) {
        return l10n.validationFieldLearnGrammar;
      }
      if (field.startsWith('learn.quiz')) {
        return l10n.validationFieldLearnQuiz;
      }
      return field;
  }
}

String validationMessageKeyLocalized(
  BuildContext context,
  String messageKey, {
  Map<String, Object?> params = const {},
}) {
  if (messageKey == 'learn.module.notCompleted') {
    final l10n = AppLocalizations.of(context);
    final label =
        learnModuleLabelLocalized(context, params['module']?.toString() ?? '');
    if (l10n != null) {
      return l10n.validationLearnModuleNotCompletedWithLabel(label);
    }
    final issue = ValidationIssue(
      code: 'learn.module.notCompleted',
      field: 'learn.module',
      messageKey: messageKey,
      severity: ValidationSeverity.blocking,
      params: params,
    );
    return validationIssueDisplayMessage(issue);
  }

  final l10n = AppLocalizations.of(context);
  if (l10n != null) {
    try {
      final localized = _localizedFromL10n(l10n, messageKey, params);
      if (localized != null) return localized;
    } catch (_) {
      // Fall through to English map.
    }
  }

  final template = validationFallbackMessagesEn[messageKey];
  if (template != null) {
    return interpolateValidationFallback(template, params);
  }
  return validationUnknownFieldMessage;
}

String? _localizedFromL10n(
  AppLocalizations l10n,
  String messageKey,
  Map<String, Object?> params,
) {
  switch (messageKey) {
    case 'auth.confirmPassword.mismatch':
      return l10n.validationAuthConfirmPasswordMismatch;
    case 'auth.email.invalid':
      return l10n.validationAuthEmailInvalid;
    case 'auth.email.length':
      return l10n.validationAuthEmailLength;
    case 'auth.email.required':
      return l10n.validationAuthEmailRequired;
    case 'auth.email.unsafe':
      return l10n.validationAuthEmailUnsafe;
    case 'auth.login.failed':
      return l10n.validationAuthLoginFailed;
    case 'auth.password.length':
      return l10n.validationAuthPasswordLength;
    case 'auth.password.lineBreak':
      return l10n.validationAuthPasswordLineBreak;
    case 'auth.password.requiredLogin':
      return l10n.validationAuthPasswordRequiredLogin;
    case 'auth.password.weak':
      return l10n.validationAuthPasswordWeak;
    case 'collection.name.excessiveRepeat':
      return l10n.validationCollectionNameExcessiveRepeat;
    case 'collection.name.length':
      return l10n.validationCollectionNameLength;
    case 'collection.name.lineBreak':
      return l10n.validationCollectionNameLineBreak;
    case 'collection.name.noUrl':
      return l10n.validationCollectionNameNoUrl;
    case 'collection.name.onlyNumbers':
      return l10n.validationCollectionNameOnlyNumbers;
    case 'collection.name.onlySpaces':
      return l10n.validationCollectionNameOnlySpaces;
    case 'collection.name.onlySymbols':
      return l10n.validationCollectionNameOnlySymbols;
    case 'collection.name.required':
      return l10n.validationCollectionNameRequired;
    case 'collection.name.tooManyEmoji':
      return l10n.validationCollectionNameTooManyEmoji;
    case 'collection.name.unsafe':
      return l10n.validationCollectionNameUnsafe;
    case 'collection.title.excessiveRepeat':
      return l10n.validationCollectionTitleExcessiveRepeat;
    case 'collection.title.length':
      return l10n.validationCollectionTitleLength;
    case 'collection.title.lineBreak':
      return l10n.validationCollectionTitleLineBreak;
    case 'collection.title.noUrl':
      return l10n.validationCollectionTitleNoUrl;
    case 'collection.title.onlyNumbers':
      return l10n.validationCollectionTitleOnlyNumbers;
    case 'collection.title.onlySpaces':
      return l10n.validationCollectionTitleOnlySpaces;
    case 'collection.title.onlySymbols':
      return l10n.validationCollectionTitleOnlySymbols;
    case 'collection.title.required':
      return l10n.validationCollectionTitleRequired;
    case 'collection.title.tooManyEmoji':
      return l10n.validationCollectionTitleTooManyEmoji;
    case 'collection.title.unsafe':
      return l10n.validationCollectionTitleUnsafe;
    case 'learn.count.grammar.range':
      return l10n.validationLearnCountGrammarRange(
          _i(params['min']), _i(params['max']), _i(params['actual']));
    case 'learn.count.quiz.range':
      return l10n.validationLearnCountQuizRange(
          _i(params['min']), _i(params['max']), _i(params['actual']));
    case 'learn.count.vocab.range':
      return l10n.validationLearnCountVocabRange(
          _i(params['min']), _i(params['max']), _i(params['actual']));
    case 'learn.furigana.invalid':
      return l10n.validationLearnFuriganaInvalid;
    case 'learn.furigana.overlap':
      return l10n.validationLearnFuriganaOverlap;
    case 'learn.grammar.title.length':
      return l10n.validationLearnGrammarTitleLength;
    case 'learn.grammar.title.lineBreak':
      return l10n.validationLearnGrammarTitleLineBreak;
    case 'learn.grammar.title.noEmoji':
      return l10n.validationLearnGrammarTitleNoEmoji;
    case 'learn.grammar.title.noUrl':
      return l10n.validationLearnGrammarTitleNoUrl;
    case 'learn.grammar.title.required':
      return l10n.validationLearnGrammarTitleRequired;
    case 'learn.grammar.title.unsafe':
      return l10n.validationLearnGrammarTitleUnsafe;
    case 'learn.quiz.answer.notInOptions':
      return l10n.validationLearnQuizAnswerNotInOptions;
    case 'learn.quiz.answer.required':
      return l10n.validationLearnQuizAnswerRequired;
    case 'learn.quiz.answer.singleCorrect':
      return l10n.validationLearnQuizAnswerSingleCorrect;
    case 'learn.quiz.category.invalid':
      return l10n.validationLearnQuizCategoryInvalid;
    case 'learn.quiz.options.count':
      return l10n.validationLearnQuizOptionsCount;
    case 'learn.quiz.options.duplicate':
      return l10n.validationLearnQuizOptionsDuplicate;
    case 'learn.quiz.question.duplicate':
      return l10n.validationLearnQuizQuestionDuplicate;
    case 'learn.quiz.question.length':
      return l10n.validationLearnQuizQuestionLength;
    case 'learn.quiz.question.required':
      return l10n.validationLearnQuizQuestionRequired;
    case 'learn.quiz.question.unsafe':
      return l10n.validationLearnQuizQuestionUnsafe;
    case 'learn.vocab.meaning.length':
      return l10n.validationLearnVocabMeaningLength;
    case 'learn.vocab.meaning.lineBreak':
      return l10n.validationLearnVocabMeaningLineBreak;
    case 'learn.vocab.meaning.noEmoji':
      return l10n.validationLearnVocabMeaningNoEmoji;
    case 'learn.vocab.meaning.noHashtag':
      return l10n.validationLearnVocabMeaningNoHashtag;
    case 'learn.vocab.meaning.noUrl':
      return l10n.validationLearnVocabMeaningNoUrl;
    case 'learn.vocab.meaning.required':
      return l10n.validationLearnVocabMeaningRequired;
    case 'learn.vocab.meaning.unsafe':
      return l10n.validationLearnVocabMeaningUnsafe;
    case 'learn.vocab.reading.invalidChars':
      return l10n.validationLearnVocabReadingInvalidChars;
    case 'learn.vocab.reading.required':
      return l10n.validationLearnVocabReadingRequired;
    case 'learn.vocab.reading.tooLong':
      return l10n.validationLearnVocabReadingTooLong;
    case 'learn.vocab.reading.tooManyAlternatives':
      return l10n.validationLearnVocabReadingTooManyAlternatives;
    case 'learn.vocab.reading.unsafe':
      return l10n.validationLearnVocabReadingUnsafe;
    case 'media.audio.invalidType':
      return l10n.validationMediaAudioInvalidType;
    case 'media.audio.tooLarge':
      return l10n.validationMediaAudioTooLarge;
    case 'media.file.empty':
      return l10n.validationMediaFileEmpty;
    case 'media.file.invalidExtension':
      return l10n.validationMediaFileInvalidExtension;
    case 'media.file.invalidField':
      return l10n.validationMediaFileInvalidField;
    case 'media.file.invalidType':
      return l10n.validationMediaFileInvalidType;
    case 'media.file.required':
      return l10n.validationMediaFileRequired;
    case 'media.file.tooLarge':
      return l10n.validationMediaFileTooLarge;
    case 'media.image.invalidType':
      return l10n.validationMediaImageInvalidType;
    case 'media.image.tooLarge':
      return l10n.validationMediaImageTooLarge;
    case 'network.offline':
      return l10n.validationNetworkOffline;
    case 'profile.bio.tooLong':
      return l10n.validationProfileBioTooLong;
    case 'profile.bio.tooManyLines':
      return l10n.validationProfileBioTooManyLines;
    case 'profile.bio.unsafe':
      return l10n.validationProfileBioUnsafe;
    case 'profile.displayName.length':
      return l10n.validationProfileDisplayNameLength;
    case 'profile.displayName.required':
      return l10n.validationProfileDisplayNameRequired;
    case 'profile.displayName.unsafe':
      return l10n.validationProfileDisplayNameUnsafe;
    case 'profile.handle.invalidChars':
      return l10n.validationProfileHandleInvalidChars;
    case 'profile.handle.length':
      return l10n.validationProfileHandleLength;
    case 'profile.handle.noEmoji':
      return l10n.validationProfileHandleNoEmoji;
    case 'profile.handle.periodEdge':
      return l10n.validationProfileHandlePeriodEdge;
    case 'profile.handle.periodRepeat':
      return l10n.validationProfileHandlePeriodRepeat;
    case 'profile.handle.reserved':
      return l10n.validationProfileHandleReserved;
    case 'protected.createCollection.login':
      return l10n.validationProtectedCreateCollectionLogin;
    case 'protected.createStory.login':
      return l10n.validationProtectedCreateStoryLogin;
    case 'protected.editProfile.login':
      return l10n.validationProtectedEditProfileLogin;
    case 'protected.follow.login':
      return l10n.validationProtectedFollowLogin;
    case 'protected.generic.disabled':
      return l10n.validationProtectedGenericDisabled;
    case 'protected.generic.forbidden':
      return l10n.validationProtectedGenericForbidden;
    case 'protected.publishStory.login':
      return l10n.validationProtectedPublishStoryLogin;
    case 'protected.react.login':
      return l10n.validationProtectedReactLogin;
    case 'protected.save.login':
      return l10n.validationProtectedSaveLogin;
    case 'protected.uploadMedia.login':
      return l10n.validationProtectedUploadMediaLogin;
    case 'story.body.tooLong':
      return l10n.validationStoryBodyTooLong(
          _i(params['max']), _i(params['actual']));
    case 'story.description.excessiveRepeat':
      return l10n.validationStoryDescriptionExcessiveRepeat;
    case 'story.description.hashtagStuffing':
      return l10n.validationStoryDescriptionHashtagStuffing;
    case 'story.description.lineBreak':
      return l10n.validationStoryDescriptionLineBreak;
    case 'story.description.recommended':
      return l10n.validationStoryDescriptionRecommended;
    case 'story.description.tooLong':
      return l10n.validationStoryDescriptionTooLong;
    case 'story.description.tooManyEmoji':
      return l10n.validationStoryDescriptionTooManyEmoji;
    case 'story.description.tooManyUrls':
      return l10n.validationStoryDescriptionTooManyUrls;
    case 'story.description.unsafe':
      return l10n.validationStoryDescriptionUnsafe;
    case 'story.limits.skippedNoBand':
      return l10n.validationStoryLimitsSkippedNoBand;
    case 'story.limits.skippedNoJlpt':
      return l10n.validationStoryLimitsSkippedNoJlpt;
    case 'story.sentences.required':
      return l10n.validationStorySentencesRequired;
    case 'story.sentences.tooFew':
      return l10n.validationStorySentencesTooFew(
          _i(params['min']), _i(params['actual']));
    case 'story.sentences.tooMany':
      return l10n.validationStorySentencesTooMany(
          _i(params['max']), _i(params['actual']));
    case 'story.title.excessiveRepeat':
      return l10n.validationStoryTitleExcessiveRepeat;
    case 'story.title.lineBreak':
      return l10n.validationStoryTitleLineBreak;
    case 'story.title.onlyNumbers':
      return l10n.validationStoryTitleOnlyNumbers;
    case 'story.title.onlySymbols':
      return l10n.validationStoryTitleOnlySymbols;
    case 'story.title.recommended':
      return l10n.validationStoryTitleRecommended;
    case 'story.title.required':
      return l10n.validationStoryTitleRequired;
    case 'story.title.tooLong':
      return l10n.validationStoryTitleTooLong;
    case 'story.title.tooManyEmoji':
      return l10n.validationStoryTitleTooManyEmoji;
    case 'story.title.tooShort':
      return l10n.validationStoryTitleTooShort;
    case 'story.title.unsafe':
      return l10n.validationStoryTitleUnsafe;
    default:
      return null;
  }
}
