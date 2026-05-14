import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/validation/app_quota_exceeded_exception.dart';
import 'package:nimon/l10n/app_localizations.dart';
import 'package:nimon/ui/quota_exceeded_dialog.dart';

void main() {
  testWidgets('showQuotaExceededDialog shows draft limit copy', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final future = showQuotaExceededDialog(
      ctx,
      const AppQuotaExceededException(
        key: 'draft_story_limit_reached',
        limit: 50,
        current: 50,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Draft limit reached'), findsOneWidget);
    expect(find.textContaining('50'), findsWidgets);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await future;
  });
}
