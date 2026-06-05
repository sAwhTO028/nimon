/// HTML generator limitation rules (source of truth).
///
/// IMPORTANT:
/// - Phase 1 config-only: this file must NOT change production behavior by itself.
/// - Values are copied verbatim from:
///   `tool/html_generator/Json_Generator_ImportReadyPrompt_v7.html`
library;

enum HtmlPromptMode { manual, ai }

enum HtmlLearningLanguage { jp, en }

enum HtmlPublishKind { readOnly, fullLearn }

enum HtmlLimitPreset { minimum, defaultValue, optimal, maximum }

String? normalizeHtmlLevel(String? input) {
  final raw = (input ?? '').trim();
  if (raw.isEmpty) return null;

  // Mirrors HTML: normalizeLevel(v) strips `^\d+\.` and trims.
  final stripped = raw.replaceFirst(RegExp(r'^\d+\.'), '').trim();
  if (stripped.isEmpty) return null;

  // Accept either "N5/A1" style or JLPT-only like "N4".
  final jlpt = stripped.split('/').first.trim().toUpperCase();
  return switch (jlpt) {
    'N5' => 'N5/A1',
    'N4' => 'N4/A2',
    'N3' => 'N3/B1',
    'N2' => 'N2/B2',
    'N1' => 'N1/C1',
    _ => stripped, // Already a concrete level (e.g. "N4/A2")
  };
}

String? normalizeHtmlDuration(String? input) {
  final raw = (input ?? '').trim();
  if (raw.isEmpty) return null;

  // Accept band keys (`3_5`) or friendly labels.
  final s = raw.toLowerCase();
  if (s.contains('3_5') || s.contains('3-5')) return '3-5 mins';
  if (s.contains('5_7') || s.contains('5-7')) return '5-7 mins';
  if (s.contains('7_9') || s.contains('7-9')) return '7-9 mins';
  return null;
}

HtmlLearningLanguage? normalizeHtmlLanguage(String? input) {
  final raw = (input ?? '').trim();
  if (raw.isEmpty) return null;

  final s = raw.toLowerCase();
  // JP
  if (s == 'jp' || s == 'ja' || s.contains('japanese') || s.contains('jp')) {
    // Note: The HTML normalizeLanguage(v) is effectively "contains 'En' ? EN : JP".
    // Here we broaden accepted inputs for config lookup.
    if (s.contains('en') && !s.contains('japanese')) {
      // avoid mapping "English" to JP because it contains "en".
    } else {
      return HtmlLearningLanguage.jp;
    }
  }
  // EN
  if (s == 'en' || s.contains('english')) return HtmlLearningLanguage.en;
  return null;
}

/// V1 prefs/draft wire (`ja` / `en`) → HTML limit table language.
///
/// Fallback to [HtmlLearningLanguage.jp] for null/unknown — validation context only;
/// does not mutate stored draft fields.
HtmlLearningLanguage resolveHtmlLearningLanguageFromWire(
  String? learningLanguageWire,
) {
  final t = (learningLanguageWire ?? '').trim().toLowerCase();
  if (t == 'en') return HtmlLearningLanguage.en;
  return HtmlLearningLanguage.jp;
}

HtmlPromptMode? normalizeHtmlPromptMode(String? input) {
  final raw = (input ?? '').trim();
  if (raw.isEmpty) return null;
  final s = raw.toLowerCase();
  if (s == 'manual' || s == 'manual_mode') return HtmlPromptMode.manual;
  if (s == 'ai' || s == 'ai_mode') return HtmlPromptMode.ai;
  return null;
}

/// Resolves HTML prompt mode from [StoryBasics.promptSourceNote] (import metadata lines).
///
/// Accepts `promptDataTab=AI_mode` / `AI_mode` → [HtmlPromptMode.ai],
/// `promptDataTab=Manual_mode` / `Manual_mode` → [HtmlPromptMode.manual].
/// Missing or unrecognized values default to manual (manual creator drafts).
HtmlPromptMode resolveHtmlPromptModeFromSourceNote(String? sourceNote) {
  final raw = (sourceNote ?? '').trim().toLowerCase();
  if (raw.contains('promptdatatab=ai_mode') || raw.contains('ai_mode')) {
    return HtmlPromptMode.ai;
  }
  if (raw.contains('promptdatatab=manual_mode') || raw.contains('manual_mode')) {
    return HtmlPromptMode.manual;
  }
  return HtmlPromptMode.manual;
}

HtmlPublishKind? normalizeHtmlPublishKind(String? input) {
  final raw = (input ?? '').trim();
  if (raw.isEmpty) return null;

  // Accept HTML UI labels like "2. FULL", and JSON publishKind strings.
  final stripped = raw.replaceFirst(RegExp(r'^\d+\.'), '').trim();
  final s = stripped.toLowerCase();
  if (s.contains('read_only') || s == 'read only' || s == 'readonly') {
    return HtmlPublishKind.readOnly;
  }
  if (s.contains('full_learn') ||
      s == 'full' ||
      s.contains('full learn') ||
      s == 'full_learn') {
    return HtmlPublishKind.fullLearn;
  }
  return null;
}

class HtmlSentenceLimit {
  const HtmlSentenceLimit({
    required this.minSentences,
    required this.maxSentences,
    required this.minChars,
    required this.maxChars,
  });

  final int minSentences;
  final int maxSentences;
  final int minChars;
  final int maxChars;
}

sealed class HtmlSelectedCount {
  const HtmlSelectedCount();
}

