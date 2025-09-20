// lib/data/story_repo.dart
import '../models/story.dart';
import '../models/episode.dart';
import '../models/quiz_item.dart';

abstract class StoryRepo {
  Future<List<Story>> getStories({String? level});
  Future<Story?> getStoryById(String id);
  Future<List<Episode>> getEpisodesByStory(String storyId);
  Future<void> addEpisode({
    required String storyId,
    required Episode episode,
  });
  Future<List<QuizItem>> getQuizByStory(String storyId);
}
