import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/settings/content_community.dart';

void main() {
  test('collection badge uses MIX for null legacy', () {
    expect(contentCommunityCollectionBadgeShortLabel(null), 'MIX');
    expect(contentCommunityCollectionBadgeShortLabel('my'), 'MY');
  });
}
