import 'package:flutter/material.dart';
import 'package:nimon/core/validation/localized_validation_messages.dart';
import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/core/validation/validation_severity.dart';
import 'package:nimon/l10n/app_localizations.dart';

/// Review blocking/recommended issues before or after a publish attempt.
///
/// Returns `true` when the user chooses **Publish anyway** (warning-only flows).
/// Returns `false` when the user dismisses or taps **Fix issues**.
Future<bool> showPublishValidationSheet(
  BuildContext context, {
  required List<ValidationIssue> issues,
  bool showPublishAnyway = false,
}) async {
  final blocking =
      issues.where((i) => i.severity == ValidationSeverity.blocking).toList();
  final recommended =
      issues.where((i) => i.severity != ValidationSeverity.blocking).toList();
  final allowAnyway =
      showPublishAnyway && blocking.isEmpty && recommended.isNotEmpty;

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final l10n = AppLocalizations.of(ctx)!;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: 16 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.validationPublishSheetTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (blocking.isNotEmpty) ...[
                  Text(
                    l10n.validationPublishSectionBlocking,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...blocking.map((i) => _PublishIssueTile(issue: i)),
                ],
                if (recommended.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.validationPublishSectionRecommended,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...recommended.map((i) => _PublishIssueTile(issue: i)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Fix issues'),
                ),
                if (allowAnyway) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Publish anyway'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}

class _PublishIssueTile extends StatelessWidget {
  const _PublishIssueTile({required this.issue});

  final ValidationIssue issue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = validationFieldLabelLocalized(context, issue.field);
    final body = validationIssueDisplayMessageLocalized(context, issue);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
