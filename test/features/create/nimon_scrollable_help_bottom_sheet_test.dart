import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/ui/widgets/nimon_scrollable_help_bottom_sheet.dart';

void main() {
  testWidgets(
      'scrollable help sheet: no overflow on small phone, Got it visible',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final longBody = List.filled(40, 'Line of help text.').join('\n');

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2563EB),
            brightness: Brightness.dark,
          ),
        ),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showNimonScrollableHelpBottomSheet(
                      context: context,
                      title: 'How to create quiz items',
                      body: longBody,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final exc = tester.takeException();
    if (exc != null) {
      expect(exc.toString(), isNot(contains('overflowed')));
    }

    expect(find.text('Got it'), findsOneWidget);
    await tester.ensureVisible(find.text('Got it'));
    await tester.pumpAndSettle();
    final exc2 = tester.takeException();
    if (exc2 != null) {
      expect(exc2.toString(), isNot(contains('overflowed')));
    }
  });
}
