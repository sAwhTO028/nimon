import 'package:flutter/foundation.dart';
import 'story.dart';

@immutable
class EpisodeMeta {
  final String id;
  final String title;
  final String episodeNo; // "Episode 7"
  final String authorName;
  final String coverUrl;
  final String jlpt; // "N5" .. "N1"
  final int likes; // 4200
  final String readTime; // "5 min"
  final String category; // "Love"
  final String preview; // short excerpt

  const EpisodeMeta({
    required this.id,
    required this.title,
    required this.episodeNo,
    required this.authorName,
    required this.coverUrl,
    required this.jlpt,
    required this.likes,
    required this.readTime,
    required this.category,
    required this.preview,
  });

  factory EpisodeMeta.fromEpisodeAndStory({
    required Episode episode,
    required Story story,
    required String authorName,
  }) {
    return EpisodeMeta(
      id: episode.id,
      title: episode.title ?? 'Episode ${episode.index}',
      episodeNo: 'Episode ${episode.index}',
      authorName: authorName,
      coverUrl: episode.thumbnailUrl ?? story.coverUrl ?? '',
      jlpt: story.jlptLevel,
      likes: story.likes,
      readTime: '${(episode.blocks.length * 0.5).ceil()} min',
      category: story.tags.isNotEmpty ? story.tags.first : 'Story',
      preview: episode.preview,
    );
  }
}
