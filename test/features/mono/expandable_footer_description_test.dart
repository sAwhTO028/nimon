import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/mono/expandable_footer_description.dart';

Widget _pumpHarness({
  required Widget child,
  double width = 200,
}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

TextStyle _footerStyle(ThemeData theme) {
  final base = theme.textTheme.labelSmall ?? const TextStyle();
  return base.copyWith(
    color: Colors.grey,
    fontWeight: FontWeight.w600,
    fontSize: 10.5,
    letterSpacing: 0.15,
  );
}

void main() {
  group('ExpandableFooterDescription.textExceedsPreviewLines', () {
    test('empty text never exceeds', () {
      expect(
        ExpandableFooterDescription.textExceedsPreviewLines(
          text: '   ',
          style: const TextStyle(fontSize: 10.5),
          maxWidth: 100,
        ),
        isFalse,
      );
    });

    test('non-positive width returns false', () {
      expect(
        ExpandableFooterDescription.textExceedsPreviewLines(
          text: 'Hello world',
          style: const TextStyle(fontSize: 10.5),
          maxWidth: 0,
        ),
        isFalse,
      );
    });

    test('very narrow width makes a medium string exceed two lines', () {
      const style = TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600);
      final long = List.filled(30, 'word').join(' ');
      expect(
        ExpandableFooterDescription.textExceedsPreviewLines(
          text: long,
          style: style,
          maxWidth: 40,
        ),
        isTrue,
      );
    });
  });

  testWidgets('empty description hides control (no See more)', (tester) async {
    await tester.pumpWidget(
      _pumpHarness(
        child: const ExpandableFooterDescription(
          text: '',
          inkMuted: Color(0xFF888888),
        ),
      ),
    );
    expect(find.text('See more'), findsNothing);
    expect(find.text('See less'), findsNothing);
  });

  testWidgets('short description shows text without See more', (tester) async {
    await tester.pumpWidget(
      _pumpHarness(
        width: 280,
        child: const ExpandableFooterDescription(
          text: 'Short basics.',
          inkMuted: Color(0xFF888888),
        ),
      ),
    );
    expect(find.text('Short basics.'), findsOneWidget);
    expect(find.text('See more'), findsNothing);
  });

  testWidgets('long description shows See more when collapsed', (tester) async {
    final long = List.filled(40, 'clause').join(' ');
    await tester.pumpWidget(
      _pumpHarness(
        width: 90,
        child: ExpandableFooterDescription(
          text: long,
          inkMuted: const Color(0xFF888888),
        ),
      ),
    );
    expect(find.text('See more'), findsOneWidget);
    expect(find.text('See less'), findsNothing);
  });

  testWidgets('tap See more expands and shows See less', (tester) async {
    final long = List.filled(40, 'clause').join(' ');
    await tester.pumpWidget(
      _pumpHarness(
        width: 90,
        child: ExpandableFooterDescription(
          text: long,
          inkMuted: const Color(0xFF888888),
        ),
      ),
    );
    await tester.tap(find.text('See more'));
    await tester.pumpAndSettle();
    expect(find.text('See less'), findsOneWidget);
    expect(find.text('See more'), findsNothing);
  });

  testWidgets('tap See less collapses back', (tester) async {
    final long = List.filled(40, 'clause').join(' ');
    await tester.pumpWidget(
      _pumpHarness(
        width: 90,
        child: ExpandableFooterDescription(
          text: long,
          inkMuted: const Color(0xFF888888),
        ),
      ),
    );
    await tester.tap(find.text('See more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See less'));
    await tester.pumpAndSettle();
    expect(find.text('See more'), findsOneWidget);
    expect(find.text('See less'), findsNothing);
  });

  testWidgets('measurement matches widget style for overflow decision',
      (tester) async {
    final theme = ThemeData(useMaterial3: true);
    final style = _footerStyle(theme);
    final long = List.filled(40, 'clause').join(' ');
    final exceeds = ExpandableFooterDescription.textExceedsPreviewLines(
      text: long,
      style: style,
      maxWidth: 90,
    );
    await tester.pumpWidget(
      _pumpHarness(
        width: 90,
        child: ExpandableFooterDescription(
          text: long,
          inkMuted: const Color(0xFF888888),
        ),
      ),
    );
    expect(find.text('See more'), exceeds ? findsOneWidget : findsNothing);
  });
}
