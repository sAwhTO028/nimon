import '../models/ai_stories.dart';
import '../models/story_category.dart';

/// Repository for AI-Stories generation
abstract class AiStoriesRepository {
  /// Generate a story from a YouTube URL
  /// Returns the generated story with auto-detected category
  Future<AiStoriesGenerateResponse> generateStory(
    AiStoriesGenerateRequest request,
  );
}

/// Mock implementation for development
class MockAiStoriesRepository implements AiStoriesRepository {
  @override
  Future<AiStoriesGenerateResponse> generateStory(
    AiStoriesGenerateRequest request,
  ) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 2));

    // Mock response - in real implementation, this would call the backend
    return AiStoriesGenerateResponse(
      storyId: 'ai_story_${DateTime.now().millisecondsSinceEpoch}',
      title: 'AI Generated Story from YouTube',
      description:
          'A story generated from the provided YouTube video. The category has been automatically detected.',
      category: StoryCategory.comedy, // Mock detected category
      jlptLevel: request.targetLevel ?? 'N4',
      episodes: [
        EpisodeContent(
          index: 1,
          title: 'Episode 1: Beginning',
          content: 'This is a mock episode content generated from the video.',
        ),
      ],
      coverUrl: null,
      videoThumbnailUrl: null,
    );
  }
}

