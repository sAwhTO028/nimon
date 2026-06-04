import 'package:nimon/features/mono/mono_feed_models.dart'
    show MonoContentType, MonoFeedItem;
import 'package:nimon/features/mono/data/mono_feed_summary_dto.dart';
import 'package:nimon/features/profile/data/published_mono_detail_parser.dart';
import 'package:nimon/features/profile/data/published_mono_display_contract.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';
import 'package:nimon/features/search/data/mono_search_result.dart';

/// Public handle line for reels/reader footer (leading `@` when missing).
String monoWriterHandleDisplay(String? rawBackendHandle) {
  final t = (rawBackendHandle ?? '').trim();
  if (t.isEmpty) return '@reader';
  return t.startsWith('@') ? t : '@$t';
}

/// Maps public catalog summary rows to [MonoFeedItem] for Mono Home (M3c).
MonoFeedItem monoFeedItemFromMonoFeedSummary(MonoFeedSummaryDto dto) {
  final pk = dto.publishKind.trim();
  PublishedMonoAccess? access;
  if (pk.contains('full_learn')) {
    access = const PublishedMonoAccess(
      isReadOnlyPublished: false,
      isFullLearnPublished: true,
      learnModulesInPayload: false,
    );
  } else if (pk.contains('read_only')) {
    access = const PublishedMonoAccess(
      isReadOnlyPublished: true,
      isFullLearnPublished: false,
      learnModulesInPayload: false,
    );
  }

  final wn = dto.writerDisplayName.trim();
  final whRaw = dto.writerHandle.trim();

  final desc = dto.description.trim();
  final av = dto.writerAvatarUrl.trim();
  return MonoFeedItem(
    id: dto.monoId,
    writerId: dto.writerId.trim().isEmpty ? null : dto.writerId.trim(),
    writerName: wn.isNotEmpty ? wn : (whRaw.isNotEmpty ? whRaw : 'Writer'),
    writerHandle: monoWriterHandleDisplay(whRaw),
    writerAvatarUrl: av.isNotEmpty ? av : null,
    level: dto.level.trim().isEmpty ? '—' : dto.level.trim(),
    contentType: MonoContentType.article,
    title: dto.title.trim().isEmpty ? null : dto.title.trim(),

    /// Summary rows do not carry `content.core.sentences`; keep description out of
    /// swipe body until `GET /v1/mono/:id` hydrates structured lines.
    bodyText: '',
    storyDescription: desc,
    content: null,
    coverImageUrl: dto.coverUrl,
    likesCount: dto.likesCount,
    isBookmarkedByMe: dto.isBookmarkedByMe,
    myReaction: dto.myReaction,
    shareUrl: dto.shareUrl,
    publishedAccess: access,
    needsRemoteDetailHydration: true,
    catalogCategory:
        dto.category.trim().isNotEmpty ? dto.category.trim() : null,
    readDurationLabel: null,
  );
}

/// Merges `GET /v1/mono/:id` detail into a catalog [MonoFeedItem] (same ids, no Profile prefix).
MonoFeedItem monoFeedItemMergePublishedDetail(
  MonoFeedItem base,
  PublishedMonoDetailDto d,
) {
  final hasLearn = publishedContentHasLearnPayload(d.content);
  final access = publishedAccessFromDetail(
    d,
    learnModulesInPayload: hasLearn,
  );
  final coreText = plainBodyFromPublishedCore(d.content);
  final content = buildMonoContentFromPublishedCore(
    d.id,
    d.title,
    d.content,
  );
  final coverUrl = (d.coverImageUrl ?? '').trim();
  final cover = coverUrl.isNotEmpty ? coverUrl : base.coverImageUrl;
  final detailDesc = d.description.trim();
  final sid = d.sourceDraftId?.trim();
  final sourceDraftOut = (sid != null && sid.isNotEmpty)
      ? sid
      : (base.sourceDraftId?.trim().isNotEmpty == true
          ? base.sourceDraftId!.trim()
          : null);

  final likesOut = d.likesCount;
  final bookmarkedOut = d.isBookmarkedByMe;
  final myReactionOut = d.myReaction;
  final shareUrlOut = d.shareUrl;

  final catDetail = d.category.trim();
  final catBase = (base.catalogCategory ?? '').trim();
  final catalogCategoryOut =
      catDetail.isNotEmpty ? catDetail : (catBase.isNotEmpty ? catBase : null);

  final durDetail = (d.targetDurationLabel ?? '').trim();
  final durBase = (base.readDurationLabel ?? '').trim();
  final readDurationLabelOut =
      durDetail.isNotEmpty ? durDetail : (durBase.isNotEmpty ? durBase : null);

  final dn = (d.writerDisplayName ?? '').trim();
  final whRaw = (d.writerHandle ?? '').trim();
  final av = (d.writerAvatarUrl ?? '').trim();

  final writerNameOut = dn.isNotEmpty
      ? dn
      : base.writerName.trim().isEmpty
          ? 'Writer'
          : base.writerName;
  final writerHandleOut =
      whRaw.isNotEmpty ? monoWriterHandleDisplay(whRaw) : base.writerHandle;
  final writerAvatarOut = av.isNotEmpty
      ? av
      : (base.writerAvatarUrl?.trim().isNotEmpty == true
          ? base.writerAvatarUrl!.trim()
          : null);

  return MonoFeedItem(
    id: base.id,
    writerId: (base.writerId?.trim().isNotEmpty == true)
        ? base.writerId!.trim()
        : (d.ownerId.trim().isNotEmpty ? d.ownerId.trim() : null),
    writerName: writerNameOut,
    writerHandle: writerHandleOut,
    writerAvatarUrl: writerAvatarOut,
    level: d.level.trim().isEmpty ? base.level : d.level.trim(),
    contentType: base.contentType,
    title: d.title.trim().isEmpty ? base.title : d.title.trim(),

    /// Never promote Story Basics description into horizontal reading body; footer uses [storyDescription].
    bodyText: coreText.isNotEmpty ? coreText : base.bodyText,
    storyDescription:
        detailDesc.isNotEmpty ? detailDesc : base.storyDescription.trim(),
    content: content ?? base.content,
    coverImageUrl: cover,
    coverCategory: base.coverCategory,
    publishedAccess: access,
    needsRemoteDetailHydration: false,
    catalogMonoId: base.catalogMonoId,
    sourceDraftId: sourceDraftOut,
    likesCount: likesOut != 0 ? likesOut : base.likesCount,
    isBookmarkedByMe: bookmarkedOut || base.isBookmarkedByMe,
    myReaction: myReactionOut ?? base.myReaction,
    shareUrl: shareUrlOut ?? base.shareUrl,
    catalogCategory: catalogCategoryOut,
    readDurationLabel: readDurationLabelOut,
  );
}

