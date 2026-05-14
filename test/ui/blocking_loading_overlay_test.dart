import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/validation/app_quota_exceeded_exception.dart';
import 'package:nimon/l10n/app_localizations.dart';
import 'package:nimon/ui/blocking_loading_overlay.dart';
import 'package:nimon/ui/quota_exceeded_dialog.dart';

void main() {
  testWidgets('blocking overlay shows spinner and message while open',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final close = showBlockingLoadingOverlay(ctx, 'Publishing…');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Publishing…'), findsOneWidget);
    close();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('quota dialog can show after overlay is dismissed',
      (tester) async {
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
    await tester.pump(const Duration(milliseconds: 50));
    final close = showBlockingLoadingOverlay(ctx, 'Publishing…');
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    close();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final dlg = showQuotaExceededDialog(
      ctx,
      const AppQuotaExceededException(
        key: 'published_mono_limit_reached',
        limit: 30,
        current: 30,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Free limit reached'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await dlg;
  });

  testWidgets('double tap does not run guarded async body twice',
      (tester) async {
    var runs = 0;
    var busy = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (ctx) {
                return FilledButton(
                  onPressed: () async {
                    if (busy) return;
                    busy = true;
                    final close = showBlockingLoadingOverlay(ctx, 'Publishing…');
                    try {
                      runs++;
                      await Future<void>.delayed(
                        const Duration(milliseconds: 80),
                      );
                    } finally {
                      busy = false;
                      close();
                    }
                  },
                  child: const Text('go'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(runs, 1);
  });
}
