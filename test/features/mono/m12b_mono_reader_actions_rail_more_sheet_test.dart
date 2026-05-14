import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mono_screen: reader footer is fully transparent meta + action column',
      () {
    final p = File('lib/features/mono/mono_screen.dart').readAsStringSync();

    expect(p.contains('class _FooterMetaBlurCard'), isFalse);
    expect(p.contains('BackdropFilter'), isFalse);

    final frStart = p.indexOf('Widget _buildReadingFooterRow');
    expect(frStart, isNonNegative);
    final frEnd = p.indexOf('@override', frStart + 1);
    expect(frEnd, greaterThan(frStart));
    final fr = p.substring(frStart, frEnd);

    expect(fr.contains('Row('), isTrue);
    expect(
        fr.contains('crossAxisAlignment: CrossAxisAlignment.center'), isTrue);
    expect(fr.contains('Expanded(child: meta)'), isTrue);
    expect(fr.contains('_MonoFooterTransparentActionColumn('), isTrue);
    expect(fr.contains('Stack('), isFalse);
    expect(fr.contains('Positioned('), isFalse);
    expect(fr.contains('DecoratedBox'), isFalse);
    expect(fr.contains('ClipRRect'), isFalse);
    expect(fr.contains('_FooterMetaBlurCard'), isFalse);
    expect(fr.contains('_FooterMetaReactCard'), isFalse);
    expect(fr.contains('_MonoFooterReactColumn'), isFalse);

    expect(
      RegExp(r'_FooterReaderIconActionButton\(').allMatches(fr).length,
      0,
    );

    final colStart = p.indexOf('class _MonoFooterTransparentActionColumn');
    final colEnd = p.indexOf('class _FooterReaderIconActionButton', colStart);
    expect(colStart, isNonNegative);
    expect(colEnd, greaterThan(colStart));
    final col = p.substring(colStart, colEnd);
    expect(col.contains('DecoratedBox'), isFalse);
    expect(col.contains("semanticsLabel: 'More actions'"), isTrue);
    expect(col.contains('Icons.more_horiz'), isTrue);
    expect(col.contains('Icons.favorite'), isTrue);
    expect(
      RegExp(r'_FooterReaderIconActionButton\(').allMatches(col).length,
      2,
    );
    expect(col.contains('if (showCount)'), isTrue);

    final groupedStart = p.indexOf('class _MonoGroupedBackgroundContent');
    final groupedEnd = p.indexOf('class _ReadingFeedPost', groupedStart);
    final grouped = p.substring(groupedStart, groupedEnd);
    expect(grouped.contains('final Widget footerRow'), isTrue);
    expect(grouped.contains('learnGroup'), isFalse);
    expect(grouped.contains('metaGroup'), isFalse);

    expect(p.contains('_slotH * 2'), isFalse);
    expect(p.contains('class _BottomActionRail'), isFalse);
  });

  test('mono_screen: shared footer icon button uses equal slot + light ink',
      () {
    final p = File('lib/features/mono/mono_screen.dart').readAsStringSync();
    final s = p.indexOf('class _FooterReaderIconActionButton');
    final e = p.length;
    expect(s, isNonNegative);
    final block = p.substring(s, e);
    expect(block.contains('static const kSlotSize = 44.0'), isTrue);
    expect(block.contains('static const kIconSize = 24.0'), isTrue);
    expect(block.contains('NoSplash.splashFactory'), isTrue);
    expect(block.contains('width: kSlotSize'), isTrue);
    expect(block.contains('height: kSlotSize'), isTrue);
  });

  test('mono_screen: read mode has no arrow-FAB action toggle', () {
    final p = File('lib/features/mono/mono_screen.dart').readAsStringSync();
    expect(p.contains('_ReadModeLearnGroupCollapsible'), isFalse);
    expect(p.contains('Hide actions'), isFalse);
  });

  test('mono_screen: More sheet gates Learn on Full Learn publish', () {
    final p = File('lib/features/mono/mono_screen.dart').readAsStringSync();
    expect(p.contains("'Mono actions'"), isTrue);
    expect(p.contains("title: 'Learn this story'"), isTrue);
    expect(p.contains('p?.isFullLearnPublished == true'), isTrue);
  });

  test('mono_screen: footer meta is compact (no handle / no description)', () {
    final p = File('lib/features/mono/mono_screen.dart').readAsStringSync();

    final metaStart = p.indexOf('class _PostFooterMeta');
    final metaEnd = p.indexOf('class _MonoStatusChip', metaStart);
    expect(metaStart, isNonNegative);
    expect(metaEnd, greaterThan(metaStart));

    final meta = p.substring(metaStart, metaEnd);
    expect(meta.contains('writerHandle'), isFalse);
    expect(meta.contains('ExpandableFooterDescription'), isFalse);
    expect(meta.contains('storyDescription'), isFalse);
    expect(meta.contains('Read only'), isTrue);
    expect(meta.contains('Full Learn'), isTrue);
    expect(meta.contains('_FooterFollowButton'), isTrue);
    expect(meta.contains('static const _metaColumnTopInset = 6.0'), isTrue);
    expect(
      meta.contains('const SizedBox(height: _metaColumnTopInset)'),
      isTrue,
    );
    expect(meta.contains('static const _metaNameToTitleGap = 6.0'), isTrue);
    expect(meta.contains('static const _metaTitleToChipGap = 5.0'), isTrue);
    expect(
      meta.contains('const SizedBox(height: _metaNameToTitleGap)'),
      isTrue,
    );
    expect(
      meta.contains('const SizedBox(height: _metaTitleToChipGap)'),
      isTrue,
    );
    expect(meta.contains('fontWeight: FontWeight.w800'), isTrue);
    expect(meta.contains('fontSize: 15'), isTrue);
    expect(meta.contains('fontSize: 12.5'), isTrue);
    expect(
        meta.contains('crossAxisAlignment: CrossAxisAlignment.center'), isTrue);
    expect(
      RegExp(r'child:\s*_WriterFooterAvatar\b').allMatches(meta).length,
      1,
    );
    expect(meta.contains('padding: const EdgeInsets.only(bottom:'), isFalse);
  });

  test('mono_screen: single More icon in mono_screen footer composition', () {
    final p = File('lib/features/mono/mono_screen.dart').readAsStringSync();
    expect(RegExp(r'Icons\.more_horiz').allMatches(p).length, 1);
    expect(p.contains('class _MonoFooterTransparentActionColumn'), isTrue);
    expect(p.contains('class _FooterReaderIconActionButton'), isTrue);
  });

  test('mono_screen: footer follow button compact (size + radius)', () {
    final p = File('lib/features/mono/mono_screen.dart').readAsStringSync();
    final s = p.indexOf('class _FooterFollowButtonState');
    final e = p.indexOf('class _MonoFooterTransparentActionColumn', s);
    expect(s, isNonNegative);
    expect(e, greaterThan(s));
    final fb = p.substring(s, e);
    expect(fb.contains('BorderRadius.circular(999)'), isFalse);
    expect(fb.contains('BorderRadius.circular(followRadius)'), isTrue);
    expect(fb.contains('const followRadius = 10.0'), isTrue);
    expect(fb.contains('84.0'), isTrue);
    expect(fb.contains('68.0'), isTrue);
    expect(fb.contains('Size(0, 28)'), isTrue);
    expect(fb.contains('fontSize: 12'), isTrue);
    expect(fb.contains("'Following'"), isTrue);
    expect(fb.contains("'Follow'"), isTrue);

    expect(fb.contains('OutlinedButton'), isTrue);
    expect(fb.contains('FilledButton'), isTrue);
    expect(fb.contains('_MonoStatusChip.kSurfaceAlpha'), isTrue);
    expect(fb.contains('_MonoStatusChip.kBorderAlpha'), isTrue);
    expect(fb.contains('followingFg'), isTrue);
    expect(fb.contains('followingBg'), isTrue);
    expect(fb.contains('followBg'), isTrue);
    expect(fb.contains('followFg'), isTrue);
    expect(
      RegExp(r'if \(isFollowing\)[\s\S]*OutlinedButton').hasMatch(fb),
      isTrue,
    );
  });
}
