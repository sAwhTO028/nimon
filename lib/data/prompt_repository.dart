import 'package:flutter/foundation.dart';

enum JlptLevel { n5, n4, n3, n2, n1 }

class Prompt {
  final String id;
  final String title;
  final String context;
  final String duration; // e.g., '4–6 minutes'
  final String category; // 'Love' | 'Comedy' | ...
  final JlptLevel level;

  const Prompt({
    required this.id,
    required this.title,
    required this.context,
    required this.duration,
    required this.category,
    required this.level,
  });
}

class PromptRepository {
  static final List<Prompt> _baseMocks = _buildMocks();
  static final List<Prompt> _customPrompts = <Prompt>[];

  static List<Prompt> get _mocks => [..._baseMocks, ..._customPrompts];

  static List<Prompt> find({
    required JlptLevel level,
    required String category,
    int limit = 5,
  }) {
    final base = _mocks
        .where((p) => p.level == level && p.category == category)
        .toList();
    return base.take(limit).toList();
  }

  static String durationStringFor(JlptLevel level) {
    switch (level) {
      case JlptLevel.n5:
        return '4–6 minutes';
      case JlptLevel.n4:
        return '5–7 minutes';
      case JlptLevel.n3:
        return '6–8 minutes';
      case JlptLevel.n2:
        return '7–9 minutes';
      case JlptLevel.n1:
        return '8–10 minutes';
    }
  }

  static List<Prompt> fallbackFor(JlptLevel level, String category, {int count = 12}) {
    return List.generate(count, (i) {
      return Prompt(
        id: 'fallback_${category.toLowerCase()}_${i + 1}',
        title: '${category.toUpperCase()} IDEA #${i + 1}',
        context: 'A ${describeEnum(level).toUpperCase()} short story about $category, variation ${i + 1}.',
        duration: '5–7 minutes',
        category: category,
        level: level,
      );
    });
  }

  static Prompt createCustom({
    required JlptLevel level,
    required String category,
    required String title,
    required String context,
    required String duration,
  }) {
    return Prompt(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      context: context,
      duration: duration,
      category: category,
      level: level,
    );
  }

  static void addCustomPrompt(Prompt prompt) {
    _customPrompts.add(prompt);
  }

  static void clearCustomPrompts() {
    _customPrompts.clear();
  }

  static List<Prompt> _buildMocks() {
    final List<Prompt> all = [];
    
    // Helper to generate prompts
    void addBatch(JlptLevel level, String category, String duration, int count) {
      for (int i = 1; i <= count; i++) {
        all.add(Prompt(
          id: '${describeEnum(level)}-${category.toLowerCase()}-$i',
          title: '${category.toUpperCase()} IDEA #$i',
          context: 'An ${describeEnum(level).toUpperCase()} short story about $category theme, variation $i.',
          duration: duration,
          category: category,
          level: level,
        ));
      }
    }

    // N5: 15 per category
    addBatch(JlptLevel.n5, 'Love', '4–6 minutes', 15);
    addBatch(JlptLevel.n5, 'Comedy', '4–6 minutes', 15);
    addBatch(JlptLevel.n5, 'Horror', '4–6 minutes', 15);
    addBatch(JlptLevel.n5, 'Cultural', '4–6 minutes', 15);
    addBatch(JlptLevel.n5, 'Adventure', '4–6 minutes', 15);
    addBatch(JlptLevel.n5, 'Fantasy', '4–6 minutes', 15);
    addBatch(JlptLevel.n5, 'Drama', '4–6 minutes', 15);
    addBatch(JlptLevel.n5, 'Business', '4–6 minutes', 15);
    addBatch(JlptLevel.n5, 'Sci-Fi', '4–6 minutes', 15);
    addBatch(JlptLevel.n5, 'Mystery', '4–6 minutes', 15);

    // N4: 15 per category
    addBatch(JlptLevel.n4, 'Love', '5–7 minutes', 15);
    addBatch(JlptLevel.n4, 'Comedy', '5–7 minutes', 15);
    addBatch(JlptLevel.n4, 'Horror', '5–7 minutes', 15);
    addBatch(JlptLevel.n4, 'Cultural', '5–7 minutes', 15);
    addBatch(JlptLevel.n4, 'Adventure', '5–7 minutes', 15);
    addBatch(JlptLevel.n4, 'Fantasy', '5–7 minutes', 15);
    addBatch(JlptLevel.n4, 'Drama', '5–7 minutes', 15);
    addBatch(JlptLevel.n4, 'Business', '5–7 minutes', 15);
    addBatch(JlptLevel.n4, 'Sci-Fi', '5–7 minutes', 15);
    addBatch(JlptLevel.n4, 'Mystery', '5–7 minutes', 15);

    // N3: 15 per category
    addBatch(JlptLevel.n3, 'Love', '6–8 minutes', 15);
    addBatch(JlptLevel.n3, 'Comedy', '6–8 minutes', 15);
    addBatch(JlptLevel.n3, 'Horror', '6–8 minutes', 15);
    addBatch(JlptLevel.n3, 'Cultural', '6–8 minutes', 15);
    addBatch(JlptLevel.n3, 'Adventure', '6–8 minutes', 15);
    addBatch(JlptLevel.n3, 'Fantasy', '6–8 minutes', 15);
    addBatch(JlptLevel.n3, 'Drama', '6–8 minutes', 15);
    addBatch(JlptLevel.n3, 'Business', '6–8 minutes', 15);
    addBatch(JlptLevel.n3, 'Sci-Fi', '6–8 minutes', 15);
    addBatch(JlptLevel.n3, 'Mystery', '6–8 minutes', 15);

    // N2: 15 per category
    addBatch(JlptLevel.n2, 'Love', '7–9 minutes', 15);
    addBatch(JlptLevel.n2, 'Comedy', '7–9 minutes', 15);
    addBatch(JlptLevel.n2, 'Horror', '7–9 minutes', 15);
    addBatch(JlptLevel.n2, 'Cultural', '7–9 minutes', 15);
    addBatch(JlptLevel.n2, 'Adventure', '7–9 minutes', 15);
    addBatch(JlptLevel.n2, 'Fantasy', '7–9 minutes', 15);
    addBatch(JlptLevel.n2, 'Drama', '7–9 minutes', 15);
    addBatch(JlptLevel.n2, 'Business', '7–9 minutes', 15);
    addBatch(JlptLevel.n2, 'Sci-Fi', '7–9 minutes', 15);
    addBatch(JlptLevel.n2, 'Mystery', '7–9 minutes', 15);

    // N1: 15 per category
    addBatch(JlptLevel.n1, 'Love', '8–10 minutes', 15);
    addBatch(JlptLevel.n1, 'Comedy', '8–10 minutes', 15);
    addBatch(JlptLevel.n1, 'Horror', '8–10 minutes', 15);
    addBatch(JlptLevel.n1, 'Cultural', '8–10 minutes', 15);
    addBatch(JlptLevel.n1, 'Adventure', '8–10 minutes', 15);
    addBatch(JlptLevel.n1, 'Fantasy', '8–10 minutes', 15);
    addBatch(JlptLevel.n1, 'Drama', '8–10 minutes', 15);
    addBatch(JlptLevel.n1, 'Business', '8–10 minutes', 15);
    addBatch(JlptLevel.n1, 'Sci-Fi', '8–10 minutes', 15);
    addBatch(JlptLevel.n1, 'Mystery', '8–10 minutes', 15);

    return all;
  }
}
