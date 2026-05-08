import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';
import 'package:nimon/features/mono/share_mono_link.dart';
import 'package:nimon/l10n/nimon_app_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('copies shareUrl and shows localized copy-holder success text',
      (tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final item = const MonoFeedItem(
      id: 'm1',
      writerName: 'W',
      writerHandle: '@w',
      level: 'N5',
      contentType: MonoContentType.article,
      bodyText: 'BODY_TEXT_SHOULD_NOT_BE_COPIED',
      shareUrl: 'http://localhost:3000/mono/m1',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => shareMonoLink(context, item),
              child: const Text('Share'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Share'));
    await tester.pump(); // start snackbar

    expect(copied, 'http://localhost:3000/mono/m1');
    expect(find.text(NimonAppStrings.shareLinkCopied), findsOneWidget);
  });

  testWidgets('missing shareUrl shows friendly message and does not copy body',
      (tester) async {
    int clipboardCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboardCalls++;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final item = const MonoFeedItem(
      id: 'm1',
      writerName: 'W',
      writerHandle: '@w',
      level: 'N5',
      contentType: MonoContentType.article,
      bodyText: 'BODY_TEXT_SHOULD_NOT_BE_COPIED',
      shareUrl: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => shareMonoLink(context, item),
              child: const Text('Share'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Share'));
    await tester.pump();

    expect(clipboardCalls, 0);
    expect(find.text(NimonAppStrings.shareLinkUnavailable), findsOneWidget);
  });
}
