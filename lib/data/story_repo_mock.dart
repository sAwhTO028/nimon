import 'package:nimon/models/story.dart';

/// Very thin shim used by the new StoryDetail/Writer UI to compile without
/// depending on old interfaces. Replace with real repository later.
class StoryRepoMock {
  Future<List<Story>> listStories() async => <Story>[];

  Future<Story?> getStoryById(String id) async => null;

  Future<List<Episode>> listEpisodes(String storyId) async => <Episode>[];

  Future<void> addEpisode(dynamic episode) async {
    // no-op for UI-only prototype
  }

  Future<List<dynamic>> listQuiz(String storyId) async => <dynamic>[];
}
