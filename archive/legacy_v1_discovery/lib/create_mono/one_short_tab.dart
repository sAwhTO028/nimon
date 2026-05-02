import 'package:flutter/material.dart';
import 'widgets/preview_paper.dart';
import 'widgets/step_indicator.dart';
import 'widgets/level_dropdown.dart';
import 'widgets/category_chips.dart';
import 'package:nimon/features/mono/mono_content_model.dart';

class OneShortDraftLine {
  final String ja;
  final String en;
  final String my;

  const OneShortDraftLine({
    this.ja = '',
    this.en = '',
    this.my = '',
  });

  OneShortDraftLine copyWith({String? ja, String? en, String? my}) {
    return OneShortDraftLine(
      ja: ja ?? this.ja,
      en: en ?? this.en,
      my: my ?? this.my,
    );
  }

  bool get hasJapanese => ja.trim().isNotEmpty;
}

class OneShortState {
  final String jlpt;
  final String? category;
  final String? promptId;
  final String title;
  final int step;
  final List<OneShortDraftLine> lines;

  const OneShortState({
    this.jlpt = '',
    this.category,
    this.promptId,
    this.title = '',
    this.step = 1,
    this.lines = const [OneShortDraftLine()],
  });

  OneShortState copyWith({
    String? jlpt,
    String? category,
    String? promptId,
    String? title,
    int? step,
    List<OneShortDraftLine>? lines,
  }) {
    return OneShortState(
      jlpt: jlpt ?? this.jlpt,
      category: category ?? this.category,
      promptId: promptId ?? this.promptId,
      title: title ?? this.title,
      step: step ?? this.step,
      lines: lines ?? this.lines,
    );
  }

  bool get hasAtLeastOneLine => lines.any((l) => l.hasJapanese);

  bool get isComplete =>
      jlpt.isNotEmpty &&
      category != null &&
      promptId != null &&
      title.isNotEmpty &&
      hasAtLeastOneLine;

  /// Structured content output aligned with the new Mono model.
  /// Furigana tokens are intentionally empty in V1 create UI.
  MonoContent toMonoContent({required String id}) {
    final safeLines = lines.where((l) => l.hasJapanese).toList();
    final sentenceLines = safeLines.map((l) {
      final exp = (l.en.trim().isEmpty && l.my.trim().isEmpty)
          ? null
          : MonoExplanationLine(
              en: l.en.trim().isEmpty ? null : l.en.trim(),
              my: l.my.trim().isEmpty ? null : l.my.trim(),
            );
      return MonoSentenceLine(
        tokens: const [],
        plainText: l.ja.trim(),
        explanation: exp,
      );
    }).toList();
    return MonoContent(
      id: id,
      title: title.trim().isEmpty ? null : title.trim(),
      pages: [
        MonoContentPage(pageId: 'p1', lines: sentenceLines),
      ],
    );
  }

  /// Legacy plain text fallback for existing reader surfaces.
  String toLegacyBodyText() {
    final safeLines = lines.where((l) => l.hasJapanese).toList();
    return safeLines.map((l) => l.ja.trim()).join('\n');
  }
}

class OneShortTab extends StatefulWidget {
  final OneShortState state;
  final ValueChanged<OneShortState> onStateChanged;

  const OneShortTab({
    super.key,
    required this.state,
    required this.onStateChanged,
  });

  @override
  State<OneShortTab> createState() => _OneShortTabState();
}

