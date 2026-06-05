import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/core/settings/catalog_discovery_lens.dart';
import 'package:nimon/features/mono/data/mono_feed_summary_dto.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';

/// Public Mono catalog — no owner scope (see `GET /v1/mono/feed`).
abstract class MonoFeedRepository {
  Future<PageResult<MonoFeedSummaryDto>> fetchFeedPage(
    PageRequest request, {
    String? level,
    String? category,
    CatalogDiscoveryLens? catalogLens,
  });

  Future<PublishedMonoDetailDto> fetchMonoDetail(String monoId);
}
