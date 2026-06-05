import 'package:nimon/features/mono/data/mono_feed_item_mapper.dart';
import 'package:nimon/features/mono/mono_feed_models.dart'
    show MonoContentType, MonoFeedItem, kProfilePublishedMonoFeedItemIdPrefix;
import 'package:nimon/features/profile/data/published_mono_detail_parser.dart';
import 'package:nimon/features/profile/data/published_mono_display_contract.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';

/// Same string as [kProfilePublishedMonoFeedItemIdPrefix] (Profile reader id prefix).
const String kProfilePublishedMonoIdPrefix =
    kProfilePublishedMonoFeedItemIdPrefix;

MonoFeedItem monoFeedItemFromPublishedMonoDetail(
  PublishedMonoDetailDto d, {
  String writerName = 'Creator',
  String writerHandle = '@reader',
  String? writerAvatarUrl,
}) {
  final hasLearn = publishedContentHasLearnPayload(d.content);
  final access = publishedAccessFromDetail(d, learnModulesInPayload: hasLearn);
  final coreText = plainBodyFromPublishedCore(d.content);
  final content = buildMonoContentFromPublishedCore(
    d.id,
    d.title,
    d.content,
    learningLanguage: d.learningLanguage,
  );
  final cover =
      (d.coverImageUrl ?? '').trim().isEmpty ? null : d.coverImageUrl!.trim();

  final basicsDesc = d.description.trim();
  final sid = d.sourceDraftId?.trim();
  final cat = d.category.trim();
  final dur = (d.targetDurationLabel ?? '').trim();

  final dn = (d.writerDisplayName ?? '').trim();
  final whRaw = (d.writerHandle ?? '').trim();
  final avBackend = (d.writerAvatarUrl ?? '').trim();

  final nameOut = dn.isNotEmpty
      ? dn
      : writerName.trim().isNotEmpty
          ? writerName.trim()
          : 'Creator';
  final handleOut = whRaw.isNotEmpty
      ? monoWriterHandleDisplay(whRaw)
      : writerHandle.trim().isNotEmpty
          ? writerHandle.trim().startsWith('@')
              ? writerHandle.trim()
              : '@${writerHandle.trim()}'
          : '@reader';
  final avatarOut = avBackend.isNotEmpty
      ? avBackend
      : (writerAvatarUrl?.trim().isNotEmpty == true
          ? writerAvatarUrl!.trim()
          : null);

  return MonoFeedItem(
    id: '$kProfilePublishedMonoIdPrefix${d.id}',
    catalogMonoId: d.id.trim(),
    sourceDraftId: (sid != null && sid.isNotEmpty) ? sid : null,
    writerId: (d.ownerId.trim().isEmpty) ? null : d.ownerId.trim(),
    writerName: nameOut,
    writerHandle: handleOut,
    writerAvatarUrl: avatarOut,
    level: d.level.trim().isEmpty ? '—' : d.level.trim(),
    contentType: MonoContentType.article,
    title: d.title.trim().isEmpty ? null : d.title.trim(),
    bodyText: coreText.isNotEmpty ? coreText : '',
    storyDescription: basicsDesc,
    content: content,
    coverImageUrl: cover,
    coverCategory: null,
    publishedAccess: access,
    likesCount: d.likesCount,
    isBookmarkedByMe: d.isBookmarkedByMe,
    myReaction: d.myReaction,
    shareUrl: d.shareUrl,
    catalogCategory: cat.isNotEmpty ? cat : null,
    readDurationLabel: dur.isNotEmpty ? dur : null,
  );
}