class HtmlCountRange extends HtmlSelectedCount {
  const HtmlCountRange({required this.min, required this.max});
  final int min;
  final int max;
}

class HtmlCountExact extends HtmlSelectedCount {
  const HtmlCountExact(this.value);
  final int value;
}

class HtmlLearnModuleLimit {
  const HtmlLearnModuleLimit({
    required this.manualMin,
    required this.manualMax,
    required this.minimum,
    required this.defaultValue,
    required this.optimal,
    required this.maximum,
  });

  final int manualMin;
  final int manualMax;
  final int minimum;
  final int defaultValue;
  final int optimal;
  final int maximum;

  HtmlSelectedCount selectedFor(HtmlPromptMode mode, HtmlLimitPreset preset) {
    if (mode == HtmlPromptMode.manual) {
      return HtmlCountRange(min: manualMin, max: manualMax);
    }
    final v = switch (preset) {
      HtmlLimitPreset.minimum => minimum,
      HtmlLimitPreset.defaultValue => defaultValue,
      HtmlLimitPreset.optimal => optimal,
      HtmlLimitPreset.maximum => maximum,
    };
    return HtmlCountExact(v);
  }
}

class HtmlQuizCategoryLimit {
  const HtmlQuizCategoryLimit({
    required this.manualMin,
    required this.manualMax,
    required this.minimum,
    required this.defaultValue,
    required this.optimal,
    required this.maximum,
  });

  final int manualMin;
  final int manualMax;
  final int minimum;
  final int defaultValue;
  final int optimal;
  final int maximum;

  HtmlSelectedCount selectedFor(HtmlPromptMode mode, HtmlLimitPreset preset) {
    if (mode == HtmlPromptMode.manual) {
      return HtmlCountRange(min: manualMin, max: manualMax);
    }
    final v = switch (preset) {
      HtmlLimitPreset.minimum => minimum,
      HtmlLimitPreset.defaultValue => defaultValue,
      HtmlLimitPreset.optimal => optimal,
      HtmlLimitPreset.maximum => maximum,
    };
    return HtmlCountExact(v);
  }
}

class HtmlFullLearnSelectedLimits {
  const HtmlFullLearnSelectedLimits({
    required this.vocabularyCount,
    required this.grammarCount,
    required this.vocabularyQuizCount,
    required this.grammarQuizCount,
    required this.sentenceQuizCount,
    required this.totalQuizCount,
  });

  final int vocabularyCount;
  final int grammarCount;
  final int vocabularyQuizCount;
  final int grammarQuizCount;
  final int sentenceQuizCount;
  final int totalQuizCount;
}

class HtmlGeneratorLimits {
  HtmlGeneratorLimits._();

  /// Mirrors HTML `sliderKeys = ["minimum","default","optimal","maximum"]`.
  static const List<String> sliderKeys = ['minimum', 'default', 'optimal', 'maximum'];

  static bool isSliderEnabled({
    required HtmlPublishKind publishKind,
    required HtmlPromptMode mode,
  }) {
    // Mirrors HTML: FULL + AI only.
    return publishKind == HtmlPublishKind.fullLearn && mode == HtmlPromptMode.ai;
  }

  static bool readOnlyNeedsLearnModules() => false;
  static bool fullLearnNeedsLearnModules() => true;

  /// Source-of-truth for future wiring; do not wire in this prompt.
  static bool fullLearnNeedsAudio() => true;

  static HtmlSentenceLimit? sentenceLimit({
    required HtmlPromptMode mode,
    required HtmlLearningLanguage language,
    required String duration,
    required String level,
  }) {
    final m = _sentenceLimits[mode];
    final l = m?[language];
    final d = l?[duration];
    return d?[level];
  }

  static HtmlLearnModuleLimit? vocabularyLimit({
    required HtmlLearningLanguage language,
    required String duration,
    required String level,
  }) =>
      _learnLimits[language]?[duration]?[level]?['Vocabulary'];

  static HtmlLearnModuleLimit? grammarLimit({
    required HtmlLearningLanguage language,
    required String duration,
    required String level,
  }) =>
      _learnLimits[language]?[duration]?[level]?['Grammar'];

  static HtmlQuizCategoryLimit? quizLimit({
    required String duration,
    required String level,
    required String quizCategory,
  }) =>
      _quizLimits[duration]?[level]?[quizCategory];

  static HtmlFullLearnSelectedLimits? selectedFullLearnLimits({
    required HtmlPromptMode mode,
    required HtmlLearningLanguage language,
    required String duration,
    required String level,
    required HtmlLimitPreset preset,
  }) {
    final vocab = vocabularyLimit(language: language, duration: duration, level: level);
    final grammar =
        grammarLimit(language: language, duration: duration, level: level);
    final vQuiz = quizLimit(
      duration: duration,
      level: level,
      quizCategory: 'Vocabulary Quiz',
    );
    final gQuiz = quizLimit(
      duration: duration,
      level: level,
      quizCategory: 'Grammar Quiz',
    );
    final sQuiz = quizLimit(
      duration: duration,
      level: level,
      quizCategory: 'Sentence Quiz',
    );
    final tQuiz = quizLimit(
      duration: duration,
      level: level,
      quizCategory: 'Total Quiz',
    );
    if (vocab == null ||
        grammar == null ||
        vQuiz == null ||
        gQuiz == null ||
        sQuiz == null ||
        tQuiz == null) {
      return null;
    }

    int selected(HtmlSelectedCount sc) => switch (sc) {
          HtmlCountExact(:final value) => value,
          HtmlCountRange(:final min, :final max) =>
            // SelectedFullLearnLimits is defined for future wiring; for Manual we
            // choose the max of the allowed range as a deterministic placeholder.
            // (Do not wire this into behavior in Phase 1.)
            max,
        };

    final vocabSel = selected(vocab.selectedFor(mode, preset));
    final grammarSel = selected(grammar.selectedFor(mode, preset));
    final vQuizSel = selected(vQuiz.selectedFor(mode, preset));
    final gQuizSel = selected(gQuiz.selectedFor(mode, preset));
    final sQuizSel = selected(sQuiz.selectedFor(mode, preset));
    final tQuizSel = selected(tQuiz.selectedFor(mode, preset));

    return HtmlFullLearnSelectedLimits(
      vocabularyCount: vocabSel,
      grammarCount: grammarSel,
      vocabularyQuizCount: vQuizSel,
      grammarQuizCount: gQuizSel,
      sentenceQuizCount: sQuizSel,
      totalQuizCount: tQuizSel,
    );
  }

