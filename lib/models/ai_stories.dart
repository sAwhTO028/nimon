import 'story_category.dart';
import 'package:flutter/foundation.dart';

/// Request model for AI-Stories generation
class AiStoriesGenerateRequest {
  final String youtubeUrl;
  final String? targetLevel; // N5, N4, N3, N2, N1
  final bool autoCategory; // Always true - backend must classify

  const AiStoriesGenerateRequest({
    required this.youtubeUrl,
    this.targetLevel,
    this.autoCategory = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'youtubeUrl': youtubeUrl,
      if (targetLevel != null) 'targetLevel': targetLevel,
      'autoCategory': autoCategory,
    };
  }
}

/// Response model for AI-Stories generation
class AiStoriesGenerateResponse {
  final String storyId;
  final String title;
  final String description;
  final StoryCategory category; // Auto-detected category
  final String jlptLevel; // N5..N1
  final List<EpisodeContent> episodes;
  final String? coverUrl;
  final String? videoThumbnailUrl;

  const AiStoriesGenerateResponse({
    required this.storyId,
    required this.title,
    required this.description,
    required this.category,
    required this.jlptLevel,
    required this.episodes,
    this.coverUrl,
    this.videoThumbnailUrl,
  });

  factory AiStoriesGenerateResponse.fromJson(Map<String, dynamic> json) {
    final categoryStr = json['category'] as String? ?? 'cultural';
    final category = StoryCategory.fromString(categoryStr) ??
        StoryCategory.cultural; // Fallback to cultural

    return AiStoriesGenerateResponse(
      storyId: json['storyId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: category,
      jlptLevel: json['jlptLevel'] as String? ?? 'N4',
      episodes: (json['episodes'] as List<dynamic>?)
              ?.map((e) => EpisodeContent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      coverUrl: json['coverUrl'] as String?,
      videoThumbnailUrl: json['videoThumbnailUrl'] as String?,
    );
  }
}

/// Episode content within AI-Stories response
class EpisodeContent {
  final int index;
  final String title;
  final String content; // Full episode text
  final List<String>? blocks; // Optional structured blocks

  const EpisodeContent({
    required this.index,
    required this.title,
    required this.content,
    this.blocks,
  });

  factory EpisodeContent.fromJson(Map<String, dynamic> json) {
    return EpisodeContent(
      index: json['index'] as int,
      title: json['title'] as String,
      content: json['content'] as String,
      blocks: (json['blocks'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }
}

