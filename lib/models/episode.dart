class Episode {
  final String id;
  final String storyId;
  final int order;
  final String type;     // 'narration' | 'dialog'
  final String? speaker; // for dialog
  final String text;

  Episode({
    required this.id, required this.storyId, required this.order,
    required this.type, this.speaker, required this.text,
  });

  factory Episode.fromJson(Map<String, dynamic> j) => Episode(
    id: j['id'],
    storyId: j['storyId'],
    order: j['order'],
    type: j['type'],
    speaker: j['speaker'],
    text: j['text'],
  );
}
