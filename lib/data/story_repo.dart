import 'package:nimon/models/story.dart';

abstract class StoryRepo {
  Future<List<Story>> getStories({String? level});  // Home/Mono
  Future<Story?> getStoryById(String id);
  Future<List<Episode>> getEpisodesByStory(String storyId);

  Future<void> addEpisode({required Episode episode}); // Writer → append

  // Placeholder for later (Quiz)
  Future<List<dynamic>> getQuizByStory(String storyId);
}
