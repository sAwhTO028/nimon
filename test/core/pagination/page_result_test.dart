import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/pagination/page_result.dart';

void main() {
  group('PageResult', () {
    test('empty factory', () {
      final p = PageResult<int>.empty();
      expect(p.items, isEmpty);
      expect(p.hasMore, isFalse);
      expect(p.nextCursor, isNull);
      expect(p.totalCount, isNull);
    });

    test('map transforms items', () {
      const p = PageResult<int>(
        items: [1, 2, 3],
        nextCursor: 'c1',
        hasMore: true,
        totalCount: 100,
      );
      final m = p.map((i) => 'n$i');
      expect(m.items, ['n1', 'n2', 'n3']);
      expect(m.nextCursor, 'c1');
      expect(m.hasMore, isTrue);
      expect(m.totalCount, 100);
    });

    test('append combines items and adopts trailing cursor', () {
      const a = PageResult<int>(
        items: [1, 2],
        nextCursor: 'c1',
        hasMore: true,
        totalCount: 10,
      );
      const b = PageResult<int>(
        items: [3, 4],
        nextCursor: 'c2',
        hasMore: false,
        totalCount: null,
      );
      final c = a.append(b);
      expect(c.items, [1, 2, 3, 4]);
      expect(c.nextCursor, 'c2');
      expect(c.hasMore, isFalse);
      expect(c.totalCount, 10);
    });

    test('append prefers next totalCount when present', () {
      const a = PageResult<int>(
        items: [1],
        nextCursor: null,
        hasMore: true,
        totalCount: 5,
      );
      const b = PageResult<int>(
        items: [2],
        nextCursor: null,
        hasMore: false,
        totalCount: 99,
      );
      expect(a.append(b).totalCount, 99);
    });
  });
}
