import 'package:flutter/foundation.dart';
import 'story_category.dart';

enum BlockType { narration, dialog }

@immutable
class EpisodeBlock {
  final BlockType type;
  final String text;
  final String? speaker;

  const EpisodeBlock({
    required this.type,
    required this.text,
    this.speaker,
  });
}

@immutable
class Episode {
  final String id;
  final String storyId;
  final int index;
  final List<EpisodeBlock> blocks;
  final String? thumbnailUrl;
  final String? title;

  const Episode({
    required this.id,
    required this.storyId,
    required this.index,
    required this.blocks,
    this.thumbnailUrl,
    this.title,
  });

  String get preview {
    if (blocks.isEmpty) return '';
    final first = blocks.first;
    return first.text.length > 80 ? '${first.text.substring(0, 80)}…' : first.text;
  }

  Episode copyWith({
    String? id,
    String? storyId,
    int? index,
    List<EpisodeBlock>? blocks,
    String? thumbnailUrl,
    String? title,
  }) =>
      Episode(
        id: id ?? this.id,
        storyId: storyId ?? this.storyId,
        index: index ?? this.index,
        blocks: blocks ?? this.blocks,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        title: title ?? this.title,
      );
}

@immutable
class Story {
  final String id;
  final String title;
  final String description;
  final String? coverUrl;
  final String jlptLevel; // N5..N1
  final List<String> tags;
  final int likes;
  final StoryCategory? category; // Auto-detected or manually selected category
  final StorySourceType? sourceType; // How the story was created

  const Story({
    required this.id,
    required this.title,
    required this.description,
    this.coverUrl,
    required this.jlptLevel,
    required this.tags,
    required this.likes,
    this.category,
    this.sourceType,
  });
}

/// Source type for stories (how they were created)
enum StorySourceType {
  manual, // Created manually by user
  ai, // Generated from YouTube URL via AI
}

