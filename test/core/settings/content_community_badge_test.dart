import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/settings/content_community.dart';

void main() {
  group('contentCommunityBadgeShortLabel', () {
    test('maps my en ja wire codes', () {
      expect(contentCommunityBadgeShortLabel('my'), 'MY');
      expect(contentCommunityBadgeShortLabel('en'), 'EN');
      expect(contentCommunityBadgeShortLabel('ja'), 'JA');
    });

    test('null and empty return legacy dash', () {
      expect(contentCommunityBadgeShortLabel(null), '—');
      expect(contentCommunityBadgeShortLabel(''), '—');
      expect(contentCommunityBadgeShortLabel('  '), '—');
    });

    test('unknown values return legacy dash', () {
      expect(contentCommunityBadgeShortLabel('th'), '—');
    });
  });
}
