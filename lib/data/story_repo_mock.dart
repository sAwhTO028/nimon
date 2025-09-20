// C:\nimon\nimon\lib\data\story_repo_mock.dart
import '../models/story.dart';
import '../models/episode.dart';
import '../models/quiz_item.dart';
import 'story_repo.dart';

class StoryRepoMock implements StoryRepo {
  final List<Story> _stories = <Story>[
    Story(
      id: 's_1',
      title: 'Rainy Kyoto',
      theme: 'rain',
      creatorId: 'u_1',
      level: 'N5',
      desc: 'A rainy-day encounter in Kyoto.',
      likes: 12,
    ),
    Story(
      id: 's_2',
      title: 'Morning at School',
      theme: 'school',
      creatorId: 'u_1',
      level: 'N5',
      desc: 'First day of class.',
      likes: 7,
    ),
  ];

  final List<Episode> _episodes = <Episode>[
    Episode(id: 'e_1', storyId: 's_1', order: 1, type: 'narration', speaker: null, text: 'きょう、きょうとは あめ です。'),
    Episode(id: 'e_2', storyId: 's_1', order: 2, type: 'dialog',    speaker: 'YAMADA', text: 'かさ を わすれました。'),
    Episode(id: 'e_3', storyId: 's_1', order: 3, type: 'dialog',    speaker: 'AYANA',  text: 'いっしょに いきますか。'),
    Episode(id: 'e_4', storyId: 's_2', order: 1, type: 'narration', speaker: null,     text: 'わたし は きょう がっこうへ いきます。'),
  ];

  final List<QuizItem> _quizzes = <QuizItem>[
    QuizItem(
      id: 'q1', storyId: 's_1', type: 'mcq',
      question: '「あめ」の いみ は？',
      choices: ['Snow','Rain','Wind','Sunny'],
      answerIndex: 1, xp: 5,
    ),
    QuizItem(
      id: 'q2', storyId: 's_1', type: 'fill',
      question: '（　）を わすれました。',
      answer: 'かさ', xp: 5,
    ),
    QuizItem(
      id: 'q3', storyId: 's_2', type: 'mcq',
      question: '「がっこう」の いμι は？',
      choices: ['Hospital','School','Park','Station'],
      answerIndex: 1, xp: 5,
    ),
  ];

  // -------- Interface methods --------
  @override
  Future<List<Story>> getStories({String? level}) async {
    if (level == null) return _stories;
    return _stories.where((s) => s.level == level).toList();
  }

  @override
  Future<Story?> getStoryById(String id) async {
    try {
      return _stories.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Episode>> getEpisodesByStory(String storyId) async {
    final eps = _episodes.where((e) => e.storyId == storyId).toList()
      ..sort((a,b)=>a.order.compareTo(b.order));
    return eps;
  }

  @override
  Future<void> addEpisode({
    required String storyId,
    required Episode episode,
  }) async {
    // order auto if needed
    final nextOrder = (_episodes.where((e)=>e.storyId==storyId).map((e)=>e.order).fold<int>(0, (p,c)=>c>p?c:p)) + 1;
    final ep = Episode(
      id: episode.id,
      storyId: storyId,
      order: episode.order == 0 ? nextOrder : episode.order,
      type: episode.type,
      speaker: episode.speaker,
      text: episode.text,
    );
    _episodes.add(ep);
  }

  @override
  Future<List<QuizItem>> getQuizByStory(String storyId) async {
    return _quizzes.where((q)=>q.storyId==storyId).toList();
  }

  // -------- Optional aliases (for old UI calls) --------
  Future<List<Story>> listStories() => getStories();
  Future<List<Episode>> listEpisodes(String storyId) => getEpisodesByStory(storyId);
  Future<List<QuizItem>> listQuiz(String storyId) => getQuizByStory(storyId);
}
