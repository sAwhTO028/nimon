class AppUser {
  final String id;
  final String name;
  final String level; // N5..N1
  final int xp;
  final int coins;
  final String avatar;
  AppUser({
    required this.id, required this.name, required this.level,
    required this.xp, required this.coins, required this.avatar,
  });
  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'], name: j['name'], level: j['level'],
    xp: j['xp'] ?? 0, coins: j['coins'] ?? 0, avatar: j['avatar'] ?? 'default',
  );
}
