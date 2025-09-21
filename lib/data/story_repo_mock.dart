// imports...
final _stories = <Story>[ /* …demo… */ ];
final _episodes = <Episode>[ /* …demo episodes… */ ];

class StoryRepoMock implements StoryRepo {
  @override
  Future<List<Story>> getStories({String? level}) async => _stories;

  @override
  Future<Story?> getStoryById(String id) async =>
      _stories.firstWhere((s) => s.id == id);

  @override
  Future<List<Episode>> getEpisodesByStory(String storyId) async =>
      _episodes.where((e) => e.storyId == storyId).toList()..sort((a,b)=>a.index.compareTo(b.index));

  @override
  Future<void> addEpisode({required Episode episode}) async {
    final next = (_episodes.where((e)=>e.storyId==episode.storyId).map((e)=>e.index).fold<int>(0, (p,c)=>c>p?c:p)) + 1;
    _episodes.add(episode.copyWith(id: UniqueKey().toString(), index: next));
  }

  @override
  Future<List<QuizItem>> getQuizByStory(String storyId) async => [];
}
