import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:nimon/data/story_repo.dart';
import 'package:nimon/models/story.dart';
import '../models/section_key.dart';
import '../models/filter_state.dart';
import '../models/oneshot.dart';
import 'story_repo.dart';
import '../models/story.dart';

final _uuid = const Uuid();

final List<String> _covers = List.generate(
  12,
      (i) => 'https://picsum.photos/seed/nimon$i/600/800.webp',
);

late final List<Story> _stories = _genStories();
late final List<Episode> _episodes = _genEpisodes();
late final List<OneShot> _oneShots = _genOneShots();

List<Story> _genStories() {
  final rnd = Random(7);
  final lv = ['N5', 'N4', 'N3', 'N2'];
  // 10 story type categories
  final categories = [
    'Love',
    'Comedy',
    'Horror',
    'Cultural',
    'Adventure',
    'Fantasy',
    'Drama',
    'Business',
    'Sci-Fi',
    'Mystery',
  ];
  return List.generate(50, (i) {
    return Story(
      id: _uuid.v4(),
      title: 'Story #${i + 1} – Rainy Kyoto',
      description:
      'A rainy-day encounter in Kyoto leads to small conversations, warm umbrellas, and gentle lessons.',
      coverUrl: _covers[i % _covers.length],
      jlptLevel: lv[i % lv.length],
      tags: [categories[i % categories.length]],
      likes: rnd.nextInt(500) + 10,
    );
  });
}

String _getEpisodeTitle(int episodeNumber) {
  final episodeTitles = [
    'The Beginning',
    'First Meeting',
    'A New Day',
    'Unexpected Encounter',
    'Growing Closer',
    'The Challenge',
    'A Moment of Truth',
    'New Horizons',
    'The Journey Continues',
    'Looking Forward',
  ];
  return episodeTitles[(episodeNumber - 1) % episodeTitles.length];
}

List<Episode> _genEpisodes() {
  final rnd = Random(9);
  final List<Episode> list = [];
  for (final s in _stories) {
    final count = 3 + rnd.nextInt(6); // 3..8
    for (int e = 1; e <= count; e++) {
      list.add(Episode(
        id: _uuid.v4(),
        storyId: s.id,
        index: e,
        title: 'Episode $e: ${_getEpisodeTitle(e)}',
        blocks: [
          EpisodeBlock(
            type: BlockType.narration,
            text:
            'Rain was falling softly in Kyoto. Aya stood under her umbrella. (Ep $e)',
          ),
          EpisodeBlock(type: BlockType.dialog, speaker: 'YAMADA', text: 'あ… かさ を わすれました。'),
          EpisodeBlock(type: BlockType.dialog, speaker: 'AYANA', text: 'いっしょに いきますか。'),
          EpisodeBlock(
            type: BlockType.narration,
            text:
            'Aya tilted her umbrella, covering him too. Their shoulders touched slightly.',
          ),
        ],
      ));
    }
  }
  return list;
}

List<OneShot> _genOneShots() {
  final rnd = Random(13);
  final lv = ['N5', 'N4', 'N3', 'N2', 'N1'];
  final writers = ['Writer Tanaka', 'Writer Sato', 'Writer Kimura', 'Writer Yamamoto', 'Writer Suzuki'];
  
  return List.generate(20, (i) {
    return OneShot(
      id: _uuid.v4(),
      title: 'Mono Story #${i + 1} – Quick Adventure',
      coverUrl: _covers[i % _covers.length],
      writerName: writers[i % writers.length],
      jlpt: lv[i % lv.length],
      likes: rnd.nextInt(5000) + 100,
      monoNo: i + 1,
    );
  });
}

class StoryRepoMock implements StoryRepo {
  @override
  Future<List<Story>> listStories({String? filter}) async => _stories;

  @override
  Future<List<Story>> getStories({String? rank, String? category}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    Iterable<Story> result = _stories;
    if (rank != null && rank != 'ALL') {
      result = result.where((s) => s.jlptLevel == rank);
    }
    if (category != null && category != 'ALL') {
      result = result.where((s) => s.tags.contains(category));
    }
    return result.toList();
  }

  @override
  Future<Story?> getStoryById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    try {
      return _stories.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Episode>> getEpisodesByStory(String storyId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final list = _episodes.where((e) => e.storyId == storyId).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return list;
  }

  @override
  Future<void> addEpisode({required Episode episode}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final nextIndex = (_episodes
        .where((e) => e.storyId == episode.storyId)
        .map((e) => e.index)
        .fold<int>(0, (p, c) => c > p ? c : p)) +
        1;
    _episodes.add(episode.copyWith(
      id: _uuid.v4(),
      index: nextIndex,
    ));
  }

  @override
  Future<List<dynamic>> getQuizByStory(String storyId) async => [];

  @override
  Future<List<Story>> getStoriesBySection(SectionKey section) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    
    // Return different subsets based on section
    switch (section) {
      case SectionKey.continueReading:
        // Return stories user has started reading (mock: first 5 stories)
        return _stories.take(5).toList();
      
      case SectionKey.recommendStories:
        // Return recommended stories (mock: stories with high likes)
        final recommended = _stories.where((s) => s.likes > 200).toList();
        recommended.shuffle(Random(42));
        return recommended;
      
      case SectionKey.trendingForYou:
        // Return trending stories (mock: most liked stories)
        final trending = List<Story>.from(_stories);
        trending.sort((a, b) => b.likes.compareTo(a.likes));
        return trending.take(20).toList();
      
      case SectionKey.fromTheCommunity:
        // Return community stories (mock: random selection)
        final community = List<Story>.from(_stories);
        community.shuffle(Random(123));
        return community.take(15).toList();
      
      case SectionKey.topCharts:
        // Return top chart stories (mock: highest liked)
        final topCharts = List<Story>.from(_stories);
        topCharts.sort((a, b) => b.likes.compareTo(a.likes));
        return topCharts;
      
      case SectionKey.popularMonoCollections:
      case SectionKey.newWritersSpotlight:
      case SectionKey.readingChallenges:
        // These sections don't support see more
        return [];
    }
  }

  @override
  Future<List<Story>> getFilteredStories(SectionKey section, FilterState filter) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    
    // Get base stories for the section
    List<Story> stories = await getStoriesBySection(section);
    
    // Apply level filter
    if (filter.selectedLevel != null) {
      stories = stories.where((s) => s.jlptLevel == filter.selectedLevel).toList();
    }
    
    // Apply category filter
    if (filter.selectedCategory != null) {
      stories = stories.where((s) => s.tags.contains(filter.selectedCategory)).toList();
    }
    
    // Apply sorting
    switch (filter.sortBy) {
      case SortBy.newest:
        // Mock: reverse order (assuming newer stories have higher indices)
        stories = stories.reversed.toList();
        break;
      case SortBy.oldest:
        // Keep original order
        break;
      case SortBy.mostPopular:
      case SortBy.mostLiked:
        stories.sort((a, b) => b.likes.compareTo(a.likes));
        break;
      case SortBy.alphabetical:
        stories.sort((a, b) => a.title.compareTo(b.title));
        break;
    }
    
    return stories;
  }

  @override
  Future<List<OneShot>> fetchQuickOneShots() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // Return personalized one-shots (mock: shuffle and take first 10)
    final personalized = List<OneShot>.from(_oneShots);
    personalized.shuffle(Random(456));
    return personalized.take(10).toList();
  }
}
