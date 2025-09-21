class StoryRepoMock {
  Future<List<dynamic>> getStories({String? level}) async => [
    {
      'id': '1',
      'title': 'ONE PIECE of the pirate…',
      'level': 'N5',
      'description': '海の冒険が始まる。N5語彙で書かれたサンプルストーリー。',
      'coverUrl': '',
      'tags': ['Adventure','Sea'],
      'episodes': 2,
    },
    {
      'id': '2',
      'title': '学校の朝',
      'level': 'N5',
      'description': 'きょうは学校へ…',
      'coverUrl': '',
      'tags': ['Daily','School'],
      'episodes': 1,
    }
  ];

  Future<dynamic> getStoryById(String id) async {
    final list = await getStories();
    return list.firstWhere((x) => x['id'] == id, orElse: () => null);
  }

  Future<List<dynamic>> getEpisodesByStory(String storyId) async => [
    {'index': 1, 'text': 'きょう、きょうとは あめ です。', 'preview': 'きょう…'},
    {'index': 2, 'text': 'つぎ の ひ、そら は はれ でした。', 'preview': 'つぎ の ひ…'},
  ];

  Future<void> addEpisode(dynamic episode) async {}
}
