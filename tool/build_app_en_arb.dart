// Builds lib/l10n/app_en.arb from validation_fallback_messages.dart + extras.
// Run: dart run tool/build_app_en_arb.dart
//
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

String arbMethodName(String messageKey) {
  final parts = messageKey.split('.');
  final buf = StringBuffer('validation');
  for (final p in parts) {
    if (p.isEmpty) continue;
    buf.write(p[0].toUpperCase());
    if (p.length > 1) buf.write(p.substring(1));
  }
  return buf.toString();
}

Map<String, String> parseFallbackMap() {
  final src = File('lib/core/validation/validation_fallback_messages.dart')
      .readAsStringSync();
  final entries = <String, String>{};

  // Single-line entries
  final re1 = RegExp(r"'([^']+)':\s*'((?:\\'|[^'])*)'", multiLine: true);
  for (final m in re1.allMatches(src)) {
    entries[m.group(1)!] = m.group(2)!;
  }
  // Continuation: 'key':\n      'value'
  final re2 = RegExp(
    r"'([^']+)':\s*\n\s*'((?:\\'|[^'])*)'",
    multiLine: true,
  );
  for (final m in re2.allMatches(src)) {
    entries[m.group(1)!] = m.group(2)!;
  }

  return entries;
}

void main() {
  final keyToEnglish = parseFallbackMap();

  final out = <String, dynamic>{
    '@@locale': 'en',
    'settingsTitle': 'Settings',
    'settingsLanguageSection': 'Language',
    'settingsAppearanceSection': 'Appearance',
    'settingsAccountSection': 'Account',
    'settingsNotificationsSection': 'Notifications',
    'settingsAboutSection': 'About',
    'settingsAppLanguage': 'App Language',
    'settingsContentCommunity': 'Content Community',
    'settingsLearningLanguage': 'Learning Language',
    'settingsTheme': 'Theme',
    'settingsComingSoon': 'Coming soon',
    'settingsEditProfile': 'Edit profile',
    'settingsSignOut': 'Sign out',
    'settingsSignOutSubtitle': 'Leave this account on this device',
    'settingsSignInRequiredTitle': 'Sign in required',
    'settingsSignInRequiredBody': 'Settings are available after you sign in.',
    'settingsSignInCta': 'Sign in',
    'settingsAppVersion': 'App version',
    'settingsAppVersionPlaceholder': 'V1 shell (version integration deferred)',
    'settingsSystem': 'System',
    'settingsEnglish': 'English',
    'settingsJapanese': 'Japanese',
    'settingsMyanmar': 'Myanmar',
    'settingsInternationalEnglish': 'International / English',
    'settingsSignOutDialogTitle': 'Sign out?',
    'settingsSignOutDialogBody':
        'You will be signed out on this device and returned to the login screen.',
    'settingsCancel': 'Cancel',
    'settingsReadingSection': 'Reading',
    'settingsReadingTextSize': 'Reading text size',
    'settingsReadingTextSizeSmall': 'Small',
    'settingsReadingTextSizeStandard': 'Standard',
    'settingsReadingTextSizeLarge': 'Large',
    'settingsShowExplanationSentence': 'Explanation sentence',
    'settingsShowExplanationSentenceSubtitle':
        'Show per-sentence explanations in the mono reader',

    // Publish validation sheet + CTAs
    'validationPublishSheetTitle': 'Before publishing',
    'validationPublishSectionBlocking': 'Blocking',
    'validationPublishSectionRecommended': 'Recommended',
    'validationPublishFixIssuesCta': 'Fix issues',
    'validationPublishAnywayCta': 'Publish anyway',
    'validationCtaSignIn': 'Sign in',
    'validationCtaNotNow': 'Not now',
    'validationCtaOk': 'OK',

    // Media upload generic fallbacks (mapper)
    'validationMediaUploadGenericImage':
        'Could not upload image. Please try again.',
    'validationMediaUploadGenericAudio':
        'Could not upload audio. Please try again.',

    // Publish field labels (validationFieldLabelForPublish)
    'validationFieldStoryTitle': 'Story title',
    'validationFieldStoryDescription': 'Description',
    'validationFieldStorySentences': 'Sentences',
    'validationFieldStoryBody': 'Story body',
    'validationFieldStoryLevel': 'JLPT level',
    'validationFieldStoryDuration': 'Duration',
    'validationFieldLearnVocabCount': 'Vocabulary',
    'validationFieldLearnGrammarCount': 'Grammar',
    'validationFieldLearnQuizCount': 'Quiz',
    'validationFieldLearnVocabulary': 'Vocabulary',
    'validationFieldLearnGrammar': 'Grammar',
    'validationFieldLearnQuiz': 'Quiz',
    'validationFieldModuleVocabularyKanji': 'Vocabulary / Kanji module',
    'validationFieldModuleGrammar': 'Grammar module',
    'validationFieldModuleQuiz': 'Quiz module',
    'validationFieldModuleAudio': 'Listening module',
    'validationFieldLearnModule': 'Learn module',

    // learn.module dynamic template + labels (replaces static learn.module.notCompleted string)
    'validationLearnModuleNotCompletedWithLabel':
        'Complete the {moduleLabel} module before publishing.',
    '@validationLearnModuleNotCompletedWithLabel': {
      'placeholders': {
        'moduleLabel': {'type': 'String'},
      },
    },
    'validationLearnModuleLabelLearn': 'learn',
    'validationLearnModuleLabelVocabularyKanji': 'Vocabulary / Kanji',
    'validationLearnModuleLabelGrammar': 'Grammar',
    'validationLearnModuleLabelQuiz': 'Quiz',
    'validationLearnModuleLabelAudio': 'Listening / Audio',

    // Reserved learn.furigana keys (future validators; mirror English)
    'validationLearnFuriganaInvalid': 'Furigana for this text is not valid.',
    'validationLearnFuriganaOverlap': 'Furigana ranges cannot overlap.',

    // --- validation message keys from fallback map ---
  };

  // Omit learn.module.notCompleted static — use template instead in resolver.
  for (final e in keyToEnglish.entries) {
    if (e.key == 'learn.module.notCompleted') continue;
    final name = arbMethodName(e.key);
    out[name] = e.value;
  }

  // Placeholder metadata for interpolated templates
  const meta = <String, Map<String, dynamic>>{
    'validationStorySentencesTooFew': {
      'placeholders': {
        'min': {'type': 'int'},
        'actual': {'type': 'int'},
      },
    },
    'validationStorySentencesTooMany': {
      'placeholders': {
        'max': {'type': 'int'},
        'actual': {'type': 'int'},
      },
    },
    'validationStoryBodyTooLong': {
      'placeholders': {
        'max': {'type': 'int'},
        'actual': {'type': 'int'},
      },
    },
    'validationLearnCountVocabRange': {
      'placeholders': {
        'min': {'type': 'int'},
        'max': {'type': 'int'},
        'actual': {'type': 'int'},
      },
    },
    'validationLearnCountGrammarRange': {
      'placeholders': {
        'min': {'type': 'int'},
        'max': {'type': 'int'},
        'actual': {'type': 'int'},
      },
    },
    'validationLearnCountQuizRange': {
      'placeholders': {
        'min': {'type': 'int'},
        'max': {'type': 'int'},
        'actual': {'type': 'int'},
      },
    },
  };
  for (final e in meta.entries) {
    out['@${e.key}'] = e.value;
  }

  // JSON encoder with indentation (Dart JsonEncoder default)
  const encoder = JsonEncoder.withIndent('  ');
  File('lib/l10n/app_en.arb').writeAsStringSync('${encoder.convert(out)}\n');
  print('Wrote lib/l10n/app_en.arb (${out.length} top-level keys)');
}
