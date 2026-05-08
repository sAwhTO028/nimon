import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/mono/mono_reader_dock.dart';

void main() {
  testWidgets('MonoReaderDock shows owner menu when onMenu set',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonoReaderDock(
            onAddMono: () {},
            onMenu: () {},
          ),
        ),
      ),
    );
    expect(find.text('Add Mono +'), findsOneWidget);
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
  });

  testWidgets(
      'MonoReaderDock hides circular menu for learner/public (onMenu null)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonoReaderDock(
            onAddMono: () {},
            onMenu: null,
          ),
        ),
      ),
    );
    expect(find.text('Add Mono +'), findsOneWidget);
    expect(find.byIcon(Icons.menu_rounded), findsNothing);
  });
}
