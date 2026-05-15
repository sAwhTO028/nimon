import 'package:flutter/foundation.dart';
import 'package:nimon/features/profile/data/published_mono_dto.dart';

/// One row from `GET /v1/search/monos` — published mono card fields plus social.
@immutable
class MonoSearchResult {
  const MonoSearchResult({
    required this.listItem,
    this.likesCount = 0,
    this.isBookmarkedByMe = false,
    this.myReaction,
  });

  /// Core published-mono list payload (shared parser with profile/catalog).
  final PublishedMonoListItemDto listItem;

  final int likesCount;
  final bool isBookmarkedByMe;
  final String? myReaction;

  String get id => listItem.id;
  String get ownerId => listItem.ownerId;
  String get title => listItem.title;
  String get category => listItem.category;
  String get level => listItem.level;
  String get description => listItem.description;
  String? get coverImageUrl => listItem.coverImageUrl;
  String? get targetDurationLabel => listItem.targetDurationLabel;
  String? get writerDisplayName => listItem.writerDisplayName;
  String? get writerHandle => listItem.writerHandle;
  String? get writerAvatarUrl => listItem.writerAvatarUrl;
  String? get shareUrl => listItem.shareUrl;

  factory MonoSearchResult.fromBackendJson(Map<String, Object?> json) {
    int readInt(Object? v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.round();
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    bool readBool(Object? v) {
      if (v == null) return false;
      if (v is bool) return v;
      final s = v.toString().toLowerCase();
      return s == 'true' || s == '1';
    }

    String? optStr(Object? v) {
      if (v == null) return null;
      if (v is String) {
        final t = v.trim();
        return t.isEmpty ? null : t;
      }
      final t = v.toString().trim();
      return t.isEmpty ? null : t;
    }

    return MonoSearchResult(
      listItem: publishedMonoListItemDtoFromBackendJson(json),
      likesCount: readInt(json['likesCount']),
      isBookmarkedByMe: readBool(json['isBookmarkedByMe']),
      myReaction: optStr(json['myReaction']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MonoSearchResult &&
        other.listItem.id == listItem.id &&
        other.listItem.updatedAt == listItem.updatedAt &&
        other.likesCount == likesCount &&
        other.isBookmarkedByMe == isBookmarkedByMe &&
        other.myReaction == myReaction;
  }

  @override
  int get hashCode => Object.hash(
        listItem.id,
        listItem.updatedAt,
        likesCount,
        isBookmarkedByMe,
        myReaction,
      );
}
