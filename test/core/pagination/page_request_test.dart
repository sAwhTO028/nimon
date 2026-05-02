import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/pagination/page_request.dart';
import 'package:nimon/core/pagination/pagination_defaults.dart';

void main() {
  group('PageRequest', () {
    test('defaults: limit and sort', () {
      final r = PageRequest();
      expect(r.limit, PaginationDefaults.defaultPageLimit);
      expect(r.sort, 'latest');
      expect(r.cursor, isNull);
    });

    test('limit clamped to min', () {
      final r = PageRequest(limit: 0);
      expect(r.limit, PaginationDefaults.minPageLimit);
    });

    test('limit clamped to max', () {
      final r = PageRequest(limit: 999);
      expect(r.limit, PaginationDefaults.maxPageLimit);
    });

    test('toQueryParameters omits null and empty strings', () {
      final r = PageRequest(
        cursor: 'abc',
        query: '',
        level: 'N5',
        publishState: 'draft',
      );
      final q = r.toQueryParameters();
      expect(q.containsKey('cursor'), isTrue);
      expect(q['cursor'], 'abc');
      expect(q.containsKey('query'), isFalse);
      expect(q['level'], 'N5');
      expect(q['publishState'], 'draft');
      expect(q['limit'], '20');
      expect(q['sort'], 'latest');
    });

    test('updatedAfter serialized as ISO-8601 UTC', () {
      final dt = DateTime.utc(2026, 1, 15, 12, 30);
      final r = PageRequest(updatedAfter: dt);
      final q = r.toQueryParameters();
      expect(q['updatedAfter'], dt.toUtc().toIso8601String());
    });

    test('copyWith preserves fields and can set cursor to null', () {
      final a = PageRequest(cursor: 'x', limit: 10, sort: 'popular');
      final b = a.copyWith(cursor: null);
      expect(b.cursor, isNull);
      expect(b.limit, 10);
      expect(b.sort, 'popular');
    });

    test('copyWith can change limit with re-clamp', () {
      final a = PageRequest(limit: 20);
      final b = a.copyWith(limit: 100);
      expect(b.limit, PaginationDefaults.maxPageLimit);
    });
  });
}