  // ---------------------------------------------------------------------------
  // Embedded source-of-truth tables (verbatim values from HTML)
  // ---------------------------------------------------------------------------

  static const Map<HtmlPromptMode, Map<HtmlLearningLanguage, Map<String,
          Map<String, HtmlSentenceLimit>>>> _sentenceLimits =
      {
    HtmlPromptMode.manual: {
      HtmlLearningLanguage.jp: {
        '3-5 mins': {
          'N5/A1': HtmlSentenceLimit(
              minSentences: 18, maxSentences: 30, minChars: 250, maxChars: 450),
          'N4/A2': HtmlSentenceLimit(
              minSentences: 20, maxSentences: 34, minChars: 350, maxChars: 600),
          'N3/B1': HtmlSentenceLimit(
              minSentences: 22, maxSentences: 36, minChars: 500, maxChars: 800),
          'N2/B2': HtmlSentenceLimit(
              minSentences: 20, maxSentences: 34, minChars: 650, maxChars: 1050),
          'N1/C1': HtmlSentenceLimit(
              minSentences: 18, maxSentences: 32, minChars: 800, maxChars: 1300),
        },
        '5-7 mins': {
          'N5/A1': HtmlSentenceLimit(
              minSentences: 28, maxSentences: 45, minChars: 400, maxChars: 650),
          'N4/A2': HtmlSentenceLimit(
              minSentences: 32, maxSentences: 50, minChars: 550, maxChars: 900),
          'N3/B1': HtmlSentenceLimit(
              minSentences: 34, maxSentences: 55, minChars: 750, maxChars: 1150),
          'N2/B2': HtmlSentenceLimit(
              minSentences: 32, maxSentences: 52, minChars: 1000, maxChars: 1550),
          'N1/C1': HtmlSentenceLimit(
              minSentences: 30, maxSentences: 50, minChars: 1250, maxChars: 1900),
        },
        '7-9 mins': {
          'N5/A1': HtmlSentenceLimit(
              minSentences: 40, maxSentences: 60, minChars: 600, maxChars: 900),
          'N4/A2': HtmlSentenceLimit(
              minSentences: 45, maxSentences: 65, minChars: 800, maxChars: 1200),
          'N3/B1': HtmlSentenceLimit(
              minSentences: 48, maxSentences: 70, minChars: 1050, maxChars: 1550),
          'N2/B2': HtmlSentenceLimit(
              minSentences: 45, maxSentences: 68, minChars: 1350, maxChars: 2050),
          'N1/C1': HtmlSentenceLimit(
              minSentences: 42, maxSentences: 65, minChars: 1650, maxChars: 2500),
        },
      },
      HtmlLearningLanguage.en: {
        '3-5 mins': {
          'N5/A1': HtmlSentenceLimit(
              minSentences: 18, maxSentences: 30, minChars: 900, maxChars: 1600),
          'N4/A2': HtmlSentenceLimit(
              minSentences: 20, maxSentences: 34, minChars: 1200, maxChars: 2200),
          'N3/B1': HtmlSentenceLimit(
              minSentences: 22, maxSentences: 36, minChars: 1600, maxChars: 2800),
          'N2/B2': HtmlSentenceLimit(
              minSentences: 20, maxSentences: 34, minChars: 2000, maxChars: 3400),
          'N1/C1': HtmlSentenceLimit(
              minSentences: 18, maxSentences: 32, minChars: 2400, maxChars: 4200),
        },
        '5-7 mins': {
          'N5/A1': HtmlSentenceLimit(
              minSentences: 28, maxSentences: 45, minChars: 1400, maxChars: 2400),
          'N4/A2': HtmlSentenceLimit(
              minSentences: 32, maxSentences: 50, minChars: 1900, maxChars: 3300),
          'N3/B1': HtmlSentenceLimit(
              minSentences: 34, maxSentences: 55, minChars: 2500, maxChars: 4200),
          'N2/B2': HtmlSentenceLimit(
              minSentences: 32, maxSentences: 52, minChars: 3300, maxChars: 5400),
          'N1/C1': HtmlSentenceLimit(
              minSentences: 30, maxSentences: 50, minChars: 4200, maxChars: 6800),
        },
        '7-9 mins': {
          'N5/A1': HtmlSentenceLimit(
              minSentences: 40, maxSentences: 60, minChars: 2200, maxChars: 3500),
          'N4/A2': HtmlSentenceLimit(
              minSentences: 45, maxSentences: 65, minChars: 3000, maxChars: 4800),
          'N3/B1': HtmlSentenceLimit(
              minSentences: 48, maxSentences: 70, minChars: 4000, maxChars: 6200),
          'N2/B2': HtmlSentenceLimit(
              minSentences: 45, maxSentences: 68, minChars: 5200, maxChars: 7800),
          'N1/C1': HtmlSentenceLimit(
              minSentences: 42, maxSentences: 65, minChars: 6500, maxChars: 9500),
        },
      },
    },
    HtmlPromptMode.ai: {
      HtmlLearningLanguage.jp: {
        '3-5 mins': {
          'N5/A1': HtmlSentenceLimit(
              minSentences: 24, maxSentences: 38, minChars: 350, maxChars: 550),
          'N4/A2': HtmlSentenceLimit(
              minSentences: 28, maxSentences: 42, minChars: 500, maxChars: 750),
          'N3/B1': HtmlSentenceLimit(
              minSentences: 30, maxSentences: 45, minChars: 650, maxChars: 950),
          'N2/B2': HtmlSentenceLimit(
              minSentences: 28, maxSentences: 42, minChars: 850, maxChars: 1250),
          'N1/C1': HtmlSentenceLimit(
              minSentences: 26, maxSentences: 40, minChars: 1050, maxChars: 1550),
        },
        '5-7 mins': {
          'N5/A1': HtmlSentenceLimit(
              minSentences: 38, maxSentences: 55, minChars: 550, maxChars: 800),
          'N4/A2': HtmlSentenceLimit(
              minSentences: 42, maxSentences: 60, minChars: 750, maxChars: 1100),
          'N3/B1': HtmlSentenceLimit(
              minSentences: 45, maxSentences: 65, minChars: 950, maxChars: 1400),
          'N2/B2': HtmlSentenceLimit(
              minSentences: 42, maxSentences: 62, minChars: 1250, maxChars: 1800),
          'N1/C1': HtmlSentenceLimit(
              minSentences: 40, maxSentences: 60, minChars: 1550, maxChars: 2250),
        },
        '7-9 mins': {
          'N5/A1': HtmlSentenceLimit(
              minSentences: 55, maxSentences: 75, minChars: 800, maxChars: 1100),
          'N4/A2': HtmlSentenceLimit(
              minSentences: 60, maxSentences: 82, minChars: 1050, maxChars: 1500),
          'N3/B1': HtmlSentenceLimit(
              minSentences: 62, maxSentences: 88, minChars: 1350, maxChars: 1900),
          'N2/B2': HtmlSentenceLimit(
              minSentences: 58, maxSentences: 84, minChars: 1700, maxChars: 2450),
          'N1/C1': HtmlSentenceLimit(
              minSentences: 55, maxSentences: 80, minChars: 2100, maxChars: 3000),
        },
      },
      HtmlLearningLanguage.en: {
        '3-5 mins': {
          'N5/A1': HtmlSentenceLimit(
              minSentences: 24, maxSentences: 38, minChars: 1200, maxChars: 2100),
          'N4/A2': HtmlSentenceLimit(
              minSentences: 28, maxSentences: 42, minChars: 1600, maxChars: 2800),
          'N3/B1': HtmlSentenceLimit(
              minSentences: 30, maxSentences: 45, minChars: 2200, maxChars: 3600),
          'N2/B2': HtmlSentenceLimit(
              minSentences: 28, maxSentences: 42, minChars: 2800, maxChars: 4400),
          'N1/C1': HtmlSentenceLimit(
              minSentences: 26, maxSentences: 40, minChars: 3400, maxChars: 5400),
        },
        '5-7 mins': {
          'N5/A1': HtmlSentenceLimit(
              minSentences: 38, maxSentences: 55, minChars: 2000, maxChars: 3200),
          'N4/A2': HtmlSentenceLimit(
              minSentences: 42, maxSentences: 60, minChars: 2600, maxChars: 4200),
          'N3/B1': HtmlSentenceLimit(
              minSentences: 45, maxSentences: 65, minChars: 3400, maxChars: 5200),
          'N2/B2': HtmlSentenceLimit(
              minSentences: 42, maxSentences: 62, minChars: 4400, maxChars: 6600),
          'N1/C1': HtmlSentenceLimit(
              minSentences: 40, maxSentences: 60, minChars: 5600, maxChars: 8200),
        },
        '7-9 mins': {
          'N5/A1': HtmlSentenceLimit(
              minSentences: 55, maxSentences: 75, minChars: 3000, maxChars: 4500),
          'N4/A2': HtmlSentenceLimit(
              minSentences: 60, maxSentences: 82, minChars: 4000, maxChars: 6000),
          'N3/B1': HtmlSentenceLimit(
              minSentences: 62, maxSentences: 88, minChars: 5200, maxChars: 7600),
          'N2/B2': HtmlSentenceLimit(
              minSentences: 58, maxSentences: 84, minChars: 6800, maxChars: 9500),
          'N1/C1': HtmlSentenceLimit(
              minSentences: 55, maxSentences: 80, minChars: 8500, maxChars: 12000),
        },
      },
    },
  };

