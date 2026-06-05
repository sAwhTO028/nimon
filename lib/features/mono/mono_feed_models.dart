import 'package:nimon/features/mono/mono_content_model.dart';
import 'package:nimon/features/profile/data/published_mono_display_contract.dart';

/// Prefix on [MonoFeedItem.id] for Profile → Published reader rows so unsave
/// callbacks can distinguish catalog ids from Profile-sourced items.
const String kProfilePublishedMonoFeedItemIdPrefix = 'profile-';

/// Reading post type (Japanese labels via content type label).
enum MonoContentType { story, letter, dialogue, sentence, diary, article }

/// Fallback cover art when [MonoFeedItem.coverImageUrl] is absent (demo / mock).
enum MonoCoverCategory { love, horror, culture, comedy, art, history }

/// One card/page in the Mono feed or reader.
class MonoFeedItem {
  final String id;
  final String? writerId;
  final String writerName;
  final String writerHandle;

  /// Author avatar from live profile / feed DTO; null keeps placeholder glyph in footer.
  final String? writerAvatarUrl;

  final String level;
  final MonoContentType contentType;
  final String? title;

  /// Full Japanese body; reading layout is Hero + optional Reading mode.
  final String bodyText;

  /// Story Basics description from publish summary/detail (not sentence body).
  final String storyDescription;

  /// Optional structured reader content (preferred direction for V1+).
  ///
  /// When null, [bodyText] is used as the source of truth.
  final MonoContent? content;

  /// Custom cover from uploader (network or file URL string); when null, fallback art applies.
  final String? coverImageUrl;

  /// When [coverImageUrl] is null, pick fallback art; when null, inferred from [contentType].
  final MonoCoverCategory? coverCategory;

  /// When from Published tab API, drives Learn gating.
  final PublishedMonoAccess? publishedAccess;

  /// When true, full reader payload should be loaded via `GET /v1/mono/:id` (public catalog).
  final bool needsRemoteDetailHydration;

  /// Public PublishedMono UUID for **`GET /v1/mono/:id`** and Learn routes.
  ///
  /// Null means [id] is already the catalog id (e.g. Mono Home). Profile Published
  /// rows set [id] to `'$kProfilePublishedMonoFeedItemIdPrefix<uuid>'` for reader
  /// bookkeeping while this field holds the raw uuid.
  final String? catalogMonoId;

  /// Linked [CreatorStoryV1] id from published `content.sourceDraftId` when known.
  /// Required to open Creator from a **catalog mono id** (Profile reader / merged detail).
  final String? sourceDraftId;

  /// Server-derived `COUNT(mono_reactions)` (M7a).
  final int likesCount;

  /// Bookmark state for the current viewer (guest-safe default false) (M7a).
  final bool isBookmarkedByMe;

  /// Viewer reaction kind for the current viewer (V1: `'heart'`), null when absent (M7a).
  final String? myReaction;

  /// Canonical share URL, when present (M7a).
  final String? shareUrl;

  /// Server Story Basics category label (not [MonoContentType] display name).
  final String? catalogCategory;

  /// Server read-duration label (e.g. `3–5 min` from `targetDurationBandKey`).
  final String? readDurationLabel;

  /// Community / audience from catalog row (`en` | `my` | `ja`); null = legacy.
  final String? contentLocale;

  /// Learning target from catalog row (`ja` | `en`); null = legacy.
  final String? learningLanguage;

  const MonoFeedItem({
    required this.id,
    this.writerId,
    required this.writerName,
    required this.writerHandle,
    this.writerAvatarUrl,
    required this.level,
    required this.contentType,
    required this.bodyText,
    this.storyDescription = '',
    this.title,
    this.content,
    this.coverImageUrl,
    this.coverCategory,
    this.publishedAccess,
    this.needsRemoteDetailHydration = false,
    this.catalogMonoId,
    this.sourceDraftId,
    this.likesCount = 0,
    this.isBookmarkedByMe = false,
    this.myReaction,
    this.shareUrl,
    this.catalogCategory,
    this.readDurationLabel,
    this.contentLocale,
    this.learningLanguage,
  });

  /// Id for **`/learn/...`** and [catalogPublishedMonoDetailProvider] — never includes
  /// the Profile reader [`kProfilePublishedMonoFeedItemIdPrefix`] prefix.
  String get monoIdForLearnRoutes {
    final c = catalogMonoId?.trim();
    if (c != null && c.isNotEmpty) return c;
    final raw = id.trim();
    if (raw.startsWith(kProfilePublishedMonoFeedItemIdPrefix)) {
      return raw.substring(kProfilePublishedMonoFeedItemIdPrefix.length).trim();
    }
    return raw;
  }

  /// V1 reader compatibility: use structured content when present, otherwise
  /// fall back to legacy [bodyText].
  String get effectiveBodyText {
    final c = content;
    if (c == null) return bodyText;
    final hasPages =
        c.pages.isNotEmpty && c.pages.any((p) => p.lines.isNotEmpty);
    if (!hasPages) return bodyText;
    final t = c.toPlainText().trim();
    return t.isEmpty ? bodyText : t;
  }
}
