import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/profile_trash_screen.dart';

void main() {
  testWidgets('Trash screen explains remote gate when drafts are off',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ProfileTrashScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Trash is available when remote drafts are enabled.'),
      findsOneWidget,
    );
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('Trash is empty'), findsNothing);
    expect(find.textContaining('Permanently delete'), findsNothing);
  });
}
