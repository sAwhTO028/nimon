import 'package:nimon/core/validation/text_normalization.dart';
import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/core/validation/validation_mode.dart';
import 'package:nimon/core/validation/validation_result.dart';
import 'package:nimon/core/validation/validation_severity.dart';

typedef JlptLevel = String;
typedef StoryDurationBand = String;

class StorySentenceBandLimits {
  const StorySentenceBandLimits({
    required this.minSentences,
    required this.maxSentences,
    required this.maxChars,
  });

  final int minSentences;
  final int maxSentences;
  final int maxChars;
}

/// Mirrors backend `STORY_SENTENCE_LIMITS` exactly.
final Map<JlptLevel, Map<StoryDurationBand, StorySentenceBandLimits>>
    storySentenceLimits = {
  'N5': {
    '3_5': const StorySentenceBandLimits(
      minSentences: 10,
      maxSentences: 35,
      maxChars: 900,
    ),
    '5_7': const StorySentenceBandLimits(
      minSentences: 18,
      maxSentences: 50,
      maxChars: 1250,
    ),
    '7_9': const StorySentenceBandLimits(
      minSentences: 25,
      maxSentences: 65,
      maxChars: 1600,
    ),
  },
  'N4': {
    '3_5': const StorySentenceBandLimits(
      minSentences: 8,
      maxSentences: 30,
      maxChars: 1000,
    ),
    '5_7': const StorySentenceBandLimits(
      minSentences: 15,
      maxSentences: 45,
      maxChars: 1400,
    ),
    '7_9': const StorySentenceBandLimits(
      minSentences: 22,
      maxSentences: 60,
      maxChars: 1800,
    ),
  },
  'N3': {
    '3_5': const StorySentenceBandLimits(
      minSentences: 7,
      maxSentences: 25,
      maxChars: 1150,
    ),
    '5_7': const StorySentenceBandLimits(
      minSentences: 12,
      maxSentences: 38,
      maxChars: 1600,
    ),
    '7_9': const StorySentenceBandLimits(
      minSentences: 18,
      maxSentences: 52,
      maxChars: 2100,
    ),
  },
  'N2': {
    '3_5': const StorySentenceBandLimits(
      minSentences: 6,
      maxSentences: 20,
      maxChars: 1300,
    ),
    '5_7': const StorySentenceBandLimits(
      minSentences: 10,
      maxSentences: 32,
      maxChars: 1850,
    ),
    '7_9': const StorySentenceBandLimits(
      minSentences: 15,
      maxSentences: 45,
      maxChars: 2350,
    ),
  },
  'N1': {
    '3_5': const StorySentenceBandLimits(
      minSentences: 5,
      maxSentences: 18,
      maxChars: 1500,
    ),
    '5_7': const StorySentenceBandLimits(
      minSentences: 8,
      maxSentences: 28,
      maxChars: 2100,
    ),
    '7_9': const StorySentenceBandLimits(
      minSentences: 12,
      maxSentences: 38,
      maxChars: 2700,
    ),
  },
};

ValidationIssue _block(String field, String code, String messageKey,
        [Map<String, Object?>? params]) =>
    ValidationIssue(
      code: code,
      field: field,
      messageKey: messageKey,
      severity: ValidationSeverity.blocking,
      source: 'story_validators',
      params: params,
    );

ValidationIssue _warn(String field, String code, String messageKey,
        [Map<String, Object?>? params]) =>
    ValidationIssue(
      code: code,
      field: field,
      messageKey: messageKey,
      severity: ValidationSeverity.warning,
      source: 'story_validators',
      params: params,
    );

