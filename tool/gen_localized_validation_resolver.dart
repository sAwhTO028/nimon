// Generates lib/core/validation/localized_validation_messages.dart
// Run: dart run tool/gen_localized_validation_resolver.dart

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
  final re1 = RegExp(r"'([^']+)':\s*'((?:\\'|[^'])*)'", multiLine: true);
  for (final m in re1.allMatches(src)) {
    entries[m.group(1)!] = m.group(2)!;
  }
  final re2 = RegExp(
    r"'([^']+)':\s*\n\s*'((?:\\'|[^'])*)'",
    multiLine: true,
  );
  for (final m in re2.allMatches(src)) {
    entries[m.group(1)!] = m.group(2)!;
  }
  return entries;
}

String interpolationCall(String messageKey, String method) {
  switch (messageKey) {
    case 'story.sentences.tooFew':
      return 'return l10n.$method(_i(params[\'min\']), _i(params[\'actual\']));';
    case 'story.sentences.tooMany':
      return 'return l10n.$method(_i(params[\'max\']), _i(params[\'actual\']));';
    case 'story.body.tooLong':
      return 'return l10n.$method(_i(params[\'max\']), _i(params[\'actual\']));';
    case 'learn.count.vocab.range':
    case 'learn.count.grammar.range':
    case 'learn.count.quiz.range':
      return 'return l10n.$method(_i(params[\'min\']), _i(params[\'max\']), _i(params[\'actual\']));';
    default:
      return 'return l10n.$method;';
  }
}

bool needsInterpolation(String messageKey) =>
    messageKey == 'story.sentences.tooFew' ||
    messageKey == 'story.sentences.tooMany' ||
    messageKey == 'story.body.tooLong' ||
    messageKey == 'learn.count.vocab.range' ||
    messageKey == 'learn.count.grammar.range' ||
    messageKey == 'learn.count.quiz.range';

void main() {
  final keys = parseFallbackMap().keys.toList()..sort();
  final buf = StringBuffer(r'''
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
''');

  for (final k in keys) {
    if (k == 'learn.module.notCompleted') {
      continue;
    }
    final m = arbMethodName(k);
    buf.writeln("    case '$k':");
    if (needsInterpolation(k)) {
      buf.writeln('      ${interpolationCall(k, m)}');
    } else {
      buf.writeln('      return l10n.$m;');
    }
  }

  buf.writeln('    default:');
  buf.writeln('      return null;');
  buf.writeln('  }');
  buf.writeln('}');

  File('lib/core/validation/localized_validation_messages.dart')
      .writeAsStringSync(buf.toString());
  print('Wrote lib/core/validation/localized_validation_messages.dart');
}
