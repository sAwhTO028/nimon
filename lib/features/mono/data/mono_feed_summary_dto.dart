// Public Mono catalog list row from `GET /v1/mono/feed` (Nimon backend M3a).

class MonoFeedSummaryDto {
  const MonoFeedSummaryDto({
    required this.monoId,
    required this.title,
    required this.coverUrl,
    required this.level,
    required this.category,
    required this.categories,
    required this.description,
    required this.writerId,
    required this.writerHandle,
    required this.writerDisplayName,
    required this.writerAvatarUrl,
    required this.publishedAt,
    required this.updatedAt,
    required this.likesCount,
    required this.hasAudio,
    required this.isBookmarkedByMe,
    required this.myReaction,
    required this.shareUrl,
    required this.publishKind,
    required this.accessType,
    this.contentLocale,
    this.learningLanguage,
  });

  final String monoId;
  final String title;
  final String? coverUrl;
  final String level;
  final String category;
  final List<String> categories;
  final String description;
  final String writerId;
  final String writerHandle;
  final String writerDisplayName;
  final String writerAvatarUrl;
  final String publishedAt;
  final String updatedAt;
  final int likesCount;
  final bool hasAudio;
  final bool isBookmarkedByMe;
  final String? myReaction;
  final String? shareUrl;
  final String publishKind;
  final String accessType;
  final String? contentLocale;
  final String? learningLanguage;

  factory MonoFeedSummaryDto.fromJson(Map<String, Object?> json) {
    final categoryStr = _str(json['category']);
    final cats = _stringList(json['categories']);
    final categoriesOut = cats.isNotEmpty
        ? cats
        : (categoryStr.isNotEmpty ? <String>[categoryStr] : const <String>[]);

    return MonoFeedSummaryDto(
      monoId: _str(json['monoId']),
      title: _str(json['title']),
      coverUrl: _optStr(json['coverUrl']),
      level: _str(json['level']),
      category: categoryStr,
      categories: categoriesOut,
      description: _str(json['description']),
      writerId: _str(json['writerId']),
      writerHandle: _str(json['writerHandle']),
      writerDisplayName: _str(json['writerDisplayName']),
      writerAvatarUrl: _str(json['writerAvatarUrl']),
      publishedAt: _str(json['publishedAt']),
      updatedAt: _str(json['updatedAt']),
      likesCount: _int(json['likesCount']),
      hasAudio: _bool(json['hasAudio']),
      isBookmarkedByMe: _bool(json['isBookmarkedByMe']),
      myReaction: _optStr(json['myReaction']),
      shareUrl: _optStr(json['shareUrl']),
      publishKind: _str(json['publishKind']),
      accessType: _str(json['accessType']).isEmpty
          ? 'public'
          : _str(json['accessType']),
      contentLocale: _optStr(json['contentLocale']),
      learningLanguage: _optStr(json['learningLanguage']),
    );
  }

  static String _str(Object? v) {
    if (v == null) return '';
    if (v is String) return v;
    return v.toString();
  }

  static String? _optStr(Object? v) {
    final s = _str(v).trim();
    return s.isEmpty ? null : s;
  }

  static int _int(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static bool _bool(Object? v) {
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  static List<String> _stringList(Object? v) {
    if (v is! List) return const [];
    final out = <String>[];
    for (final e in v) {
      out.add(_str(e));
    }
    return out;
  }
}
