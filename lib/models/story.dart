class Story {
  final String id;
  final String title;
  final String theme;    // rain/sakura/...
  final String creatorId;
  final String level;    // N5..N1
  final String desc;
  final int likes;
  Story({
    required this.id, required this.title, required this.theme,
    required this.creatorId, required this.level, required this.desc,
    required this.likes,
  });
  factory Story.fromJson(Map<String, dynamic> j) => Story(
    id: j['id'],
    title: j['title'],
    theme: j['theme'] ?? 'default',
    creatorId: j['creatorId'],
    level: j['level'] ?? 'N5',
    desc: j['desc'] ?? '',
    likes: j['likes'] ?? 0,
  );
}
