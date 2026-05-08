import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/create/data/story_draft_mapper.dart';
import 'package:nimon/features/create/story_creator_public_audio_url.dart';
import 'package:nimon/features/create/story_v1_model.dart';

void main() {
  group('publicAudioSourceUrlValidationMessage', () {
    test('accepts http and https', () {
      expect(
        publicAudioSourceUrlValidationMessage('https://cdn.example.com/a.mp3'),
        isNull,
      );
      expect(
        publicAudioSourceUrlValidationMessage('HTTP://example.com/x.wav'),
        isNull,
      );
    });

    test('rejects empty, file, local, ftp', () {
      expect(
        publicAudioSourceUrlValidationMessage(''),
        isNotNull,
      );
      expect(
        publicAudioSourceUrlValidationMessage('   '),
        isNotNull,
      );
      expect(
        publicAudioSourceUrlValidationMessage('file:///tmp/x.mp3'),
        isNotNull,
      );
      expect(
        publicAudioSourceUrlValidationMessage('local://x.mp3'),
        isNotNull,
      );
      expect(
        publicAudioSourceUrlValidationMessage('ftp://host/x'),
        isNotNull,
      );
    });
  });

  group('StoryDraftMapper.fromDomainRemoteSafe storyAudio', () {
    test('preserves http localhost upload URL (M5b)', () {
      final story = CreatorStoryV1.empty().copyWith(
        audio: AudioLayer(
          storyAudio: StoryAudioAsset(
            id: 'aud-m5',
            sourceUrl:
                'http://localhost:3000/uploads/1111-1111/audio/story.mp3',
            displayName: 'Narration',
            durationSeconds: 42,
            provenance: const ContentProvenance(),
          ),
        ),
      );
      final dto = StoryDraftMapper.fromDomainRemoteSafe(story);
      expect(
        dto.audio.storyAudio?.sourceUrl,
        'http://localhost:3000/uploads/1111-1111/audio/story.mp3',
      );
      expect(dto.audio.storyAudio?.durationSeconds, 42);
    });

    test('preserves https sourceUrl', () {
      final story = CreatorStoryV1.empty().copyWith(
        audio: AudioLayer(
          storyAudio: StoryAudioAsset(
            id: 'aud-1',
            sourceUrl: 'https://cdn.example.com/story.mp3',
            localFileName: 'old-local.mp3',
            localPath: '/device/x.mp3',
            displayName: 'Chapter read',
            durationSeconds: 120,
            provenance: const ContentProvenance(),
          ),
        ),
      );
      final dto = StoryDraftMapper.fromDomainRemoteSafe(story);
      expect(
          dto.audio.storyAudio?.sourceUrl, 'https://cdn.example.com/story.mp3');
      expect(dto.audio.storyAudio?.displayName, 'Chapter read');
      expect(dto.audio.storyAudio?.durationSeconds, 120);
      expect(dto.audio.storyAudio?.localFileName, isNull);
      expect(dto.audio.storyAudio?.localPath, isNull);
    });

    test('strips non-http sourceUrl and local fields', () {
      final story = CreatorStoryV1.empty().copyWith(
        audio: AudioLayer(
          storyAudio: StoryAudioAsset(
            id: 'aud-2',
            sourceUrl: 'local://clip.mp3',
            localFileName: 'clip.mp3',
            localPath: '/tmp/clip.mp3',
            displayName: 'Local',
            provenance: const ContentProvenance(),
          ),
        ),
      );
      final dto = StoryDraftMapper.fromDomainRemoteSafe(story);
      expect(dto.audio.storyAudio?.sourceUrl, isNull);
      expect(dto.audio.storyAudio?.localFileName, isNull);
      expect(dto.audio.storyAudio?.localPath, isNull);
    });
  });

  group('toDomain after remote-safe https', () {
    test('storyAudio remains valid for listening UI', () {
      final story = CreatorStoryV1.empty().copyWith(
        audio: AudioLayer(
          storyAudio: StoryAudioAsset(
            id: 'aud-3',
            sourceUrl: 'https://example.com/a.m4a',
            displayName: 'Track',
            durationSeconds: 60,
            provenance: const ContentProvenance(),
          ),
        ),
      );
      final dto = StoryDraftMapper.fromDomainRemoteSafe(story);
      final viaRemote = StoryDraftMapper.toDomain(dto);
      expect(viaRemote.audio.storyAudio?.isValidV1, isTrue);
      expect(viaRemote.audio.storyAudio?.hasUploadedSourceUrl, isTrue);
      expect(
          viaRemote.audio.storyAudio?.sourceUrl, 'https://example.com/a.m4a');
    });
  });
}
