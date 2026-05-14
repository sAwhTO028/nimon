import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/widgets/creator_fit_info_bottom_sheet.dart';
import 'package:nimon/features/create/widgets/creator_info_bottom_sheet.dart';
import 'package:nimon/ui/widgets/nimon_scrollable_help_bottom_sheet.dart';

double _logicalHeight(WidgetTester tester) =>
    tester.view.physicalSize.height / tester.view.devicePixelRatio;

Future<void> _pumpOpenSheet(
  WidgetTester tester, {
  required VoidCallback onOpen,
}) async {
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
      home: Scaffold(
        body: Center(
          child: TextButton(
            onPressed: onOpen,
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void _assertHandleAlignedToSheet(WidgetTester tester) {
  final sheetTop =
      tester.getTopLeft(find.byKey(creatorFitInfoBottomSheetKey)).dy;
  final handleTop =
      tester.getTopLeft(find.byKey(creatorFitInfoBottomSheetHandleKey)).dy;
  expect(handleTop, greaterThanOrEqualTo(sheetTop + 6));
  expect(handleTop, lessThan(sheetTop + 32));
}

void _assertNoOverflow(WidgetTester tester) {
  final exc = tester.takeException();
  if (exc != null) {
    expect(exc.toString(), isNot(contains('overflowed')));
  }
}

void main() {
  testWidgets('Vocabulary info handle sits inside sheet, sheet stays short', (
    tester,
  ) async {
    await _pumpOpenSheet(
      tester,
      onOpen: () => showCreatorFitInfoBottomSheet(
        context: tester.element(find.text('Open')),
        title: 'How to add vocabulary / kanji',
        children: const [
          CreatorInfoBulletColumn(
            lines: [
              'Tap Add entry.',
              'Select a word or phrase from the story.',
            ],
          ),
        ],
      ),
    );

    final h = _logicalHeight(tester);
    final sheet = tester.getSize(find.byKey(creatorFitInfoBottomSheetKey));
    expect(sheet.height, lessThan(h * 0.70));
    _assertHandleAlignedToSheet(tester);
    _assertNoOverflow(tester);
  });

  testWidgets('Quiz info handle sits inside sheet, sheet stays short', (
    tester,
  ) async {
    await _pumpOpenSheet(
      tester,
      onOpen: () => showNimonScrollableHelpBottomSheet(
        context: tester.element(find.text('Open')),
        title: 'How to create quiz items',
        body: 'Short body for test.',
      ),
    );

    final h = _logicalHeight(tester);
    final sheet = tester.getSize(find.byKey(creatorFitInfoBottomSheetKey));
    expect(sheet.height, lessThanOrEqualTo(h * 0.80 + 1));
    _assertHandleAlignedToSheet(tester);
    _assertNoOverflow(tester);
  });
}
