/// V1 mock data for the learner-facing public profile (replace with API later).

/// A public Mono story as shown to other learners.
class PublicStory {
  const PublicStory({
    required this.id,
    required this.title,
    required this.description,
    required this.jlptLevel,
    this.thumbnailUrl,
    this.readMinutes = 3,
    this.metadataLineOverride,
  });

  final String id;
  final String title;
  final String description;
  final String jlptLevel;
  final String? thumbnailUrl;
  final int readMinutes;

  /// When set, shown as the bottom metadata row instead of the default line.
  final String? metadataLineOverride;

  String get metadataLine {
    final o = metadataLineOverride?.trim();
    if (o != null && o.isNotEmpty) return o;
    return '$readMinutes min read · Mono';
  }
}

/// A public folder / collection.
class PublicFolder {
  const PublicFolder({
    required this.id,
    required this.name,
    required this.storyIds,
    this.description,
    this.coverImageUrl,
  });

  final String id;
  final String name;
  final List<String> storyIds;
  final String? description;
  final String? coverImageUrl;

  int get storyCount => storyIds.length;
}

/// Bundle shown on [PublicProfileScreen].
class PublicProfileBundle {
  const PublicProfileBundle({
    required this.displayName,
    required this.handle,
    this.bio,
    this.coverImageUrl,
    this.avatarUrl,
    required this.storiesCount,
    required this.followersCount,
    required this.followingCount,
    required this.stories,
    required this.folders,
    this.featuredStoryId,
  });

  final String displayName;
  final String handle;
  final String? bio;
  final String? coverImageUrl;
  final String? avatarUrl;
  final int storiesCount;
  final int followersCount;
  final int followingCount;
  final List<PublicStory> stories;
  final List<PublicFolder> folders;

  /// Pinned / featured story on Home; falls back to latest in UI if null.
  final String? featuredStoryId;

  PublicStory? storyById(String id) {
    for (final s in stories) {
      if (s.id == id) return s;
    }
    return null;
  }

  PublicFolder? folderById(String id) {
    for (final f in folders) {
      if (f.id == id) return f;
    }
    return null;
  }

  List<PublicStory> storiesForFolder(PublicFolder folder) {
    final out = <PublicStory>[];
    for (final sid in folder.storyIds) {
      final s = storyById(sid);
      if (s != null) out.add(s);
    }
    return out;
  }
}

/// Demo public profile (same persona as owner mock for V1 continuity).
final PublicProfileBundle nimonDemoPublicProfile = PublicProfileBundle(
  displayName: 'Just4withYou',
  handle: '@just4withyou',
  bio: 'Japanese micro-stories • daily reading',
  coverImageUrl: 'https://picsum.photos/seed/nimoncover/1200/400',
  avatarUrl: 'https://picsum.photos/seed/nimonavatar/200/200',
  storiesCount: 4,
  followersCount: 128,
  followingCount: 24,
  featuredStoryId: 'pub_s_1',
  stories: const [
    PublicStory(
      id: 'pub_s_1',
      title: '雨上がりの駅で',
      description: '改札前で起きた小さな出会いと、言えなかった一言。',
      jlptLevel: 'N4',
      thumbnailUrl: 'https://picsum.photos/seed/pub1/300/300',
      readMinutes: 4,
    ),
    PublicStory(
      id: 'pub_s_2',
      title: '引き出しの古い鍵',
      description: '使われなくなった鍵が、忘れていた約束を思い出させる。',
      jlptLevel: 'N3',
      thumbnailUrl: 'https://picsum.photos/seed/pub2/300/300',
      readMinutes: 5,
    ),
    PublicStory(
      id: 'pub_s_3',
      title: '窓辺のコーヒー',
      description: '朝の光と静かな時間が、一日の始まりを整える。',
      jlptLevel: 'N5',
      thumbnailUrl: 'https://picsum.photos/seed/pub3/300/300',
      readMinutes: 3,
    ),
    PublicStory(
      id: 'pub_s_4',
      title: '夜行バスの窓',
      description: '流れる街の灯りの中で、ふと思い出した故郷の話。',
      jlptLevel: 'N4',
      thumbnailUrl: 'https://picsum.photos/seed/pub4/300/300',
      readMinutes: 6,
    ),
  ],
  folders: const [
    PublicFolder(
      id: 'pub_f_1',
      name: 'Seasonal shorts',
      description: 'Small stories tied to weather and light.',
      coverImageUrl: 'https://picsum.photos/seed/pubf1/400/240',
      storyIds: ['pub_s_1', 'pub_s_3'],
    ),
    PublicFolder(
      id: 'pub_f_2',
      name: 'N3 practice picks',
      description: 'Slightly longer reads for intermediate learners.',
      coverImageUrl: 'https://picsum.photos/seed/pubf2/400/240',
      storyIds: ['pub_s_2', 'pub_s_4'],
    ),
    PublicFolder(
      id: 'pub_f_3',
      name: 'Quiet moments',
      description: 'Calm pacing and everyday scenes.',
      coverImageUrl: 'https://picsum.photos/seed/pubf3/400/240',
      storyIds: ['pub_s_3', 'pub_s_1'],
    ),
  ],
);
