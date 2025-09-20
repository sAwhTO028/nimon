import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class LocalDataLoader {
  Future<List<Map<String, dynamic>>> _loadList(String path) async {
    final s = await rootBundle.loadString(path);
    return (json.decode(s) as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> loadUsersRaw() => _loadList('assets/data/users.json');
  Future<List<Map<String, dynamic>>> loadStoriesRaw() => _loadList('assets/data/stories.json');
  Future<List<Map<String, dynamic>>> loadEpisodesRaw() => _loadList('assets/data/episodes.json');
  Future<List<Map<String, dynamic>>> loadVocabIndexRaw() => _loadList('assets/data/vocab_index.json');
  Future<List<Map<String, dynamic>>> loadQuizzesRaw() => _loadList('assets/data/quizzes.json');
}
