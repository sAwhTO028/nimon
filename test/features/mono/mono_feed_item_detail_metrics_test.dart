import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/mono/mono_feed_item_detail_metrics.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';

void main() {
  test('likes uses server count not fake default', () {
    const item = MonoFeedItem(
      id: 'm1',
      writerName: 'W',
      writerHandle: '@w',
      level: 'N5',
      contentType: MonoContentType.article,
      bodyText: '',
      likesCount: 42,
      catalogCategory: 'Travel',
      readDurationLabel: '5–7 min',
    );
    expect(monoDetailSheetLikesValue(item), '42');
  });

  test('read time prefers server label over placeholder', () {
    const item = MonoFeedItem(
      id: 'm1',
      writerName: 'W',
      writerHandle: '@w',
      level: 'N5',
      contentType: MonoContentType.article,
      bodyText: '',
      readDurationLabel: '3–5 min',
    );
    expect(monoDetailSheetReadTimeValue(item), '3–5 min');
  });

  test('read time shows em dash when no label', () {
    const item = MonoFeedItem(
      id: 'm1',
      writerName: 'W',
      writerHandle: '@w',
      level: 'N5',
      contentType: MonoContentType.article,
      bodyText: '',
    );
    expect(monoDetailSheetReadTimeValue(item), '—');
  });

  test('category uses catalog field not content type', () {
    const item = MonoFeedItem(
      id: 'm1',
      writerName: 'W',
      writerHandle: '@w',
      level: 'N5',
      contentType: MonoContentType.article,
      bodyText: '',
      catalogCategory: 'Horror',
    );
    expect(monoDetailSheetCategoryValue(item), 'Horror');
  });

  test('category em dash when catalog empty', () {
    const item = MonoFeedItem(
      id: 'm1',
      writerName: 'W',
      writerHandle: '@w',
      level: 'N5',
      contentType: MonoContentType.story,
      bodyText: '',
    );
    expect(monoDetailSheetCategoryValue(item), '—');
  });
}
