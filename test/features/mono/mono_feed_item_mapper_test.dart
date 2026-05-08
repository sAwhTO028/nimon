import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/features/mono/data/mono_feed_item_mapper.dart';
import 'package:nimon/features/mono/data/mono_feed_summary_dto.dart';
import 'package:nimon/features/mono/mono_feed_models.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';

void main() {
  test(
    'monoFeedItemFromPublishedMonoListItemDto prefers DTO writer snapshot over fallbacks',
    () {
      final dto = PublishedMonoListItemDto(
        id: 'cat-m2',
        ownerId: 'owner1',
        sourceDraftId: null,
        title: 'Story',
        category: 'Love',
        level: 'N4',
        description: 'Desc',
        publishKind: 'read_only_v1',
        displayPublishKind: 'read_only',
        coverImageUrl: null,
        targetDurationLabel: null,
        createdAt: '2026-01-01T00:00:00Z',
        updatedAt: '2026-01-02T00:00:00Z',
        contentSummary: null,
        writerDisplayName: 'Live Name',
        writerHandle: 'live_h',
        writerAvatarUrl: 'https://avatars.test/live.png',
      );
      final item = monoFeedItemFromPublishedMonoListItemDto(
        dto,
        writerName: 'Fallback',
        writerHandle: '@fallback',
        writerAvatarUrl: 'https://ignored',
      );
      expect(item.writerName, 'Live Name');
      expect(item.writerHandle, '@live_h');
      expect(item.writerAvatarUrl, 'https://avatars.test/live.png');
    },
  );

  test(
    'monoFeedItemFromPublishedMonoListItemDto maps catalog id and hydration',
    () {
      final dto = PublishedMonoListItemDto(
        id: 'cat-m1',
        ownerId: 'owner1',
        sourceDraftId: null,
        title: 'Story',
        category: 'Love',
        level: 'N4',
        description: 'Desc',
        publishKind: 'read_only_v1',
        displayPublishKind: 'read_only',
        coverImageUrl: 'http://example/c.png',
        targetDurationLabel: null,
        createdAt: '2026-01-01T00:00:00Z',
        updatedAt: '2026-01-02T00:00:00Z',
        contentSummary: null,
      );
      final item = monoFeedItemFromPublishedMonoListItemDto(
        dto,
        writerName: 'Writer',
        writerHandle: '@w',
      );
      expect(item.id, 'cat-m1');
      expect(item.writerId, 'owner1');
      expect(item.needsRemoteDetailHydration, true);
      expect(item.publishedAccess?.isReadOnlyPublished, true);
      expect(item.catalogMonoId, isNull);
    },
  );

  test(
      'monoFeedItemFromMonoFeedSummary maps id title level and flags hydration',
      () {
    final d = MonoFeedSummaryDto(
      monoId: 'm1',
      title: 'T',
      coverUrl: null,
      level: 'N4',
      category: 'L',
      categories: const ['L'],
      description: 'Desc',
      writerId: 'w',
      writerHandle: '@h',
      writerDisplayName: 'Name',
      writerAvatarUrl: 'https://avatars.test/me.png',
      publishedAt: '',
      updatedAt: '',
      likesCount: 0,
      hasAudio: false,
      isBookmarkedByMe: true,
      myReaction: 'heart',
      shareUrl: 'http://localhost:3000/mono/m1',
      publishKind: 'read_only_v1',
      accessType: 'public',
    );
    final item = monoFeedItemFromMonoFeedSummary(d);
    expect(item.id, 'm1');
    expect(item.writerId, 'w');
    expect(item.title, 'T');
    expect(item.level, 'N4');
    expect(item.bodyText, '');
    expect(item.storyDescription, 'Desc');
    expect(item.isBookmarkedByMe, true);
    expect(item.myReaction, 'heart');
    expect(item.shareUrl, 'http://localhost:3000/mono/m1');
    expect(item.needsRemoteDetailHydration, true);
    expect(item.publishedAccess?.isReadOnlyPublished, true);
    expect(item.contentType, MonoContentType.article);
    expect(item.writerAvatarUrl, 'https://avatars.test/me.png');
  });

  test('monoFeedItemMergePublishedDetail clears hydration flag', () {
    final base = monoFeedItemFromMonoFeedSummary(
      MonoFeedSummaryDto(
        monoId: 'mid',
        title: 't',
        coverUrl: null,
        level: 'N5',
        category: '',
        categories: const [],
        description: '',
        writerId: '',
        writerHandle: '',
        writerDisplayName: '',
        writerAvatarUrl: '',
        publishedAt: '',
        updatedAt: '',
        likesCount: 0,
        hasAudio: false,
        isBookmarkedByMe: false,
        myReaction: null,
        shareUrl: null,
        publishKind: 'read_only_v1',
        accessType: 'public',
      ),
    );
    final detail = PublishedMonoDetailDto(
      id: 'mid',
      ownerId: 'o',
      sourceDraftId: null,
      title: 'Full',
      category: '',
      level: 'N5',
      description: '',
      publishKind: 'read_only_v1',
      displayPublishKind: 'read_only',
      coverImageUrl: null,
      targetDurationLabel: null,
      createdAt: '',
      updatedAt: '',
      contentSummary: null,
      content: {
        'core': {
          'sentences': [
            {
              'content': {'japaneseText': 'こんにちは'},
            },
          ],
        },
      },
      likesCount: 9,
      isBookmarkedByMe: true,
      myReaction: 'heart',
      shareUrl: 'http://localhost:3000/mono/mid',
    );
    final merged = monoFeedItemMergePublishedDetail(base, detail);
    expect(merged.needsRemoteDetailHydration, false);
    expect(merged.writerId, 'o');
    expect(merged.title, 'Full');
    expect(merged.effectiveBodyText, contains('こんにちは'));
    expect(merged.likesCount, 9);
    expect(merged.isBookmarkedByMe, true);
    expect(merged.myReaction, 'heart');
    expect(merged.shareUrl, 'http://localhost:3000/mono/mid');
    expect(merged.sourceDraftId, isNull);
  });

  test('monoFeedItemMergePublishedDetail copies sourceDraftId from detail', () {
    final base = monoFeedItemFromMonoFeedSummary(
      MonoFeedSummaryDto(
        monoId: 'mid',
        title: 't',
        coverUrl: null,
        level: 'N5',
        category: '',
        categories: const [],
        description: '',
        writerId: '',
        writerHandle: '',
        writerDisplayName: '',
        writerAvatarUrl: '',
        publishedAt: '',
        updatedAt: '',
        likesCount: 0,
        hasAudio: false,
        isBookmarkedByMe: false,
        myReaction: null,
        shareUrl: null,
        publishKind: 'read_only_v1',
        accessType: 'public',
      ),
    );
    final detail = PublishedMonoDetailDto(
      id: 'mid',
      ownerId: 'o',
      sourceDraftId: 'draft-xyz',
      title: 'Full',
      category: '',
      level: 'N5',
      description: '',
      publishKind: 'read_only_v1',
      displayPublishKind: 'read_only',
      coverImageUrl: null,
      targetDurationLabel: null,
      createdAt: '',
      updatedAt: '',
      contentSummary: null,
      content: const {},
    );
    final merged = monoFeedItemMergePublishedDetail(base, detail);
    expect(merged.sourceDraftId, 'draft-xyz');
  });

  test(
      'monoFeedItemMergePublishedDetail keeps story basics description when sentence body loads',
      () {
    final base = monoFeedItemFromMonoFeedSummary(
      MonoFeedSummaryDto(
        monoId: 'mid',
        title: 't',
        coverUrl: null,
        level: 'N5',
        category: '',
        categories: const [],
        description: 'Summary basics',
        writerId: '',
        writerHandle: '',
        writerDisplayName: '',
        writerAvatarUrl: '',
        publishedAt: '',
        updatedAt: '',
        likesCount: 0,
        hasAudio: false,
        isBookmarkedByMe: false,
        myReaction: null,
        shareUrl: null,
        publishKind: 'read_only_v1',
        accessType: 'public',
      ),
    );
    final detail = PublishedMonoDetailDto(
      id: 'mid',
      ownerId: 'o',
      sourceDraftId: null,
      title: 'Full',
      category: '',
      level: 'N5',
      description: 'Published basics',
      publishKind: 'read_only_v1',
      displayPublishKind: 'read_only',
      coverImageUrl: null,
      targetDurationLabel: null,
      createdAt: '',
      updatedAt: '',
      contentSummary: null,
      content: {
        'core': {
          'sentences': [
            {
              'content': {'japaneseText': '本文です'},
            },
          ],
        },
      },
    );
    final merged = monoFeedItemMergePublishedDetail(base, detail);
    expect(merged.storyDescription, 'Published basics');
    expect(merged.effectiveBodyText, contains('本文です'));
    expect(merged.storyDescription, isNot(contains('本文です')));
  });

  test(
      'monoFeedItemMergePublishedDetail keeps summary basics when detail description empty',
      () {
    final base = monoFeedItemFromMonoFeedSummary(
      MonoFeedSummaryDto(
        monoId: 'mid',
        title: 't',
        coverUrl: null,
        level: 'N5',
        category: '',
        categories: const [],
        description: 'Only from summary',
        writerId: '',
        writerHandle: '',
        writerDisplayName: '',
        writerAvatarUrl: '',
        publishedAt: '',
        updatedAt: '',
        likesCount: 0,
        hasAudio: false,
        isBookmarkedByMe: false,
        myReaction: null,
        shareUrl: null,
        publishKind: 'read_only_v1',
        accessType: 'public',
      ),
    );
    final detail = PublishedMonoDetailDto(
      id: 'mid',
      ownerId: 'o',
      sourceDraftId: null,
      title: 'Full',
      category: '',
      level: 'N5',
      description: '',
      publishKind: 'read_only_v1',
      displayPublishKind: 'read_only',
      coverImageUrl: null,
      targetDurationLabel: null,
      createdAt: '',
      updatedAt: '',
      contentSummary: null,
      content: {
        'core': {
          'sentences': [
            {
              'content': {'japaneseText': 'X'},
            },
          ],
        },
      },
    );
    final merged = monoFeedItemMergePublishedDetail(base, detail);
    expect(merged.storyDescription, 'Only from summary');
  });

  test(
      'monoFeedItemMergePublishedDetail keeps description out of swipe body '
      'when core sentences absent', () {
    final base = monoFeedItemFromMonoFeedSummary(
      MonoFeedSummaryDto(
        monoId: 'mid',
        title: 't',
        coverUrl: null,
        level: 'N5',
        category: '',
        categories: const [],
        description: 'Summ',
        writerId: '',
        writerHandle: '',
        writerDisplayName: '',
        writerAvatarUrl: '',
        publishedAt: '',
        updatedAt: '',
        likesCount: 0,
        hasAudio: false,
        isBookmarkedByMe: false,
        myReaction: null,
        shareUrl: null,
        publishKind: 'read_only_v1',
        accessType: 'public',
      ),
    );
    final detail = PublishedMonoDetailDto(
      id: 'mid',
      ownerId: 'o',
      sourceDraftId: null,
      title: 'Full',
      category: '',
      level: 'N5',
      description: 'Basics only',
      publishKind: 'read_only_v1',
      displayPublishKind: 'read_only',
      coverImageUrl: null,
      targetDurationLabel: null,
      createdAt: '',
      updatedAt: '',
      contentSummary: null,
      content: {'core': <String, Object?>{}},
    );
    final merged = monoFeedItemMergePublishedDetail(base, detail);
    expect(merged.storyDescription, 'Basics only');
    expect(
      merged.bodyText,
      '',
      reason: 'Do not use Story Basics text as horizontal reading body',
    );
    expect(merged.content, isNull);
  });
}
