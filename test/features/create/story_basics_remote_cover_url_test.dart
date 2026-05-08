import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/story_basics_remote_cover_url.dart';

void main() {
  group('storyBasicsRemoteCoverUrl', () {
    test('returns network URL when set', () {
      expect(
        storyBasicsRemoteCoverUrl(
          coverLocalPath: null,
          coverNetworkUrl: 'https://cdn.example.com/c.png',
        ),
        'https://cdn.example.com/c.png',
      );
    });

    test('returns http URL from local path when manual paste', () {
      expect(
        storyBasicsRemoteCoverUrl(
          coverLocalPath: 'http://localhost:3000/uploads/x/y.jpg',
          coverNetworkUrl: null,
        ),
        'http://localhost:3000/uploads/x/y.jpg',
      );
    });

    test('does not return filesystem paths', () {
      expect(
        storyBasicsRemoteCoverUrl(
          coverLocalPath: '/storage/emulated/0/DCIM/a.jpg',
          coverNetworkUrl: null,
        ),
        isNull,
      );
    });

    test('ignores non-http network field', () {
      expect(
        storyBasicsRemoteCoverUrl(
          coverLocalPath: null,
          coverNetworkUrl: 'file:///tmp/x.png',
        ),
        isNull,
      );
    });
  });

  group('storyBasicsPersistedCoverUrl', () {
    test('keeps draft URL when form has no new remote value', () {
      expect(
        storyBasicsPersistedCoverUrl(
          coverExplicitlyCleared: false,
          coverLocalPath: null,
          coverNetworkUrl: null,
          draftCoverImageUrl: 'https://cdn.example.com/old.png',
        ),
        'https://cdn.example.com/old.png',
      );
    });

    test('uses new remote when set', () {
      expect(
        storyBasicsPersistedCoverUrl(
          coverExplicitlyCleared: false,
          coverLocalPath: null,
          coverNetworkUrl: 'https://cdn.example.com/new.png',
          draftCoverImageUrl: 'https://cdn.example.com/old.png',
        ),
        'https://cdn.example.com/new.png',
      );
    });

    test('clears when user explicitly cleared cover', () {
      expect(
        storyBasicsPersistedCoverUrl(
          coverExplicitlyCleared: true,
          coverLocalPath: null,
          coverNetworkUrl: null,
          draftCoverImageUrl: 'https://cdn.example.com/old.png',
        ),
        isNull,
      );
    });
  });
}
