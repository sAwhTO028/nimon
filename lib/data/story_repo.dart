import 'package:nimon/models/story.dart';

abstract class StoryRepo {
  Future<List<Story>> listStories({String? filter});
  Future<List<Story>> getStories({String? rank, String? category});  // Home/Mono
  Future<Story?> getStoryById(String id);
  Future<List<Episode>> getEpisodesByStory(String storyId);

  Future<void> addEpisode({required Episode episode}); // Writer → append

  // Placeholder for later (Quiz)
  Future<List<dynamic>> getQuizByStory(String storyId);
}
