import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/profile/mono_story_list_row.dart';
import 'package:nimon/features/profile/public_profile_widgets.dart';
import 'package:nimon/ui/nimon_default_cover_asset.dart';
import 'package:nimon/ui/nimon_story_cover_image.dart';

bool _treeHasDefaultAssetImage(WidgetTester tester) {
  for (final img in tester.widgetList<Image>(find.byType(Image))) {
    final p = img.image;
    if (p is AssetImage && p.assetName == nimonDefaultStoryCoverAsset) {
      return true;
    }
  }
  return false;
}

bool _treeHasNetworkImage(WidgetTester tester) {
  for (final img in tester.widgetList<Image>(find.byType(Image))) {
    if (img.image is NetworkImage) return true;
  }
  return false;
}

void main() {
  group('NimonStoryCoverImage.hasUsableCoverUrl', () {
    test('null empty whitespace', () {
      expect(NimonStoryCoverImage.hasUsableCoverUrl(null), isFalse);
      expect(NimonStoryCoverImage.hasUsableCoverUrl(''), isFalse);
      expect(NimonStoryCoverImage.hasUsableCoverUrl('   '), isFalse);
      expect(NimonStoryCoverImage.hasUsableCoverUrl(' https://x '), isTrue);
    });
  });

  testWidgets('null cover URL shows default asset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NimonStoryCoverImage(
            coverImageUrl: null,
            width: 48,
            height: 64,
          ),
        ),
      ),
    );
    expect(_treeHasDefaultAssetImage(tester), isTrue);
    expect(_treeHasNetworkImage(tester), isFalse);
  });

  testWidgets('empty cover URL shows default asset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NimonStoryCoverImage(
            coverImageUrl: '',
            width: 48,
            height: 64,
          ),
        ),
      ),
    );
    expect(_treeHasDefaultAssetImage(tester), isTrue);
  });

  testWidgets('whitespace cover URL shows default asset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NimonStoryCoverImage(
            coverImageUrl: ' \t ',
            width: 48,
            height: 64,
          ),
        ),
      ),
    );
    expect(_treeHasDefaultAssetImage(tester), isTrue);
  });

  testWidgets('valid cover URL uses network image', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NimonStoryCoverImage(
            coverImageUrl: 'https://example.com/cover.png',
            width: 48,
            height: 64,
          ),
        ),
      ),
    );
    expect(_treeHasNetworkImage(tester), isTrue);
  });

  testWidgets('network image error falls back to default asset',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NimonStoryCoverImage(
            coverImageUrl: 'http://127.0.0.1:9/__nimon_cover_fail_test__',
            width: 48,
            height: 64,
          ),
        ),
      ),
    );
    expect(_treeHasNetworkImage(tester), isTrue);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(_treeHasDefaultAssetImage(tester), isTrue);
  });

  testWidgets(
      'profile MonoStoryListRow with missing cover renders default asset',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MonoStoryListRow(
            title: 'Title',
            description: 'Body',
            jlptLevel: 'N5',
            thumbnailUrl: null,
          ),
        ),
      ),
    );
    expect(find.byType(PublicStoryThumb), findsOneWidget);
    expect(_treeHasDefaultAssetImage(tester), isTrue);
  });
}
