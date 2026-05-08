import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/public_profile_screen.dart';

void main() {
  testWidgets('Public profile does not expose Edit profile action',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PublicProfileScreen(
            ownerPreview: false,
            userId: 'someone-else',
          ),
        ),
      ),
    );
    // Avoid pumpAndSettle: PublicProfileScreen can keep a scroll listener and
    // async loaders alive; we only need a single frame to assert UI text absence.
    await tester.pump(const Duration(milliseconds: 200));

    // Owner-only entry point lives in owner profile drawer; public profile should not show it.
    expect(find.text('Edit profile'), findsNothing);
  });
}