ValidationResult validateStoryTitle(String? raw, ValidationMode mode) {
  final normalized = normalizeSingleLineText(trimText(raw ?? ''));
  final publishLike = mode == ValidationMode.readOnlyPublish ||
      mode == ValidationMode.fullLearnPublish;

  if (normalized.isEmpty) {
    if (publishLike) {
      return resultFromIssues([
        _block('story.title', 'story.title.required', 'story.title.required'),
      ]);
    }
    return resultFromIssues([
      _warn(
        'story.title',
        'story.title.empty',
        'story.title.recommended',
      ),
    ]);
  }

  if (mode == ValidationMode.draft) {
    final draftIssues = <ValidationIssue>[];
    if (containsHtmlOrScript(normalized)) {
      draftIssues.add(
        _block('story.title', 'story.title.unsafe', 'story.title.unsafe'),
      );
    }
    if (RegExp(r'[\r\n]').hasMatch(trimText(raw ?? ''))) {
      draftIssues.add(
        _block(
          'story.title',
          'story.title.lineBreak',
          'story.title.lineBreak',
        ),
      );
    }
    return resultFromIssues(draftIssues);
  }

  final issues = <ValidationIssue>[];
  final len = charLength(normalized);
  if (len < 5) {
    issues.add(
      _block(
        'story.title',
        'story.title.tooShort',
        'story.title.tooShort',
        {'min': 5, 'actual': len},
      ),
    );
  }
  if (len > 80) {
    issues.add(
      _block(
        'story.title',
        'story.title.tooLong',
        'story.title.tooLong',
        {'max': 80, 'actual': len},
      ),
    );
  }

  if (containsHtmlOrScript(normalized)) {
    issues
        .add(_block('story.title', 'story.title.unsafe', 'story.title.unsafe'));
  }

  if (RegExp(r'[\r\n]').hasMatch(trimText(raw ?? ''))) {
    issues.add(
      _block('story.title', 'story.title.lineBreak', 'story.title.lineBreak'),
    );
  }

  final emojis = countEmojis(normalized);
  if (emojis > 1) {
    issues.add(
      _block(
        'story.title',
        'story.title.tooManyEmoji',
        'story.title.tooManyEmoji',
        {'max': 1, 'actual': emojis},
      ),
    );
  }

  if (isOnlyNumbers(normalized)) {
    issues.add(
      _block(
        'story.title',
        'story.title.onlyNumbers',
        'story.title.onlyNumbers',
      ),
    );
  }

  if (isOnlySymbols(normalized)) {
    issues.add(
      _block(
        'story.title',
        'story.title.onlySymbols',
        'story.title.onlySymbols',
      ),
    );
  }

  if (hasExcessiveRepeatedCharacters(normalized, 4)) {
    issues.add(
      _block(
        'story.title',
        'story.title.excessiveRepeat',
        'story.title.excessiveRepeat',
      ),
    );
  }

  return resultFromIssues(issues);
}

ValidationResult validateStoryDescription(String? raw, ValidationMode mode) {
  final normalized = normalizeSingleLineText(trimText(raw ?? ''));
  if (normalized.isEmpty) {
    if (mode == ValidationMode.readOnlyPublish ||
        mode == ValidationMode.fullLearnPublish) {
      return resultFromIssues([
        _warn(
          'story.description',
          'story.description.recommended',
          'story.description.recommended',
        ),
      ]);
    }
    return okResult();
  }

  if (mode == ValidationMode.draft) {
    final draftIssues = <ValidationIssue>[];
    if (containsHtmlOrScript(normalized)) {
      draftIssues.add(
        _block(
          'story.description',
          'story.description.unsafe',
          'story.description.unsafe',
        ),
      );
    }
    if (RegExp(r'[\r\n]').hasMatch(trimText(raw ?? ''))) {
      draftIssues.add(
        _block(
          'story.description',
          'story.description.lineBreak',
          'story.description.lineBreak',
        ),
      );
    }
    return resultFromIssues(draftIssues);
  }

  final issues = <ValidationIssue>[];
  final len = charLength(normalized);
  if (len > 160) {
    issues.add(
      _block(
        'story.description',
        'story.description.tooLong',
        'story.description.tooLong',
        {'max': 160, 'actual': len},
      ),
    );
  }

  if (containsHtmlOrScript(normalized)) {
    issues.add(
      _block(
        'story.description',
        'story.description.unsafe',
        'story.description.unsafe',
      ),
    );
  }

  if (RegExp(r'[\r\n]').hasMatch(trimText(raw ?? ''))) {
    issues.add(
      _block(
        'story.description',
        'story.description.lineBreak',
        'story.description.lineBreak',
      ),
    );
  }

  if (countUrls(normalized) > 1) {
    issues.add(
      _block(
        'story.description',
        'story.description.tooManyUrls',
        'story.description.tooManyUrls',
      ),
    );
  }

  final tags = countHashtags(normalized);
  if (tags > 4) {
    issues.add(
      _block(
        'story.description',
        'story.description.hashtagStuffing',
        'story.description.hashtagStuffing',
        {'max': 4, 'actual': tags},
      ),
    );
  }

  final emojis = countEmojis(normalized);
  if (emojis > 2) {
    issues.add(
      _block(
        'story.description',
        'story.description.tooManyEmoji',
        'story.description.tooManyEmoji',
        {'max': 2, 'actual': emojis},
      ),
    );
  }

  if (hasExcessiveRepeatedCharacters(normalized, 4)) {
    issues.add(
      _block(
        'story.description',
        'story.description.excessiveRepeat',
        'story.description.excessiveRepeat',
      ),
    );
  }

  return resultFromIssues(issues);
}
