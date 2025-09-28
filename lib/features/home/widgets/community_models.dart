class CommunityCardVM {
  final String title; // e.g., "Myanmar Hits"
  final String level; // e.g., "N2"
  final String description;
  final String genre; // e.g., "Love"
  final int totalEpisodes; // e.g., 20
  final String coverUrl; // book cover
  final List<CommunityEpisodeVM> episodes; // exactly 3 for UI

  const CommunityCardVM({
    required this.title,
    required this.level,
    required this.description,
    required this.genre,
    required this.totalEpisodes,
    required this.coverUrl,
    required this.episodes,
  });
}

class CommunityEpisodeVM {
  final String title; // episode title
  final int number; // 1..3
  final String thumb; // static image

  const CommunityEpisodeVM({
    required this.title,
    required this.number,
    required this.thumb,
  });
}
