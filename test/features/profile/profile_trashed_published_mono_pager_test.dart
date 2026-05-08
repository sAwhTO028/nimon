import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/page_result.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';
import 'package:nimon/features/profile/data/remote_published_mono_repository.dart';
import 'package:nimon/features/profile/presentation/providers/profile_trashed_published_mono_pager.dart';

PublishedMonoListItemDto get _one => PublishedMonoListItemDto(
      id: 'pm_t',
      ownerId: 'o',
      sourceDraftId: null,
      title: 'Trashed row',
      category: 'c',
      level: 'N5',
      description: 'd',
      publishKind: null,
      displayPublishKind: 'read_only',
      coverImageUrl: null,
      targetDurationLabel: null,
      createdAt: '2026-01-01T00:00:00Z',
      updatedAt: '2026-01-02T00:00:00Z',
      contentSummary: null,
      trashedAt: '2026-01-05T08:00:00Z',
    );

class _StubTrashedRepo extends RemotePublishedMonoRepository {
  _StubTrashedRepo(this._fetch)
      : super(
          apiBaseUrl: 'http://stub.test',
          client: MockClient(
            (_) async => http.Response('internal stub', 500),
          ),
        );

  final Future<PageResult<PublishedMonoListItemDto>> Function(PageRequest r)
      _fetch;

  @override
  Future<PageResult<PublishedMonoListItemDto>> fetchTrashedPage(
    PageRequest request,
  ) {
    return _fetch(request);
  }
}

void main() {
  group('ProfileTrashedPublishedMonoPager', () {
    test('loadFirstPage loads trash rows', () async {
      final stub = _StubTrashedRepo((_) async {
        return PageResult<PublishedMonoListItemDto>(
          items: [_one],
          nextCursor: null,
          hasMore: false,
        );
      });
      final p = ProfileTrashedPublishedMonoPager(stub);
      await p.loadFirstPage();
      expect(p.state.items.single.id, 'pm_t');
      expect(p.state.items.single.trashedAt, isNotEmpty);
    });
  });
}
