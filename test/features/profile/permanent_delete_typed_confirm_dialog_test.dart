import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/presentation/permanent_delete_confirm_dialog.dart';

void main() {
  testWidgets('typed DELETE enables final permanent delete button',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PermanentDeleteTypedConfirmDialog(),
        ),
      ),
    );

    final button = find.byKey(const ValueKey('permanentDeleteFinalConfirm'));
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('permanentDeleteTypeField')),
      'DEL',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('permanentDeleteTypeField')),
      'DELETE',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });
}
