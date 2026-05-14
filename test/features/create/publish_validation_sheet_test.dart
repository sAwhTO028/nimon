import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/core/validation/validation_severity.dart';
import 'package:nimon/features/create/publish_validation_sheet.dart';
import 'package:nimon/l10n/app_localizations.dart';

void main() {
  testWidgets('sheet lists blocking issues', (tester) async {
    final issues = [
      ValidationIssue(
        code: 'story.title.required',
        field: 'story.title',
        messageKey: 'story.title.required',
        severity: ValidationSeverity.blocking,
        source: 'test',
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPublishValidationSheet(
                context,
                issues: issues,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Before publishing'), findsOneWidget);
    expect(find.text('Blocking'), findsOneWidget);
    expect(find.text('Fix issues'), findsOneWidget);
  });
}