  static const Map<HtmlLearningLanguage,
          Map<String, Map<String, Map<String, HtmlLearnModuleLimit>>>> _learnLimits =
      {
    HtmlLearningLanguage.jp: {
      '3-5 mins': {
        'N5/A1': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 6,
              manualMax: 12,
              minimum: 6,
              defaultValue: 8,
              optimal: 10,
              maximum: 12),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 2,
              manualMax: 5,
              minimum: 2,
              defaultValue: 3,
              optimal: 4,
              maximum: 5),
        },
        'N4/A2': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 8,
              manualMax: 16,
              minimum: 8,
              defaultValue: 11,
              optimal: 13,
              maximum: 16),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 3,
              manualMax: 7,
              minimum: 3,
              defaultValue: 4,
              optimal: 5,
              maximum: 7),
        },
        'N3/B1': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 10,
              manualMax: 22,
              minimum: 10,
              defaultValue: 14,
              optimal: 17,
              maximum: 22),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 4,
              manualMax: 10,
              minimum: 4,
              defaultValue: 6,
              optimal: 8,
              maximum: 10),
        },
        'N2/B2': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 12,
              manualMax: 28,
              minimum: 12,
              defaultValue: 18,
              optimal: 22,
              maximum: 28),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 5,
              manualMax: 13,
              minimum: 5,
              defaultValue: 8,
              optimal: 10,
              maximum: 13),
        },
        'N1/C1': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 15,
              manualMax: 36,
              minimum: 15,
              defaultValue: 22,
              optimal: 28,
              maximum: 36),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 6,
              manualMax: 16,
              minimum: 6,
              defaultValue: 10,
              optimal: 12,
              maximum: 16),
        },
      },
      '5-7 mins': {
        'N5/A1': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 9,
              manualMax: 18,
              minimum: 9,
              defaultValue: 12,
              optimal: 14,
              maximum: 18),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 3,
              manualMax: 7,
              minimum: 3,
              defaultValue: 4,
              optimal: 5,
              maximum: 7),
        },
        'N4/A2': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 12,
              manualMax: 24,
              minimum: 12,
              defaultValue: 16,
              optimal: 19,
              maximum: 24),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 4,
              manualMax: 10,
              minimum: 4,
              defaultValue: 6,
              optimal: 8,
              maximum: 10),
        },
        'N3/B1': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 16,
              manualMax: 32,
              minimum: 16,
              defaultValue: 22,
              optimal: 26,
              maximum: 32),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 5,
              manualMax: 14,
              minimum: 5,
              defaultValue: 8,
              optimal: 10,
              maximum: 14),
        },
        'N2/B2': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 20,
              manualMax: 42,
              minimum: 20,
              defaultValue: 28,
              optimal: 33,
              maximum: 42),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 7,
              manualMax: 18,
              minimum: 7,
              defaultValue: 11,
              optimal: 14,
              maximum: 18),
        },
        'N1/C1': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 26,
              manualMax: 55,
              minimum: 26,
              defaultValue: 36,
              optimal: 43,
              maximum: 55),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 9,
              manualMax: 22,
              minimum: 9,
              defaultValue: 14,
              optimal: 17,
              maximum: 22),
        },
      },
      '7-9 mins': {
        'N5/A1': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 12,
              manualMax: 24,
              minimum: 12,
              defaultValue: 16,
              optimal: 19,
              maximum: 24),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 4,
              manualMax: 9,
              minimum: 4,
              defaultValue: 6,
              optimal: 7,
              maximum: 9),
        },
        'N4/A2': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 16,
              manualMax: 32,
              minimum: 16,
              defaultValue: 22,
              optimal: 26,
              maximum: 32),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 5,
              manualMax: 13,
              minimum: 5,
              defaultValue: 8,
              optimal: 10,
              maximum: 13),
        },
        'N3/B1': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 22,
              manualMax: 42,
              minimum: 22,
              defaultValue: 29,
              optimal: 34,
              maximum: 42),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 7,
              manualMax: 18,
              minimum: 7,
              defaultValue: 11,
              optimal: 14,
              maximum: 18),
        },
        'N2/B2': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 28,
              manualMax: 55,
              minimum: 28,
              defaultValue: 37,
              optimal: 44,
              maximum: 55),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 9,
              manualMax: 24,
              minimum: 9,
              defaultValue: 14,
              optimal: 18,
              maximum: 24),
        },
        'N1/C1': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 36,
              manualMax: 70,
              minimum: 36,
              defaultValue: 48,
              optimal: 56,
              maximum: 70),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 12,
              manualMax: 30,
              minimum: 12,
              defaultValue: 18,
              optimal: 23,
              maximum: 30),
        },
      },
    },
    HtmlLearningLanguage.en: {
      '3-5 mins': {
        'N5/A1': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 6,
              manualMax: 13,
              minimum: 6,
              defaultValue: 8,
              optimal: 10,
              maximum: 13),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 2,
              manualMax: 5,
              minimum: 2,
              defaultValue: 3,
              optimal: 4,
              maximum: 5),
        },
        'N4/A2': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 8,
              manualMax: 17,
              minimum: 8,
              defaultValue: 11,
              optimal: 13,
              maximum: 17),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 3,
              manualMax: 7,
              minimum: 3,
              defaultValue: 4,
              optimal: 5,
              maximum: 7),
        },
        'N3/B1': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 11,
              manualMax: 24,
              minimum: 11,
              defaultValue: 16,
              optimal: 19,
              maximum: 24),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 4,
              manualMax: 10,
              minimum: 4,
              defaultValue: 6,
              optimal: 8,
              maximum: 10),
        },
        'N2/B2': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 15,
              manualMax: 32,
              minimum: 15,
              defaultValue: 21,
              optimal: 25,
              maximum: 32),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 5,
              manualMax: 13,
              minimum: 5,
              defaultValue: 8,
              optimal: 10,
              maximum: 13),
        },
        'N1/C1': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 20,
              manualMax: 42,
              minimum: 20,
              defaultValue: 28,
              optimal: 33,
              maximum: 42),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 6,
              manualMax: 16,
              minimum: 6,
              defaultValue: 10,
              optimal: 12,
              maximum: 16),
        },
      },
      '5-7 mins': {
        'N5/A1': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 10,
              manualMax: 20,
              minimum: 10,
              defaultValue: 14,
              optimal: 16,
              maximum: 20),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 3,
              manualMax: 7,
              minimum: 3,
              defaultValue: 4,
              optimal: 5,
              maximum: 7),
        },
        'N4/A2': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 13,
              manualMax: 26,
              minimum: 13,
              defaultValue: 18,
              optimal: 21,
              maximum: 26),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 4,
              manualMax: 10,
              minimum: 4,
              defaultValue: 6,
              optimal: 8,
              maximum: 10),
        },
        'N3/B1': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 18,
              manualMax: 36,
              minimum: 18,
              defaultValue: 24,
              optimal: 29,
              maximum: 36),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 5,
              manualMax: 14,
              minimum: 5,
              defaultValue: 8,
              optimal: 10,
              maximum: 14),
        },
        'N2/B2': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 24,
              manualMax: 48,
              minimum: 24,
              defaultValue: 32,
              optimal: 38,
              maximum: 48),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 7,
              manualMax: 18,
              minimum: 7,
              defaultValue: 11,
              optimal: 14,
              maximum: 18),
        },
        'N1/C1': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 32,
              manualMax: 64,
              minimum: 32,
              defaultValue: 43,
              optimal: 51,
              maximum: 64),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 9,
              manualMax: 22,
              minimum: 9,
              defaultValue: 14,
              optimal: 17,
              maximum: 22),
        },
      },
      '7-9 mins': {
        'N5/A1': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 14,
              manualMax: 28,
              minimum: 14,
              defaultValue: 19,
              optimal: 22,
              maximum: 28),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 4,
              manualMax: 9,
              minimum: 4,
              defaultValue: 6,
              optimal: 7,
              maximum: 9),
        },
        'N4/A2': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 18,
              manualMax: 36,
              minimum: 18,
              defaultValue: 24,
              optimal: 29,
              maximum: 36),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 5,
              manualMax: 13,
              minimum: 5,
              defaultValue: 8,
              optimal: 10,
              maximum: 13),
        },
        'N3/B1': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 25,
              manualMax: 50,
              minimum: 25,
              defaultValue: 34,
              optimal: 40,
              maximum: 50),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 7,
              manualMax: 18,
              minimum: 7,
              defaultValue: 11,
              optimal: 14,
              maximum: 18),
        },
        'N2/B2': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 34,
              manualMax: 66,
              minimum: 34,
              defaultValue: 45,
              optimal: 53,
              maximum: 66),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 9,
              manualMax: 24,
              minimum: 9,
              defaultValue: 14,
              optimal: 18,
              maximum: 24),
        },
        'N1/C1': {
          'Vocabulary': HtmlLearnModuleLimit(
              manualMin: 45,
              manualMax: 85,
              minimum: 45,
              defaultValue: 59,
              optimal: 69,
              maximum: 85),
          'Grammar': HtmlLearnModuleLimit(
              manualMin: 12,
              manualMax: 30,
              minimum: 12,
              defaultValue: 18,
              optimal: 23,
              maximum: 30),
        },
      },
    },
  };

  static const Map<String, Map<String, Map<String, HtmlQuizCategoryLimit>>>
      _quizLimits = {
    '3-5 mins': {
      'N5/A1': {
        'Vocabulary Quiz': HtmlQuizCategoryLimit(
            manualMin: 3,
            manualMax: 6,
            minimum: 4,
            defaultValue: 5,
            optimal: 6,
            maximum: 8),
        'Grammar Quiz': HtmlQuizCategoryLimit(
            manualMin: 1,
            manualMax: 3,
            minimum: 2,
            defaultValue: 3,
            optimal: 3,
            maximum: 4),
        'Sentence Quiz': HtmlQuizCategoryLimit(
            manualMin: 1,
            manualMax: 3,
            minimum: 2,
            defaultValue: 3,
            optimal: 3,
            maximum: 4),
        'Total Quiz': HtmlQuizCategoryLimit(
            manualMin: 5,
            manualMax: 12,
            minimum: 8,
            defaultValue: 11,
            optimal: 13,
            maximum: 16),
      },
      'N4/A2': {
        'Vocabulary Quiz': HtmlQuizCategoryLimit(
            manualMin: 4,
            manualMax: 8,
            minimum: 5,
            defaultValue: 7,
            optimal: 8,
            maximum: 10),
        'Grammar Quiz': HtmlQuizCategoryLimit(
            manualMin: 2,
            manualMax: 4,
            minimum: 2,
            defaultValue: 3,
            optimal: 4,
            maximum: 5),
        'Sentence Quiz': HtmlQuizCategoryLimit(
            manualMin: 2,
            manualMax: 4,
            minimum: 2,
            defaultValue: 3,
            optimal: 4,
            maximum: 5),
        'Total Quiz': HtmlQuizCategoryLimit(
            manualMin: 8,
            manualMax: 16,
            minimum: 9,
            defaultValue: 13,
            optimal: 16,
            maximum: 20),
      },
      'N3/B1': {
        'Vocabulary Quiz': HtmlQuizCategoryLimit(
            manualMin: 5,
            manualMax: 10,
            minimum: 6,
            defaultValue: 8,
            optimal: 10,
            maximum: 13),
        'Grammar Quiz': HtmlQuizCategoryLimit(
            manualMin: 2,
            manualMax: 5,
            minimum: 3,
            defaultValue: 4,
            optimal: 5,
            maximum: 6),
        'Sentence Quiz': HtmlQuizCategoryLimit(
            manualMin: 2,
            manualMax: 5,
            minimum: 3,
            defaultValue: 4,
            optimal: 5,
            maximum: 6),
        'Total Quiz': HtmlQuizCategoryLimit(
            manualMin: 9,
            manualMax: 20,
            minimum: 12,
            defaultValue: 17,
            optimal: 20,
            maximum: 25),
      },
      'N2/B2': {
        'Vocabulary Quiz': HtmlQuizCategoryLimit(
            manualMin: 6,
            manualMax: 12,
            minimum: 8,
            defaultValue: 11,
            optimal: 13,
            maximum: 16),
        'Grammar Quiz': HtmlQuizCategoryLimit(
            manualMin: 3,
            manualMax: 6,
            minimum: 4,
            defaultValue: 5,
            optimal: 6,
            maximum: 8),
        'Sentence Quiz': HtmlQuizCategoryLimit(
            manualMin: 3,
            manualMax: 6,
            minimum: 3,
            defaultValue: 4,
            optimal: 5,
            maximum: 7),
        'Total Quiz': HtmlQuizCategoryLimit(
            manualMin: 12,
            manualMax: 24,
            minimum: 15,
            defaultValue: 21,
            optimal: 25,
            maximum: 31),
      },
      'N1/C1': {
        'Vocabulary Quiz': HtmlQuizCategoryLimit(
            manualMin: 7,
            manualMax: 14,
            minimum: 10,
            defaultValue: 14,
            optimal: 16,
            maximum: 20),
        'Grammar Quiz': HtmlQuizCategoryLimit(
            manualMin: 3,
            manualMax: 7,
            minimum: 5,
            defaultValue: 7,
            optimal: 8,
            maximum: 10),
        'Sentence Quiz': HtmlQuizCategoryLimit(
            manualMin: 3,
            manualMax: 7,
            minimum: 4,
            defaultValue: 5,
            optimal: 6,
            maximum: 8),
        'Total Quiz': HtmlQuizCategoryLimit(
            manualMin: 13,
            manualMax: 28,
            minimum: 19,
            defaultValue: 26,
            optimal: 30,
            maximum: 38),
      },
    },
    '5-7 mins': {
      'N5/A1': {
        'Vocabulary Quiz': HtmlQuizCategoryLimit(
            manualMin: 5,
            manualMax: 9,
            minimum: 6,
            defaultValue: 8,
            optimal: 10,
            maximum: 12),
        'Grammar Quiz': HtmlQuizCategoryLimit(
            manualMin: 2,
            manualMax: 4,
            minimum: 3,
            defaultValue: 4,
            optimal: 5,
            maximum: 6),
        'Sentence Quiz': HtmlQuizCategoryLimit(
            manualMin: 2,
            manualMax: 4,
            minimum: 3,
            defaultValue: 4,
            optimal: 5,
            maximum: 6),
        'Total Quiz': HtmlQuizCategoryLimit(
            manualMin: 9,
            manualMax: 17,
            minimum: 12,
            defaultValue: 16,
            optimal: 19,
            maximum: 24),
      },
      'N4/A2': {
        'Vocabulary Quiz': HtmlQuizCategoryLimit(
            manualMin: 6,
            manualMax: 12,
            minimum: 8,
            defaultValue: 11,
            optimal: 13,
            maximum: 16),
        'Grammar Quiz': HtmlQuizCategoryLimit(
            manualMin: 2,
            manualMax: 5,
            minimum: 4,
            defaultValue: 5,
            optimal: 6,
            maximum: 8),
        'Sentence Quiz': HtmlQuizCategoryLimit(
            manualMin: 3,
            manualMax: 5,
            minimum: 3,
            defaultValue: 4,
            optimal: 5,
            maximum: 7),
        'Total Quiz': HtmlQuizCategoryLimit(
            manualMin: 11,
            manualMax: 22,
            minimum: 15,
            defaultValue: 21,
            optimal: 25,
            maximum: 31),
      },
      'N3/B1': {
        'Vocabulary Quiz': HtmlQuizCategoryLimit(
            manualMin: 8,
            manualMax: 16,
            minimum: 10,
            defaultValue: 14,
            optimal: 16,
            maximum: 20),
        'Grammar Quiz': HtmlQuizCategoryLimit(
            manualMin: 3,
            manualMax: 7,
            minimum: 5,
            defaultValue: 7,
            optimal: 8,
            maximum: 10),
        'Sentence Quiz': HtmlQuizCategoryLimit(
            manualMin: 3,
            manualMax: 7,
            minimum: 4,
            defaultValue: 5,
            optimal: 6,
            maximum: 8),
        'Total Quiz': HtmlQuizCategoryLimit(
            manualMin: 14,
            manualMax: 30,
            minimum: 19,
            defaultValue: 26,
            optimal: 30,
            maximum: 38),
      },
      'N2/B2': {
        'Vocabulary Quiz': HtmlQuizCategoryLimit(
            manualMin: 10,
            manualMax: 20,
            minimum: 13,
            defaultValue: 18,
            optimal: 21,
            maximum: 26),
        'Grammar Quiz': HtmlQuizCategoryLimit(
            manualMin: 4,
            manualMax: 9,
            minimum: 6,
            defaultValue: 8,
            optimal: 10,
            maximum: 13),
        'Sentence Quiz': HtmlQuizCategoryLimit(
            manualMin: 4,
            manualMax: 8,
            minimum: 5,
            defaultValue: 7,
            optimal: 8,
            maximum: 10),
        'Total Quiz': HtmlQuizCategoryLimit(
            manualMin: 18,
            manualMax: 37,
            minimum: 24,
            defaultValue: 33,
            optimal: 39,
            maximum: 49),
      },
      'N1/C1': {
        'Vocabulary Quiz': HtmlQuizCategoryLimit(
            manualMin: 12,
            manualMax: 24,
            minimum: 16,
            defaultValue: 22,
            optimal: 26,
            maximum: 32),
        'Grammar Quiz': HtmlQuizCategoryLimit(
            manualMin: 5,
            manualMax: 11,
            minimum: 8,
            defaultValue: 11,
            optimal: 13,
            maximum: 16),
        'Sentence Quiz': HtmlQuizCategoryLimit(
            manualMin: 5,
            manualMax: 10,
            minimum: 6,
            defaultValue: 8,
            optimal: 10,
            maximum: 12),
        'Total Quiz': HtmlQuizCategoryLimit(
            manualMin: 22,
            manualMax: 45,
            minimum: 30,
            defaultValue: 41,
            optimal: 48,
            maximum: 60),
      },
    },
    '7-9 mins': {
      'N5/A1': {
        'Vocabulary Quiz': HtmlQuizCategoryLimit(
            manualMin: 6,
            manualMax: 12,
            minimum: 8,
            defaultValue: 11,
            optimal: 13,
            maximum: 16),
        'Grammar Quiz': HtmlQuizCategoryLimit(
            manualMin: 2,
            manualMax: 5,
            minimum: 4,
            defaultValue: 5,
            optimal: 6,
            maximum: 8),
        'Sentence Quiz': HtmlQuizCategoryLimit(
            manualMin: 3,
            manualMax: 5,
            minimum: 4,
            defaultValue: 5,
            optimal: 6,
            maximum: 8),
        'Total Quiz': HtmlQuizCategoryLimit(
            manualMin: 11,
            manualMax: 22,
            minimum: 16,
            defaultValue: 22,
            optimal: 26,
            maximum: 32),
      },
      'N4/A2': {
        'Vocabulary Quiz': HtmlQuizCategoryLimit(
            manualMin: 8,
            manualMax: 16,
            minimum: 10,
            defaultValue: 14,
            optimal: 16,
            maximum: 20),
        'Grammar Quiz': HtmlQuizCategoryLimit(
            manualMin: 3,
            manualMax: 6,
            minimum: 5,
            defaultValue: 7,
            optimal: 8,
            maximum: 10),
        'Sentence Quiz': HtmlQuizCategoryLimit(
            manualMin: 3,
            manualMax: 7,
            minimum: 5,
            defaultValue: 7,
            optimal: 8,
            maximum: 10),
        'Total Quiz': HtmlQuizCategoryLimit(
            manualMin: 14,
            manualMax: 29,
            minimum: 20,
            defaultValue: 27,
            optimal: 32,
            maximum: 40),
      },
      'N3/B1': {
        'Vocabulary Quiz': HtmlQuizCategoryLimit(
            manualMin: 10,
            manualMax: 20,
            minimum: 13,
            defaultValue: 18,
            optimal: 21,
            maximum: 26),
        'Grammar Quiz': HtmlQuizCategoryLimit(
            manualMin: 4,
            manualMax: 9,
            minimum: 6,
            defaultValue: 8,
            optimal: 10,
            maximum: 13),
        'Sentence Quiz': HtmlQuizCategoryLimit(
            manualMin: 4,
            manualMax: 9,
            minimum: 6,
            defaultValue: 8,
            optimal: 10,
            maximum: 12),
        'Total Quiz': HtmlQuizCategoryLimit(
            manualMin: 18,
            manualMax: 38,
            minimum: 25,
            defaultValue: 34,
            optimal: 41,
            maximum: 51),
      },
      'N2/B2': {
        'Vocabulary Quiz': HtmlQuizCategoryLimit(
            manualMin: 13,
            manualMax: 26,
            minimum: 17,
            defaultValue: 23,
            optimal: 27,
            maximum: 34),
        'Grammar Quiz': HtmlQuizCategoryLimit(
            manualMin: 5,
            manualMax: 12,
            minimum: 8,
            defaultValue: 11,
            optimal: 13,
            maximum: 17),
        'Sentence Quiz': HtmlQuizCategoryLimit(
            manualMin: 5,
            manualMax: 11,
            minimum: 7,
            defaultValue: 9,
            optimal: 11,
            maximum: 14),
        'Total Quiz': HtmlQuizCategoryLimit(
            manualMin: 23,
            manualMax: 49,
            minimum: 32,
            defaultValue: 44,
            optimal: 52,
            maximum: 65),
      },
      'N1/C1': {
        'Vocabulary Quiz': HtmlQuizCategoryLimit(
            manualMin: 16,
            manualMax: 32,
            minimum: 22,
            defaultValue: 29,
            optimal: 34,
            maximum: 42),
        'Grammar Quiz': HtmlQuizCategoryLimit(
            manualMin: 6,
            manualMax: 15,
            minimum: 10,
            defaultValue: 14,
            optimal: 17,
            maximum: 21),
        'Sentence Quiz': HtmlQuizCategoryLimit(
            manualMin: 6,
            manualMax: 13,
            minimum: 8,
            defaultValue: 11,
            optimal: 13,
            maximum: 16),
        'Total Quiz': HtmlQuizCategoryLimit(
            manualMin: 28,
            manualMax: 60,
            minimum: 40,
            defaultValue: 54,
            optimal: 63,
            maximum: 79),
      },
    },
  };
}

