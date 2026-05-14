import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';
import 'package:nimon/features/mono/share_mono_link.dart';

void main() {
  test('resolveMonoShareUrlForItem prefers backend shareUrl', () {
    const item = MonoFeedItem(
      id: 'mid',
      writerName: 'W',
      writerHandle: '@w',
      level: 'N5',
      contentType: MonoContentType.article,
      bodyText: '',
      shareUrl: 'https://nimon.app/mono/mid',
    );
    expect(
      resolveMonoShareUrlForItem(
        item,
        publicWebBaseFromDefine: 'http://192.168.11.5:3000',
        apiBaseFromDefine: 'http://192.168.11.5:3000',
      ),
      'https://nimon.app/mono/mid',
    );
  });

  test('resolveMonoShareUrlForItem uses publicWebBase when backend empty', () {
    const item = MonoFeedItem(
      id: 'mid',
      writerName: 'W',
      writerHandle: '@w',
      level: 'N5',
      contentType: MonoContentType.article,
      bodyText: '',
      shareUrl: null,
    );
    expect(
      resolveMonoShareUrlForItem(
        item,
        publicWebBaseFromDefine: 'http://192.168.11.5:3000',
        apiBaseFromDefine: 'http://localhost:3000',
      ),
      'http://192.168.11.5:3000/mono/mid',
    );
  });

  test('resolveMonoShareUrlForItem uses non-loopback api when public web empty',
      () {
    const item = MonoFeedItem(
      id: 'mid',
      writerName: 'W',
      writerHandle: '@w',
      level: 'N5',
      contentType: MonoContentType.article,
      bodyText: '',
      shareUrl: null,
    );
    expect(
      resolveMonoShareUrlForItem(
        item,
        publicWebBaseFromDefine: '',
        apiBaseFromDefine: 'http://192.168.11.5:3000',
      ),
      'http://192.168.11.5:3000/mono/mid',
    );
  });

  test(
      'resolveMonoShareUrlForItem refuses loopback api fallback (no misleading localhost link)',
      () {
    const item = MonoFeedItem(
      id: 'mid',
      writerName: 'W',
      writerHandle: '@w',
      level: 'N5',
      contentType: MonoContentType.article,
      bodyText: '',
      shareUrl: null,
    );
    expect(
      resolveMonoShareUrlForItem(
        item,
        publicWebBaseFromDefine: '',
        apiBaseFromDefine: 'http://localhost:3000',
      ),
      '',
    );
  });

  test('profile-prefixed id still uses catalog id in path when set', () {
    const item = MonoFeedItem(
      id: 'profile-real-uuid',
      writerName: 'W',
      writerHandle: '@w',
      level: 'N5',
      contentType: MonoContentType.article,
      bodyText: '',
      shareUrl: null,
      catalogMonoId: 'real-uuid',
    );
    expect(
      resolveMonoShareUrlForItem(
        item,
        publicWebBaseFromDefine: 'http://192.168.11.5:3000',
        apiBaseFromDefine: '',
      ),
      'http://192.168.11.5:3000/mono/real-uuid',
    );
  });
}
