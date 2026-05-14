import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/presentation/profile_workspace_section_header.dart';

void main() {
  testWidgets('Workspace section headers: visible, not pure black in dark mode',
      (tester) async {
    final dark = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: Brightness.dark,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: dark,
        home: Scaffold(
          body: ListView(
            children: const [
              ProfileWorkspaceSectionHeader(title: 'Drafts'),
              SizedBox(height: 8),
              ProfileWorkspaceSectionHeader(title: 'Editing'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('DRAFTS'), findsOneWidget);
    expect(find.text('EDITING'), findsOneWidget);

    final drafts = tester.widget<Text>(find.text('DRAFTS'));
    final editing = tester.widget<Text>(find.text('EDITING'));
    expect(drafts.style?.color, isNot(equals(const Color(0xFF000000))));
    expect(editing.style?.color, isNot(equals(const Color(0xFF000000))));
    expect((drafts.style?.color ?? Colors.transparent).a, greaterThan(0.35));
    expect((editing.style?.color ?? Colors.transparent).a, greaterThan(0.35));

    final exc = tester.takeException();
    if (exc != null) {
      expect(exc.toString(), isNot(contains('overflowed')));
    }
  });
}