/// Maps a published-mono list row (catalog API) to [MonoFeedItem] for public surfaces.
MonoFeedItem monoFeedItemFromPublishedMonoListItemDto(
  PublishedMonoListItemDto dto, {
  String writerName = 'Writer',
  String writerHandle = '@reader',
  String? writerAvatarUrl,
  int likesCount = 0,
  bool isBookmarkedByMe = false,
  String? myReaction,
}) {
  final pk = (dto.publishKind ?? '').trim();
  final dpk = dto.displayPublishKind.trim();
  PublishedMonoAccess? access;
  if (dpk == 'full_learn' || pk.contains('full_learn')) {
    access = const PublishedMonoAccess(
      isReadOnlyPublished: false,
      isFullLearnPublished: true,
      learnModulesInPayload: false,
    );
  } else if (dpk == 'read_only' || pk.contains('read_only')) {
    access = const PublishedMonoAccess(
      isReadOnlyPublished: true,
      isFullLearnPublished: false,
      learnModulesInPayload: false,
    );
  }

  final oid = dto.ownerId.trim();
  final dn = (dto.writerDisplayName ?? '').trim();
  final whDto = (dto.writerHandle ?? '').trim();
  final avDto = (dto.writerAvatarUrl ?? '').trim();

  final writerNameOut = dn.isNotEmpty
      ? dn
      : (whDto.isNotEmpty
          ? whDto
          : (writerName.trim().isNotEmpty ? writerName.trim() : 'Writer'));
  final wh =
      whDto.isNotEmpty ? monoWriterHandleDisplay(whDto) : writerHandle.trim();
  final av = avDto.isNotEmpty ? avDto : (writerAvatarUrl?.trim());

  final desc = dto.description.trim();
  final cat = dto.category.trim();
  final dur = (dto.targetDurationLabel ?? '').trim();

  return MonoFeedItem(
    id: dto.id,
    writerId: oid.isEmpty ? null : oid,
    writerName: writerNameOut,
    writerHandle: wh,
    writerAvatarUrl: (av != null && av.isNotEmpty) ? av : null,
    level: dto.level.trim().isEmpty ? '—' : dto.level.trim(),
    contentType: MonoContentType.article,
    title: dto.title.trim().isEmpty ? null : dto.title.trim(),
    bodyText: '',
    storyDescription: desc,
    coverImageUrl: dto.coverImageUrl,
    publishedAccess: access,
    needsRemoteDetailHydration: true,
    catalogMonoId: null,
    sourceDraftId: dto.sourceDraftId,
    shareUrl: dto.shareUrl,
    catalogCategory: cat.isNotEmpty ? cat : null,
    readDurationLabel: dur.isNotEmpty ? dur : null,
    likesCount: likesCount,
    isBookmarkedByMe: isBookmarkedByMe,
    myReaction: myReaction,
    contentLocale: dto.contentLocale,
  );
}

/// Search API row → reader/list [MonoFeedItem] (M18C).
MonoFeedItem monoFeedItemFromMonoSearchResult(MonoSearchResult r) {
  return monoFeedItemFromPublishedMonoListItemDto(
    r.listItem,
    likesCount: r.likesCount,
    isBookmarkedByMe: r.isBookmarkedByMe,
    myReaction: r.myReaction,
  );
}
