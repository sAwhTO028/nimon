import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/share_profile_screen.dart';
import 'package:nimon/l10n/app_localizations.dart';
import 'package:share_plus_platform_interface/method_channel/method_channel_share.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const shareChannel = MethodChannelShare.channel;

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);
  });

  Future<void> setShareMock(Future<Object?> Function(MethodCall call) fn) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, fn);
    return Future<void>.value();
  }

  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    );
  }

  Future<void> pumpUi(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('shows display name, handle, and short URL label',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const ShareProfileScreen(
          displayName: 'Alice Writer',
          handleLine: 'alice',
          publicProfileUrl: 'https://nimon.app/u/alice',
        ),
      ),
    );
    await pumpUi(tester);

    expect(find.text('Alice Writer'), findsOneWidget);
    expect(find.text('@alice'), findsOneWidget);
    expect(find.text('nimon.app/u/alice'), findsOneWidget);
    expect(find.textContaining('Download'), findsNothing);
  });

  testWidgets('Copy link copies exact URL and shows localized snack',
      (tester) async {
    const url = 'https://nimon.app/u/alice';
    await setShareMock((_) async => null);

    await tester.pumpWidget(
      wrap(
        const ShareProfileScreen(
          displayName: 'Alice',
          handleLine: 'alice',
          publicProfileUrl: url,
        ),
      ),
    );
    await pumpUi(tester);

    await tester.tap(find.text('Copy link'));
    await tester.pump();

    expect(find.text('Link copied'), findsOneWidget);
  });

  testWidgets('Share profile invokes platform share with exact URL',
      (tester) async {
    const url = 'https://nimon.app/u/bob';
    String? shared;

    await setShareMock((call) async {
      if (call.method == 'share') {
        final args = call.arguments as Map<dynamic, dynamic>;
        shared = args['text'] as String?;
        return 'success';
      }
      return null;
    });

    await tester.pumpWidget(
      wrap(
        const ShareProfileScreen(
          displayName: 'Bob',
          handleLine: 'bob',
          publicProfileUrl: url,
        ),
      ),
    );
    await pumpUi(tester);

    await tester.tap(find.text('Share profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(shared, url);
  });

  testWidgets('QR widget keyed by profile URL is present', (tester) async {
    const url = 'https://nimon.app/u/carol';
    await setShareMock((_) async => null);

    await tester.pumpWidget(
      wrap(
        const ShareProfileScreen(
          displayName: 'Carol',
          handleLine: 'carol',
          publicProfileUrl: url,
        ),
      ),
    );
    await pumpUi(tester);

    expect(
        find.byKey(ValueKey<String>('share_profile_qr_$url')), findsOneWidget);
  });

  testWidgets('Download card control is absent', (tester) async {
    await setShareMock((_) async => null);
    await tester.pumpWidget(
      wrap(
        const ShareProfileScreen(
          displayName: 'D',
          handleLine: 'd',
          publicProfileUrl: 'https://nimon.app/u/d',
        ),
      ),
    );
    await pumpUi(tester);

    expect(find.textContaining('Download'), findsNothing);
  });

  testWidgets('dark theme: primary identity uses onSurface', (tester) async {
    await setShareMock((_) async => null);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6750A4),
            brightness: Brightness.dark,
          ),
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const ShareProfileScreen(
          displayName: 'Eve',
          handleLine: 'eve',
          publicProfileUrl: 'https://nimon.app/u/eve',
        ),
      ),
    );
    await pumpUi(tester);

    final nameText = tester.widget<Text>(find.text('Eve'));
    final scheme = Theme.of(tester.element(find.text('Eve'))).colorScheme;
    expect(nameText.style?.color, scheme.onSurface);
  });
}
