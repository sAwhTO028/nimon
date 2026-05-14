import 'package:nimon/core/validation/validation_issue.dart';

/// English fallbacks for [ValidationIssue.messageKey] until full l10n wiring.
const validationFallbackMessagesEn = <String, String>{
  'profile.displayName.required': 'Enter a display name.',
  'profile.displayName.length':
      'Display name must be between 1 and 30 characters.',
  'profile.displayName.unsafe':
      'Display name contains content that is not allowed.',
  'profile.handle.noEmoji': 'Handles cannot include emoji.',
  'profile.handle.length': 'Handle must be between 3 and 24 characters.',
  'profile.handle.invalidChars':
      'Handles may use lowercase letters, numbers, underscore, and period only.',
  'profile.handle.periodEdge': 'Handles cannot start or end with a period.',
  'profile.handle.periodRepeat': 'Handles cannot contain consecutive periods.',
  'profile.handle.reserved': 'That handle is reserved.',
  'profile.bio.tooLong': 'Bio must be at most 150 characters.',
  'profile.bio.unsafe': 'Bio contains content that is not allowed.',
  'profile.bio.tooManyLines': 'Bio may have at most 3 lines.',
  'story.title.required': 'Title is required to publish.',
  'story.title.recommended': 'Add a title for your story.',
  'story.title.tooShort': 'Title must be at least 5 characters.',
  'story.title.tooLong': 'Title must be at most 80 characters.',
  'story.title.unsafe': 'Title contains content that is not allowed.',
  'story.title.lineBreak': 'Title cannot contain line breaks.',
  'story.title.tooManyEmoji': 'Title may include at most one emoji.',
  'story.title.onlyNumbers': 'Title cannot be only numbers.',
  'story.title.onlySymbols': 'Title cannot be only symbols.',
  'story.title.excessiveRepeat': 'Title has too many repeated characters.',
  'story.description.recommended': 'Add a short description before publishing.',
  'story.description.tooLong': 'Description must be at most 160 characters.',
  'story.description.unsafe':
      'Description contains content that is not allowed.',
  'story.description.lineBreak': 'Description cannot contain line breaks.',
  'story.description.tooManyUrls': 'Description may include at most one link.',
  'story.description.hashtagStuffing': 'Too many hashtags in the description.',
  'story.description.tooManyEmoji':
      'Description may include at most two emoji.',
  'story.description.excessiveRepeat':
      'Description has too many repeated characters.',
  'collection.title.required': 'Collection name is required.',
  'collection.title.length':
      'Collection name must be between 1 and 40 characters.',
  'collection.title.unsafe':
      'Collection name contains content that is not allowed.',
  'collection.title.lineBreak': 'Collection name cannot contain line breaks.',
  'collection.title.noUrl': 'Collection name cannot contain links.',
  'collection.title.tooManyEmoji':
      'Collection name may include at most one emoji.',
  'collection.title.onlyNumbers': 'Collection name cannot be only numbers.',
  'collection.title.onlySymbols': 'Collection name cannot be only symbols.',
  'collection.title.onlySpaces': 'Collection name needs letters or numbers.',
  'collection.title.excessiveRepeat':
      'Collection name has too many repeated characters.',
  // Aliases for product/docs (`collection.name.*`); validators use `collection.title`.
  'collection.name.required': 'Collection name is required.',
  'collection.name.length':
      'Collection name must be between 1 and 40 characters.',
  'collection.name.unsafe':
      'Collection name contains content that is not allowed.',
  'collection.name.lineBreak': 'Collection name cannot contain line breaks.',
  'collection.name.noUrl': 'Collection name cannot contain links.',
  'collection.name.tooManyEmoji':
      'Collection name may include at most one emoji.',
  'collection.name.onlyNumbers': 'Collection name cannot be only numbers.',
  'collection.name.onlySymbols': 'Collection name cannot be only symbols.',
  'collection.name.onlySpaces': 'Collection name needs letters or numbers.',
  'collection.name.excessiveRepeat':
      'Collection name has too many repeated characters.',
  'auth.email.required': 'Email is required.',
  'auth.email.length': 'Email must be between 5 and 254 characters.',
  'auth.email.invalid': 'Enter a valid email address.',
  'auth.email.unsafe': 'Email contains content that is not allowed.',
  'auth.password.length': 'Password must be between 8 and 64 characters.',
  'auth.password.weak': 'That password is too common. Choose a stronger one.',
  'auth.password.lineBreak': 'Password cannot contain line breaks.',
  'auth.password.requiredLogin': 'Password is required.',
  'auth.confirmPassword.mismatch': 'Passwords do not match.',
  'auth.login.failed': 'Email or password is incorrect.',
  'learn.vocab.meaning.required': 'Meaning is required for this publish mode.',
  'learn.vocab.meaning.length': 'Meaning must be between 1 and 80 characters.',
  'learn.vocab.meaning.noEmoji': 'Meaning cannot include emoji.',
  'learn.vocab.meaning.lineBreak': 'Meaning cannot contain line breaks.',
  'learn.vocab.meaning.unsafe': 'Meaning contains content that is not allowed.',
  'learn.vocab.meaning.noUrl': 'Meaning cannot contain links.',
  'learn.vocab.meaning.noHashtag': 'Meaning cannot contain hashtags.',
  'learn.vocab.reading.required': 'Reading is required for this word.',
  'learn.vocab.reading.tooLong': 'Reading must be at most 40 characters.',
  'learn.vocab.reading.tooManyAlternatives': 'Too many alternative readings.',
  'learn.vocab.reading.invalidChars':
      'Reading may use hiragana, katakana, ・ and / only.',
  'learn.vocab.reading.unsafe': 'Reading contains content that is not allowed.',
  'learn.furigana.invalid': 'Furigana for this text is not valid.',
  'learn.furigana.overlap': 'Furigana ranges cannot overlap.',
  'learn.grammar.title.required': 'Grammar title is required.',
  'learn.grammar.title.length':
      'Grammar title must be between 2 and 40 characters.',
  'learn.grammar.title.noEmoji': 'Grammar title cannot include emoji.',
  'learn.grammar.title.lineBreak': 'Grammar title cannot contain line breaks.',
  'learn.grammar.title.unsafe':
      'Grammar title contains content that is not allowed.',
  'learn.grammar.title.noUrl': 'Grammar title cannot contain links.',
  'learn.quiz.category.invalid': 'Choose a quiz category.',
  'learn.quiz.question.required': 'Question is required.',
  'learn.quiz.question.length':
      'Question must be between 5 and 120 characters.',
  'learn.quiz.question.unsafe':
      'Question contains content that is not allowed.',
  'learn.quiz.question.duplicate': 'That question is already in this story.',
  'learn.quiz.options.count': 'Provide between 2 and 4 answer options.',
  'learn.quiz.options.duplicate': 'Answer options must be unique.',
  'learn.quiz.answer.required': 'Choose the correct answer.',
  'learn.quiz.answer.notInOptions':
      'Correct answer must match one of the options.',
  'learn.quiz.answer.singleCorrect':
      'Exactly one option must be marked correct.',
  'story.sentences.required': 'Add at least one Japanese sentence.',
  'story.sentences.tooFew':
      'Not enough sentences for this level and duration (minimum {min}; you have {actual}).',
  'story.sentences.tooMany':
      'Too many sentences for this level and duration (maximum {max}; you have {actual}).',
  'story.body.tooLong':
      'Story text is too long (maximum {max} characters; you have {actual}).',
  'story.limits.skippedNoJlpt':
      'JLPT level is not set; sentence length limits were not applied.',
  'story.limits.skippedNoBand':
      'Duration band is not set; sentence length limits were not applied.',
  'learn.count.vocab.range':
      'Vocabulary count must be between {min} and {max} (you have {actual}).',
  'learn.count.grammar.range':
      'Grammar count must be between {min} and {max} (you have {actual}).',
  'learn.count.quiz.range':
      'Quiz count must be between {min} and {max} (you have {actual}).',
  'learn.module.notCompleted':
      'Complete all Full Learn modules before publishing.',

  /// Protected-action UX (M13C); stable keys for login / offline prompts.
  'protected.react.login': 'Sign in to react to stories.',
  'protected.follow.login': 'Sign in to follow creators.',
  'protected.save.login': 'Sign in to save stories.',
  'protected.createStory.login':
      'Sign in to create and publish Monos.',
  'protected.publishStory.login': 'Sign in to publish your story.',
  'protected.createCollection.login': 'Sign in to create collections.',
  'protected.uploadMedia.login': 'Sign in to upload media.',
  'protected.editProfile.login':
      'Sign in to view and manage your profile.',
  'protected.generic.forbidden': 'This action is not available.',
  'protected.generic.disabled': 'This action is disabled for your account.',

  'media.file.required': 'Please choose a file to upload.',
  'media.file.empty': 'This file is empty. Please choose another file.',
  'media.file.tooLarge': 'This file is too large.',
  'media.file.invalidType': 'This file type is not supported.',
  'media.file.invalidExtension': 'This file extension is not supported.',
  'media.file.invalidField': 'Upload request was missing a required field.',
  'media.image.invalidType': 'Please choose a JPG, PNG, or WebP image.',
  'media.image.tooLarge': 'This image is too large.',
  'media.audio.invalidType': 'Please choose a supported audio file.',
  'media.audio.tooLarge': 'This audio file is too large.',

  'network.offline':
      'No internet connection. Please check your network and try again.',
};

