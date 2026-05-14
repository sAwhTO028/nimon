// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also read widget properties with the WidgetTester.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/main.dart';

import 'auth/in_memory_auth_token_store.dart';

void main() {
  testWidgets('App boots to login after auth bootstrap',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authTokenStoreProvider.overrideWithValue(InMemoryAuthTokenStore()),
        ],
        child: const NimonApp(),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('Great!').evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.widgetWithText(FilledButton, 'LOGIN'), findsOneWidget);
  });
}
