import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/media/media_upload_error_mapper.dart';
import 'package:nimon/core/validation/http_validation_failed_exception.dart';
import 'package:nimon/core/validation/localized_validation_messages.dart';
import 'package:nimon/core/validation/validation_issue.dart';
import 'package:nimon/core/validation/validation_severity.dart';
import 'package:nimon/l10n/app_localizations.dart';

void main() {
  group('validationMessageKeyLocalized', () {
    testWidgets('known key returns English localized string', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final s = validationMessageKeyLocalized(ctx, 'auth.email.required');
      expect(s, AppLocalizations.of(ctx)!.validationAuthEmailRequired);
    });

    testWidgets('unknown key falls back safely', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        validationMessageKeyLocalized(ctx, 'totally.unknown.key.xyz'),
        validationUnknownFieldMessage,
      );
    });

    testWidgets('interpolates min/max params via l10n', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final out = validationMessageKeyLocalized(
        ctx,
        'learn.count.vocab.range',
        params: {'min': 1, 'max': 10, 'actual': 3},
      );
      expect(out, contains('1'));
      expect(out, contains('10'));
      expect(out, contains('3'));
    });
  });

  testWidgets('mediaUploadUserMessageLocalized maps image invalid type',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final ex = HttpValidationFailedException([
      ValidationIssue(
        code: 'm',
        field: 'file',
        messageKey: 'media.image.invalidType',
        severity: ValidationSeverity.blocking,
      ),
    ]);
    expect(
      mediaUploadUserMessageLocalized(ctx, ex,
          surface: MediaUploadSurface.storyCover),
      AppLocalizations.of(ctx)!.validationMediaImageInvalidType,
    );
  });
}
