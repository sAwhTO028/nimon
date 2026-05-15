import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/search/data/mono_search_result.dart';

/// Contract for `GET /v1/search/monos` (implemented by [RemoteMonoSearchRepository]).
abstract class MonoSearchRemote {
  Future<PaginatedPage<MonoSearchResult>> searchMonos({
    String? q,
    String? level,
    String? category,
    String sort = 'latest',
    int limit = 20,
    String? cursor,
  });
}
