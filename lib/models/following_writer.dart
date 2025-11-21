/// Model representing a writer that the user is following
class FollowingWriter {
  final String id;
  final String name;
  final String? avatarUrl;

  const FollowingWriter({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  /// Get the initial letter for avatar fallback
  String get initial {
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }
}

