import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/data/dto/story_draft_dto.dart';
import 'package:nimon/features/learn/listening_pronunciation_screen.dart';

void main() {
  group('publishedStoryAudioHttpUrl', () {
    test('returns null for null dto', () {
      expect(publishedStoryAudioHttpUrl(null), isNull);
    });

    test('accepts http and https', () {
      expect(
        publishedStoryAudioHttpUrl(
          const StoryAudioDto(
            id: '1',
            sourceUrl: 'https://cdn.example.com/a.mp3',
          ),
        ),
        'https://cdn.example.com/a.mp3',
      );
      expect(
        publishedStoryAudioHttpUrl(
          const StoryAudioDto(
            id: '1',
            sourceUrl: 'http://cdn.example.com/a.mp3',
          ),
        ),
        'http://cdn.example.com/a.mp3',
      );
    });

    test('rejects empty, file scheme, and non-http(s)', () {
      expect(
        publishedStoryAudioHttpUrl(
          const StoryAudioDto(id: '1', sourceUrl: ''),
        ),
        isNull,
      );
      expect(
        publishedStoryAudioHttpUrl(
          const StoryAudioDto(id: '1', sourceUrl: 'file:///tmp/x.mp3'),
        ),
        isNull,
      );
      expect(
        publishedStoryAudioHttpUrl(
          const StoryAudioDto(id: '1', sourceUrl: 'ftp://x/y'),
        ),
        isNull,
      );
    });

    test('ignores localPath when sourceUrl unusable', () {
      expect(
        publishedStoryAudioHttpUrl(
          const StoryAudioDto(
            id: '1',
            sourceUrl: null,
            localPath: '/data/app/audio.mp3',
          ),
        ),
        isNull,
      );
    });
  });
}