String validationFallbackMessage(String messageKey) =>
    validationFallbackMessagesEn[messageKey] ?? messageKey;

String interpolateValidationFallback(
  String template,
  Map<String, Object?>? params,
) {
  if (params == null || params.isEmpty) return template;
  var out = template;
  for (final e in params.entries) {
    out = out.replaceAll('{${e.key}}', '${e.value}');
  }
  return out;
}

String validationIssueDisplayMessage(ValidationIssue issue) {
  if (issue.messageKey == 'learn.module.notCompleted') {
    final k = issue.params?['module']?.toString() ?? '';
    final label = switch (k) {
      'vocabulary_kanji' => 'Vocabulary / Kanji',
      'grammar' => 'Grammar',
      'quiz' => 'Quiz',
      'audio' => 'Listening / Audio',
      _ when k.isNotEmpty => k,
      _ => 'learn',
    };
    return 'Complete the $label module before publishing.';
  }
  final t = validationFallbackMessage(issue.messageKey);
  return interpolateValidationFallback(t, issue.params);
}

/// Short labels for validation [ValidationIssue.field] (publish gate UI).
String validationFieldLabelForPublish(String field) {
  switch (field) {
    case 'story.title':
      return 'Story title';
    case 'story.description':
      return 'Description';
    case 'story.sentences':
      return 'Sentences';
    case 'story.body':
      return 'Story body';
    case 'story.level':
      return 'JLPT level';
    case 'story.duration':
      return 'Duration';
    case 'learn.vocab.count':
      return 'Vocabulary';
    case 'learn.grammar.count':
      return 'Grammar';
    case 'learn.quiz.count':
      return 'Quiz';
    default:
      if (field.startsWith('module.')) {
        final key = field.substring('module.'.length);
        return switch (key) {
          'vocabulary_kanji' => 'Vocabulary / Kanji module',
          'grammar' => 'Grammar module',
          'quiz' => 'Quiz module',
          'audio' => 'Listening module',
          _ => 'Learn module',
        };
      }
      if (field.startsWith('learn.vocab')) {
        return 'Vocabulary';
      }
      if (field.startsWith('learn.grammar')) {
        return 'Grammar';
      }
      if (field.startsWith('learn.quiz')) {
        return 'Quiz';
      }
      return field;
  }
}
