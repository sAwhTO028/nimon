import 'package:nimon/features/mono/mono_screen.dart' show MonoContentType, MonoFeedItem;
import 'package:nimon/features/profile/data/published_mono_detail_parser.dart';
import 'package:nimon/features/profile/data/published_mono_display_contract.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';

const String kProfilePublishedMonoIdPrefix = 'profile-';

MonoFeedItem monoFeedItemFromPublishedMonoDetail(
  PublishedMonoDetailDto d, {
  String writerName = 'Just4withYou',
  String writerHandle = '@just4withyou',
}) {
  final hasLearn = publishedContentHasLearnPayload(d.content);
  final access = publishedAccessFromDetail(d, learnModulesInPayload: hasLearn);
  final coreText = plainBodyFromPublishedCore(d.content);
  final content = buildMonoContentFromPublishedCore(
    d.id,
    d.title,
    d.content,
  );
  final cover = (d.coverImageUrl ?? '').trim().isEmpty
      ? null
      : d.coverImageUrl!.trim();

  return MonoFeedItem(
    id: '$kProfilePublishedMonoIdPrefix${d.id}',
    writerName: writerName,
    writerHandle: writerHandle,
    level: d.level.trim().isEmpty ? '—' : d.level.trim(),
    contentType: MonoContentType.story,
    title: d.title.trim().isEmpty ? null : d.title.trim(),
    bodyText: coreText.isNotEmpty ? coreText : d.description,
    content: content,
    coverImageUrl: cover,
    coverCategory: null,
    publishedAccess: access,
  );
}
