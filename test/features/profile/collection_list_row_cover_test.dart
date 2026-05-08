import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/public_profile_widgets.dart';

void main() {
  testWidgets(
      'CollectionListRow renders network image when coverImageUrl exists',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: CollectionListRow(
            title: 'T',
            countLabel: '1 story',
            coverImageUrl: 'https://img.test/x.png',
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
  });
}
