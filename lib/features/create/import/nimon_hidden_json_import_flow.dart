import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/core/validation/auth_validators.dart' show normalizeEmailInput;
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/auth/current_user_id_provider.dart';
import 'package:nimon/features/create/creator_back_policy.dart';
import 'package:nimon/features/create/import/nimon_import_dev_config.dart';
import 'package:nimon/features/create/import/nimon_import_models.dart';
import 'package:nimon/features/create/presentation/providers/story_creator_add_tab_draft_summary_provider.dart';
import 'package:nimon/features/create/story_creator_provider.dart';
import 'package:nimon/features/settings/data/user_preferences_repository.dart';
import 'package:nimon/core/settings/content_community.dart';
import 'package:nimon/features/settings/presentation/providers/user_preferences_notifier.dart';

// -----------------------------------------------------------------------------
// Hidden developer JSON import (Add tab).
// -----------------------------------------------------------------------------

/// Thrown when picked JSON cannot be decoded or is not a root object.
class NimonImportJsonParseException implements Exception {
  NimonImportJsonParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Builds validation context from current Riverpod app state (no network).
NimonImportValidationContext buildNimonImportValidationContext(WidgetRef ref) {
  final prefs = ref.read(userPreferencesNotifierProvider).prefs;
  final session = ref.read(authSessionProvider);
  final email = switch (session) {
    AuthSessionAuthenticated(:final user) => normalizeEmailInput(user.email),
    _ => '',
  };
  return NimonImportValidationContext(
    learningLanguageCode: prefs.learningLanguage,
    contentLocaleCode: normalizeContentLocaleWireCode(prefs.contentLocale) ??
        UserPreferences.defaults.contentLocale,
    authenticatedEmail: email.isEmpty ? null : email,
  );
}

/// Decodes UTF-8 JSON text; root must be a JSON object.
Map<String, Object?> decodeImportJsonRoot(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    throw NimonImportJsonParseException('File is empty.');
  }
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) {
      throw NimonImportJsonParseException(
        'JSON root must be an object.',
      );
    }
    return Map<String, Object?>.from(decoded.cast<String, Object?>());
  } on FormatException catch (e) {
    throw NimonImportJsonParseException('Invalid JSON: ${e.message}');
  }
}

/// Whether import validation flagged missing Full Learn audio.
bool importValidationNeedsFullLearnAudio(NimonImportValidationResult validation) {
  return validation.missingPublishRequirements.any(
    (i) => i.code == 'import.fullLearn.audioRequired',
  );
}

/// Success dialog body after [importMappedDraft] (not “Ready to Publish”).
String importSuccessDialogBody(NimonImportValidationResult validation) {
  if (importValidationNeedsFullLearnAudio(validation)) {
    return 'This draft is ready to preview. '
        'Audio upload is required before Full Learn publish.';
  }
  return 'This draft is ready to preview.';
}

/// Legacy combined message (title + body); prefer [importSuccessDialogBody].
String importSuccessMessage(NimonImportValidationResult validation) {
  return 'Import completed. ${importSuccessDialogBody(validation)}';
}

/// GoRouter location for the imported draft story workspace (main sentences surface).
String importedDraftPreviewLocation(String draftId) {
  return creatorStorySentencesMainLocation(draftId: draftId.trim());
}

/// Opens [StoryCreatorSentencesScreen] for [draftId] (same rules as draft resume).
void navigateToImportedDraftPreview(BuildContext context, String draftId) {
  final target = importedDraftPreviewLocation(draftId);
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    context.push(target);
    return;
  }
  if (router.state.uri.path.startsWith('/create/story')) {
    context.go(target);
  } else {
    context.push(target);
  }
}

/// Picks a `.json` file and returns its UTF-8 text, or `null` if cancelled.
Future<String?> pickJsonFileText() async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    type: FileType.custom,
    allowedExtensions: const ['json'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;

  final bytes = file.bytes;
  if (bytes != null && bytes.isNotEmpty) {
    return utf8.decode(bytes);
  }

  if (!kIsWeb) {
    final path = file.path;
    if (path != null && path.trim().isNotEmpty) {
      return File(path).readAsString();
    }
  }

  throw NimonImportJsonParseException(
    'Could not read file contents. Try a smaller file or re-export the JSON.',
  );
}

Future<void> showHiddenJsonImportEntryDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!NimonImportDevConfig.jsonImportUiEnabled) return;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Developer import'),
      content: const Text(
        'Import an AI-generated Nimon JSON file as a local creator draft. '
        'This tool is for internal testing only.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Import JSON'),
        ),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  await runHiddenJsonImportFlow(context, ref);
}

