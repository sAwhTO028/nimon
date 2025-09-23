import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:nimon/data/story_repo.dart';
import 'package:nimon/models/story.dart';
import 'story_repo.dart';
import '../models/story.dart';

final _uuid = const Uuid();

final List<String> _covers = List.generate(
  12,
      (i) => 'https://picsum.photos/seed/nimon$i/600/800.webp',
);

late final List<Story> _stories = _genStories();
late final List<Episode> _episodes = _genEpisodes();

List<Story> _genStories() {
  final rnd = Random(7);
  final lv = ['N5', 'N4', 'N3', 'N2'];
  final tags = ['Love', 'School', 'Kyoto', 'Work', 'Cafe', 'Rain', 'Trip'];
  return List.generate(50, (i) {
    return Story(
      id: _uuid.v4(),
      title: 'Story #${i + 1} – Rainy Kyoto',
      description:
      'A rainy-day encounter in Kyoto leads to small conversations, warm umbrellas, and gentle lessons.',
      coverUrl: _covers[i % _covers.length],
      jlptLevel: lv[i % lv.length],
      tags: [tags[i % tags.length], tags[(i + 3) % tags.length]],
      likes: rnd.nextInt(500) + 10,
    );
  });
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

class StoryRepoMock implements StoryRepo {
  @override
  Future<List<Story>> listStories({String? filter}) async => _stories;

  @override
  Future<List<Story>> getStories({String? level}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (level == null) return _stories;
    return _stories.where((s) => s.jlptLevel == level).toList();
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
}