class _OneShortTabState extends State<OneShortTab> {
  late OneShortState _state;
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _state = widget.state;
    _titleController.text = _state.title;
  }

  @override
  void didUpdateWidget(OneShortTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      _state = widget.state;
      _titleController.text = _state.title;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _updateState(OneShortState newState) {
    setState(() {
      _state = newState;
    });
    widget.onStateChanged(newState);
  }

  void _setJlpt(String jlpt) {
    final newState = _state.copyWith(jlpt: jlpt, step: 2);
    _updateState(newState);
  }

  void _setCategory(String category) {
    final newState = _state.copyWith(category: category, step: 3);
    _updateState(newState);
  }

  void _setPrompt(String promptId) {
    final newState = _state.copyWith(promptId: promptId, step: 4);
    _updateState(newState);
  }

  void _setTitle(String title) {
    final newState = _state.copyWith(title: title);
    _updateState(newState);
  }

  void _addLine() {
    final next = [..._state.lines, const OneShortDraftLine()];
    _updateState(_state.copyWith(lines: next));
  }

  void _removeLine(int index) {
    final next = [..._state.lines]..removeAt(index);
    if (next.isEmpty) next.add(const OneShortDraftLine());
    _updateState(_state.copyWith(lines: next));
  }

  void _updateLine(int index, OneShortDraftLine line) {
    final next = [..._state.lines];
    if (index < 0 || index >= next.length) return;
    next[index] = line;
    _updateState(_state.copyWith(lines: next));
  }

  List<Map<String, String>> _filteredPrompts() {
    // Sample prompts data - in a real app, this would come from a service
    final allPrompts = [
      {
        'id': 'rainy_day_promise',
        'title': 'Theme – RAINY DAY PROMISE',
        'context': 'Two old friends meet again at a bus stop on a rainy afternoon in Tokyo.',
        'duration': '4–6 minutes',
        'category': 'Love',
        'level': 'N3',
      },
      {
        'id': 'first_snow_train',
        'title': 'Theme – FIRST SNOW, LAST TRAIN',
        'context': 'Two people miss the last train home and walk together through the first snow of the season.',
        'duration': '6–8 minutes',
        'category': 'Love',
        'level': 'N2',
      },
      {
        'id': 'mystery_library',
        'title': 'Theme – MYSTERY IN THE LIBRARY',
        'context': 'A detective investigates a strange disappearance in an old university library.',
        'duration': '5–7 minutes',
        'category': 'Mystery',
        'level': 'N1',
      },
      {
        'id': 'horror_apartment',
        'title': 'Theme – THE APARTMENT',
        'context': 'A new tenant discovers the dark history of their new apartment building.',
        'duration': '6–8 minutes',
        'category': 'Horror',
        'level': 'N2',
      },
    ];

    if (_state.jlpt.isEmpty || _state.category == null) {
      return [];
    }

    return allPrompts.where((prompt) {
      return prompt['level'] == _state.jlpt && prompt['category'] == _state.category;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PreviewPaper(
          jlpt: _state.jlpt,
          category: _state.category,
          promptId: _state.promptId,
          title: _state.title,
        ),
        const SizedBox(height: 16),
        StepIndicator(currentStep: _state.step),
        const SizedBox(height: 16),
        LevelDropdown(
          selectedJlpt: _state.jlpt,
          onChanged: _setJlpt,
        ),
        const SizedBox(height: 16),
        CategoryChips(
          selectedCategory: _state.category,
          onCategorySelected: _setCategory,
        ),
        const SizedBox(height: 16),
        _buildPromptSection(),
        const SizedBox(height: 16),
        _buildTitleInput(),
        const SizedBox(height: 16),
        _buildLinesEditor(),
      ],
    );
  }

  Widget _buildLinesEditor() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Lines',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add line'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(_state.lines.length, (i) {
            final line = _state.lines[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(14),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: theme.dividerColor),
                  ),
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: theme.dividerColor),
                  ),
                  title: TextFormField(
                    key: ValueKey('ja_$i'),
                    initialValue: line.ja,
                    decoration: InputDecoration(
                      hintText: 'Japanese line ${i + 1}',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: theme.hintColor),
                    ),
                    minLines: 1,
                    maxLines: 3,
                    onChanged: (v) => _updateLine(i, line.copyWith(ja: v)),
                  ),
                  trailing: IconButton(
                    onPressed: () => _removeLine(i),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Remove line',
                  ),
                  children: [
                    TextFormField(
                      key: ValueKey('en_$i'),
                      initialValue: line.en,
                      decoration: const InputDecoration(
                        labelText: 'Explanation (EN) — optional',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 3,
                      onChanged: (v) => _updateLine(i, line.copyWith(en: v)),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      key: ValueKey('my_$i'),
                      initialValue: line.my,
                      decoration: const InputDecoration(
                        labelText: 'Explanation (MY) — optional',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 3,
                      onChanged: (v) => _updateLine(i, line.copyWith(my: v)),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (!_state.hasAtLeastOneLine)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Add at least one Japanese line to continue.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPromptSection() {
    final matches = _filteredPrompts();
    final hasSelections = _state.jlpt.isNotEmpty && _state.category != null;

    if (!hasSelections) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          height: 100,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Text(
            'Choose JLPT level and category to see prompts here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ),
      );
    }

    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Text(
            'No prompts for ${_state.jlpt} + ${_state.category!} yet. Please try another combination.',
            style: const TextStyle(fontSize: 14),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Prompt',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          // Scrollable prompt grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: matches.length,
            itemBuilder: (context, i) {
              final p = matches[i];
              final isSelected = _state.promptId == p['id'];
              return GestureDetector(
                onTap: () {
                  _setPrompt(p['id']!);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).dividerColor,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            p['level']!,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p['title']!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          p['context']!,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, height: 1.3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            p['duration']!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E6E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'One-Short Title',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            onChanged: _setTitle,
            decoration: InputDecoration(
              hintText: 'Demo Title Name',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
