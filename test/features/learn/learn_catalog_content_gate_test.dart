import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/learn/learn_catalog_content_gate.dart'
    show
        catalogMonoIdLooksLikeUuid,
        learnDemoMocksAllowed,
        normalizeCatalogMonoIdForUuidCheck;
import 'package:nimon/features/mono/mono_feed_models.dart';

void main() {
  const uuid = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';

  test('normalizeCatalogMonoIdForUuidCheck strips profile prefix', () {
    expect(
      normalizeCatalogMonoIdForUuidCheck(
        '$kProfilePublishedMonoFeedItemIdPrefix$uuid',
      ),
      uuid,
    );
  });

  test('catalogMonoIdLooksLikeUuid true for profile-prefixed catalog uuid', () {
    expect(
      catalogMonoIdLooksLikeUuid(
        '$kProfilePublishedMonoFeedItemIdPrefix$uuid',
      ),
      isTrue,
    );
  });

  test('learnDemoMocksAllowed false for profile-prefixed catalog uuid', () {
    expect(
      learnDemoMocksAllowed(
        '$kProfilePublishedMonoFeedItemIdPrefix$uuid',
      ),
      isFalse,
    );
  });
}
