import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/learn/learn_creator_module_tokens.dart';

void main() {
  testWidgets('learnCreatorModule tokens track ColorScheme (dark)', (
    tester,
  ) async {
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: Brightness.dark,
    );

    late Color primary;
    late Color secondary;
    late Color cardBg;
    late Color border;
    late Color action;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: darkScheme,
        ),
        home: Builder(
          builder: (context) {
            primary = learnCreatorModulePrimaryTextColor(context);
            secondary = learnCreatorModuleSecondaryTextColor(context);
            cardBg = learnCreatorModuleCardSurfaceColor(context);
            border = learnCreatorModuleCardBorderColor(context);
            action = learnCreatorModuleActionForegroundColor(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(primary, equals(darkScheme.onSurface));
    expect(secondary, equals(darkScheme.onSurfaceVariant));
    expect(cardBg, equals(darkScheme.surface));
    expect(border, equals(darkScheme.outlineVariant));
    expect(action, equals(darkScheme.primary));
  });
}
