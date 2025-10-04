import 'package:nimon/models/story.dart';
import '../models/section_key.dart';
import '../models/filter_state.dart';
import '../models/oneshot.dart';

abstract class StoryRepo {
  Future<List<Story>> listStories({String? filter});
  Future<List<Story>> getStories({String? rank, String? category});  // Home/Mono
  Future<Story?> getStoryById(String id);
  Future<List<Episode>> getEpisodesByStory(String storyId);

  Future<void> addEpisode({required Episode episode}); // Writer → append

  // Placeholder for later (Quiz)
  Future<List<dynamic>> getQuizByStory(String storyId);

  // New methods for See More functionality
  Future<List<Story>> getStoriesBySection(SectionKey section);
  Future<List<Story>> getFilteredStories(SectionKey section, FilterState filter);
  
  // OneShot methods
  Future<List<OneShot>> fetchQuickOneShots(); // personalized one-shots
}
