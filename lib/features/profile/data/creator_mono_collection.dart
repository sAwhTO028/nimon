/// Backend creator collection row (`GET /v1/me/creator-collections`).
class CreatorMonoCollection {
  const CreatorMonoCollection({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    this.coverImageUrl,
    required this.visibility,
    required this.itemCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final String visibility;
  final int itemCount;
  final String createdAt;
  final String updatedAt;

  factory CreatorMonoCollection.fromJson(Map<String, Object?> m) {
    int itemCount(Object? v) {
      if (v is int) return v;
      if (v is double) return v.round();
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return CreatorMonoCollection(
      id: (m['id'] ?? '').toString(),
      ownerId: (m['ownerId'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      description: m['description']?.toString(),
      coverImageUrl: m['coverImageUrl']?.toString(),
      visibility: (m['visibility'] ?? 'public').toString(),
      itemCount: itemCount(m['itemCount']),
      createdAt: (m['createdAt'] ?? '').toString(),
      updatedAt: (m['updatedAt'] ?? '').toString(),
    );
  }
}
