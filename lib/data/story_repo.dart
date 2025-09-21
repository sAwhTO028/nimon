import 'package:nimon/models/story.dart';
import 'package:nimon/models/episode.dart';

abstract class StoryRepo {
  Future<List<Story>> getStories({String? level});
  Future<Story?> getStoryById(String id);
  Future<List<Episode>> getEpisodesByStory(String storyId);
  Future<List<QuizItem>> getQuizByStory(String storyId);

  Future<void> addEpisode({required Episode episode});
  // Optional: reorder
  Future<void> reorderEpisodes(String storyId, List<Episode> newOrder) async {}
}