/// Full pick → validate → confirm → map → [importMappedDraft] flow.
Future<void> runHiddenJsonImportFlow(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!NimonImportDevConfig.jsonImportUiEnabled) return;

  try {
    final text = await pickJsonFileText();
    if (text == null) return;
    if (!context.mounted) return;

    final root = decodeImportJsonRoot(text);
    final payload = NimonImportRawPayload.fromJsonMap(root);
    final validationContext = buildNimonImportValidationContext(ref);
    final validation = validateNimonImportPayload(payload, validationContext);

    if (!context.mounted) return;

    if (!validation.canImport) {
      await _showValidationReportDialog(
        context,
        validation,
        title: 'Import blocked',
      );
      return;
    }

    final proceed = await _showValidationReportDialog(
      context,
      validation,
      title: 'Import validation',
      confirmImportLabel: 'Import draft',
    );
    if (proceed != true || !context.mounted) return;

    final ownerId = ref.read(currentUserIdProvider);
    final mapped = mapNimonImportPayloadToCreatorStoryV1(
      payload,
      ownerId: ownerId,
    );
    await ref.read(storyCreatorDraftProvider.notifier).importMappedDraft(mapped);
    unawaited(
      ref.read(storyCreatorAddTabDraftSummaryProvider.notifier).refresh(),
    );

    if (!context.mounted) return;
    final openPreview = await _showImportCompleteDialog(context, validation);
    if (openPreview == true && context.mounted) {
      ref.read(creatorEntryChannelProvider.notifier).state =
          CreatorEntryChannel.add;
      navigateToImportedDraftPreview(context, mapped.id);
    }
  } on NimonImportJsonParseException catch (e) {
    if (!context.mounted) return;
    await _showErrorDialog(context, e.message);
  } on NimonImportMappingException catch (e) {
    if (!context.mounted) return;
    await _showErrorDialog(context, e.toString());
  } catch (e) {
    if (!context.mounted) return;
    await _showErrorDialog(context, 'Import failed: $e');
  }
}

Future<bool?> _showImportCompleteDialog(
  BuildContext context,
  NimonImportValidationResult validation,
) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Import completed'),
      content: Text(importSuccessDialogBody(validation)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Stay here'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Open preview'),
        ),
      ],
    ),
  );
}

Future<bool?> _showValidationReportDialog(
  BuildContext context,
  NimonImportValidationResult validation, {
  required String title,
  String? confirmImportLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: _ValidationReportBody(validation: validation),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(confirmImportLabel == null ? 'OK' : 'Cancel'),
        ),
        if (confirmImportLabel != null)
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmImportLabel),
          ),
      ],
    ),
  );
}

Future<void> _showErrorDialog(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Import failed'),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class _ValidationReportBody extends StatelessWidget {
  const _ValidationReportBody({required this.validation});

  final NimonImportValidationResult validation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          validation.canImport
              ? (validation.canPublishImmediately
                  ? 'Ready to preview (import layer).'
                  : 'Ready to preview. Some publish steps remain.')
              : 'Cannot import until blocking issues are fixed.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (validation.blockingErrors.isNotEmpty) ...[
          Text('Blocking', style: theme.textTheme.titleSmall),
          ...validation.blockingErrors.map((i) => _issueTile(i, theme)),
        ],
        if (validation.missingPublishRequirements.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Before publish', style: theme.textTheme.titleSmall),
          ...validation.missingPublishRequirements.map(
            (i) => _issueTile(i, theme),
          ),
        ],
        if (validation.warnings.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Warnings', style: theme.textTheme.titleSmall),
          ...validation.warnings.map((i) => _issueTile(i, theme)),
        ],
        if (validation.blockingErrors.isEmpty &&
            validation.missingPublishRequirements.isEmpty &&
            validation.warnings.isEmpty)
          const Text('No issues reported.'),
      ],
    );
  }

  Widget _issueTile(NimonImportIssue issue, ThemeData theme) {
    final path =
        issue.path == null || issue.path!.isEmpty ? '' : ' (${issue.path})';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '• ${issue.code}$path\n  ${issue.message}',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

/// Long-press target for debug JSON import (title / empty card).
class NimonHiddenJsonImportLongPress extends ConsumerWidget {
  const NimonHiddenJsonImportLongPress({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!NimonImportDevConfig.jsonImportUiEnabled) {
      return child;
    }
    return GestureDetector(
      onLongPress: () =>
          unawaited(showHiddenJsonImportEntryDialog(context, ref)),
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
