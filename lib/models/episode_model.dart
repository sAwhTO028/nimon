import 'package:flutter/foundation.dart';
import 'episode_meta.dart';

/// Episode model for the M3 modal bottom sheet
@immutable
class EpisodeModel {
  final String title;
  final int number;
  final String writerName;
  final String preview;
  final String coverUrl;
  final String category;
  final String jlpt;
  final int likes;
  final Duration readTime;

  const EpisodeModel({
    required this.title,
    required this.number,
    required this.writerName,
    required this.preview,
    required this.coverUrl,
    required this.category,
    required this.jlpt,
    required this.likes,
    required this.readTime,
  });

  /// Convert from EpisodeMeta to EpisodeModel
  factory EpisodeModel.fromEpisodeMeta(EpisodeMeta meta) {
    // Parse read time from string (e.g., "5 min" -> Duration(minutes: 5))
    final readTimeMatch = RegExp(r'(\d+)').firstMatch(meta.readTime);
    final minutes = readTimeMatch != null ? int.parse(readTimeMatch.group(1)!) : 5;
    
    // Parse episode number from episodeNo (e.g., "Episode 7" -> 7)
    final episodeMatch = RegExp(r'(\d+)').firstMatch(meta.episodeNo);
    final episodeNumber = episodeMatch != null ? int.parse(episodeMatch.group(1)!) : 1;
    
    return EpisodeModel(
      title: meta.title,
      number: episodeNumber,
      writerName: meta.authorName,
      preview: meta.preview,
      coverUrl: meta.coverUrl,
      category: meta.category,
      jlpt: meta.jlpt,
      likes: meta.likes,
      readTime: Duration(minutes: minutes),
    );
  }

  /// Format read time for display
  String get readTimeFormatted {
    final minutes = readTime.inMinutes;
    return '${minutes} min';
  }

  /// Format likes count for display
  String get likesFormatted {
    if (likes >= 1000000) {
      return '${(likes / 1000000).toStringAsFixed(1)}M';
    } else if (likes >= 1000) {
      return '${(likes / 1000).toStringAsFixed(1)}K';
    }
    return likes.toString();
  }
}
