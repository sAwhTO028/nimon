class QuizItem {
  final String id;
  final String storyId;
  final String type; // 'mcq' | 'fill'
  final String question;
  final List<String>? choices;
  final int? answerIndex;
  final String? answer;
  final int xp;

  QuizItem({
    required this.id, required this.storyId, required this.type,
    required this.question, this.choices, this.answerIndex, this.answer,
    this.xp = 5,
  });

  factory QuizItem.fromJson(Map<String, dynamic> j) => QuizItem(
    id: j['id'],
    storyId: j['storyId'],
    type: j['type'],
    question: j['question'],
    choices: (j['choices'] as List?)?.map((e) => e.toString()).toList(),
    answerIndex: j['answerIndex'],
    answer: j['answer'],
    xp: j['xp'] ?? 5,
  );
}
