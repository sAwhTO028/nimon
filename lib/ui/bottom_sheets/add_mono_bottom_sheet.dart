import 'package:flutter/material.dart';
import '../create/widgets/one_short_paper_card.dart';
import '../create/widgets/prompt_carousel.dart';
import '../create/widgets/duration_accordion_field.dart';
import '../../data/prompt_repository.dart';

// Legacy enum - kept for compatibility
enum CreationType { oneShort, storySeries, promptEpisode }

class OneShortState {
  final String? selectedLevel;
  final String? selectedCategory;
  final String? selectedPromptId;
  final String title;
  final int currentStep;
  final String? customPromptTitle;
  final String? customPromptContext;
  final String? customPromptDuration;

  const OneShortState({
    this.selectedLevel,
    this.selectedCategory,
    this.selectedPromptId,
    this.title = '',
    this.currentStep = 0,
    this.customPromptTitle,
    this.customPromptContext,
    this.customPromptDuration,
  });

  OneShortState copyWith({
    String? selectedLevel,
    String? selectedCategory,
    String? selectedPromptId,
    String? title,
    int? currentStep,
    String? customPromptTitle,
    String? customPromptContext,
    String? customPromptDuration,
  }) {
    return OneShortState(
      selectedLevel: selectedLevel ?? this.selectedLevel,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedPromptId: selectedPromptId ?? this.selectedPromptId,
      title: title ?? this.title,
      currentStep: currentStep ?? this.currentStep,
      customPromptTitle: customPromptTitle ?? this.customPromptTitle,
      customPromptContext: customPromptContext ?? this.customPromptContext,
      customPromptDuration: customPromptDuration ?? this.customPromptDuration,
    );
  }

  bool get hasRepoPrompt => selectedPromptId != null;
  
  bool get hasCustomPrompt => 
      (customPromptTitle?.isNotEmpty ?? false) && 
      (customPromptContext?.isNotEmpty ?? false);

  bool get isComplete => 
      selectedLevel != null && 
      selectedCategory != null && 
      (hasRepoPrompt || hasCustomPrompt) && 
      title.isNotEmpty &&
      title.length <= 60;
}

extension OneShortStateSteps on OneShortState {
  int get stepsCompleted {
    int s = 0;
    if ((selectedLevel ?? '').isNotEmpty) s++;
    if ((selectedCategory ?? '').isNotEmpty) s++;
    if (hasRepoPrompt || hasCustomPrompt) s++;
    if (title.trim().isNotEmpty) s++;
    return s;
  }
}


class _AddMonoSheet extends StatefulWidget {
  const _AddMonoSheet();

  @override
  State<_AddMonoSheet> createState() => _AddMonoSheetState();
}

class _AddMonoSheetState extends State<_AddMonoSheet> {
  OneShortState _oneShortState = const OneShortState();
  final TextEditingController _titleController = TextEditingController();

  final List<String> _jlptLevels = ['N5', 'N4', 'N3', 'N2', 'N1'];
  final List<String> _categories = ['Love', 'Comedy', 'Horror', 'Cultural', 'Adventure', 'Fantasy', 'Drama', 'Business', 'Sci-Fi', 'Mystery'];
  
  // Repository-driven prompt data
  List<Prompt> _matchingPrompts = const [];
  int _visibleLimit = 5;
  
  // Memoize prompt data to avoid unnecessary rebuilds
  List<Prompt>? _cachedPrompts;
  String? _cachedLevel;
  String? _cachedCategory;
  int? _cachedLimit;

  JlptLevel? _toJlptLevel(String? s) {
    switch (s) {
      case 'N5': return JlptLevel.n5;
      case 'N4': return JlptLevel.n4;
      case 'N3': return JlptLevel.n3;
      case 'N2': return JlptLevel.n2;
      case 'N1': return JlptLevel.n1;
    }
    return null;
  }

  void _refreshPrompts() {
    final level = _toJlptLevel(_oneShortState.selectedLevel);
    final category = _oneShortState.selectedCategory;
    
    // Memoization: only re-query if level, category, or limit changed
    if (level != null && category != null) {
      if (_cachedLevel != _oneShortState.selectedLevel ||
          _cachedCategory != category ||
          _cachedLimit != _visibleLimit) {
        _matchingPrompts = PromptRepository.find(
          level: level,
          category: category,
          limit: _visibleLimit,
        );
        _cachedLevel = _oneShortState.selectedLevel;
        _cachedCategory = category;
        _cachedLimit = _visibleLimit;
      }
    } else {
      _matchingPrompts = const [];
      _cachedLevel = null;
      _cachedCategory = null;
      _cachedLimit = null;
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _updateOneShortState(OneShortState newState) {
    setState(() {
      _oneShortState = newState;
    });
  }

  void _setLevel(String level) {
    setState(() {
      _oneShortState = _oneShortState.copyWith(
      selectedLevel: level,
        selectedCategory: null,
        selectedPromptId: null,
      );
      _visibleLimit = 5;
    });
    _refreshPrompts();
  }

  void _setCategory(String category) {
    // Toggle: if same category is selected, deselect it
    final newCategory = _oneShortState.selectedCategory == category ? null : category;
    setState(() {
      _oneShortState = _oneShortState.copyWith(
        selectedCategory: newCategory,
        selectedPromptId: null,
      );
      _visibleLimit = 5;
    });
    _refreshPrompts();
  }

  void _setPrompt(String promptId) {
    _updateOneShortState(_oneShortState.copyWith(
      selectedPromptId: promptId,
      customPromptTitle: null,
      customPromptContext: null,
      customPromptDuration: null,
      currentStep: 3,
    ));
  }

  void _setTitle(String title) {
    setState(() {
      _oneShortState = _oneShortState.copyWith(title: title);
    });
  }

  Future<void> _openCustomPromptSheet() async {
    final titleCtrl = TextEditingController();
    final contextCtrl = TextEditingController();
    
    const durationOptions = ['3–5 minutes', '5–7 minutes', '7–9 minutes'];
    
    // State holder that persists across rebuilds
    String? selectedDuration;
    
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: StatefulBuilder(
              builder: (ctx, setSheetState) {
                final bool canAdd = 
                    (selectedDuration != null) &&
                    titleCtrl.text.trim().length >= 3 &&
                    titleCtrl.text.trim().length <= 60 &&
                    contextCtrl.text.trim().length >= 10;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Add Custom Prompt',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    // 1) Duration (Accordion) — TOP
                    DurationAccordionField(
                      options: durationOptions,
                      initialValue: selectedDuration,
                      onChanged: (v) {
                        selectedDuration = v;
                        setSheetState(() {}); // Rebuild to update button state
                      },
                    ),
                    const SizedBox(height: 14),
                    // 2) Title
                    TextField(
                      controller: titleCtrl,
                      maxLength: 60,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setSheetState(() {}), // Rebuild to update button
                      decoration: const InputDecoration(
                        labelText: 'Title (3–60 chars)',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 3) Description
                    TextField(
                      controller: contextCtrl,
                      maxLength: 300,
                      minLines: 3,
                      maxLines: 6,
                      onChanged: (_) => setSheetState(() {}), // Rebuild to update button
                      decoration: const InputDecoration(
                        labelText: 'Description / Context (min 10 chars)',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: canAdd ? () {
                              // >>> UPDATE MAIN STATE - Custom prompt replaces previous selection
    _updateOneShortState(_oneShortState.copyWith(
                                selectedPromptId: null, // Clear repo prompt selection
                                customPromptTitle: titleCtrl.text.trim(),
                                customPromptContext: contextCtrl.text.trim(),
                                customPromptDuration: selectedDuration,
                                currentStep: 3,
                              ));
                              // Show success feedback
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Custom prompt added!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              Navigator.of(ctx).pop();
                            } : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: canAdd ? null : Colors.grey.shade300,
                              foregroundColor: canAdd ? null : Colors.grey.shade600,
                            ),
                            child: const Text('Add'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _handleCreate() {
    if (_oneShortState.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Created One-Short!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Preview carousel matching Home card dimensions
                SizedBox(
                  height: 220, // Home card height + outer padding
                  child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                    child: OneShortPaperCard(
                            key: ValueKey(
                              '${_oneShortState.selectedLevel}_'
                              '${_oneShortState.selectedCategory}_'
                              '${_oneShortState.selectedPromptId}_'
                              '${_oneShortState.title}_'
                              '${_oneShortState.customPromptTitle}_'
                              '${_oneShortState.customPromptContext}',
                            ),
                            data: OneShortPaper(
                              jlpt: _oneShortState.selectedLevel ?? '',
                              title: _oneShortState.title,
                              theme: _oneShortState.customPromptTitle?.trim().isNotEmpty == true
                                  ? _oneShortState.customPromptTitle!.trim()
                                  : (_oneShortState.selectedPromptId != null && _matchingPrompts.isNotEmpty
                                      ? (_matchingPrompts.firstWhere((p) => p.id == _oneShortState.selectedPromptId, orElse: () => _matchingPrompts.first).title)
                                      : ''),
                              context: _oneShortState.customPromptContext?.trim().isNotEmpty == true
                                  ? _oneShortState.customPromptContext!.trim()
                                  : (_oneShortState.selectedPromptId != null && _matchingPrompts.isNotEmpty
                                      ? (_matchingPrompts.firstWhere((p) => p.id == _oneShortState.selectedPromptId, orElse: () => _matchingPrompts.first).context)
                                      : ''),
                              category: _oneShortState.selectedCategory ?? '',
                              durationText: _oneShortState.customPromptDuration?.trim().isNotEmpty == true
                                  ? _oneShortState.customPromptDuration!.trim()
                                  : (_oneShortState.selectedPromptId != null && _matchingPrompts.isNotEmpty
                                      ? (_matchingPrompts.firstWhere((p) => p.id == _oneShortState.selectedPromptId, orElse: () => _matchingPrompts.first).duration)
                                      : ''),
                            ),
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 12), // Reduced spacing
                  _buildStepIndicator(),
                  const SizedBox(height: 24),
                  _buildLevelSelector(),
                  const SizedBox(height: 16),
                  _buildCategorySelector(),
                  const SizedBox(height: 16),
                  _buildPromptSelector(),
                  const SizedBox(height: 16),
                  _buildTitleInput(),
                ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Pill handle
          Container(
            width: 40,
            height: 4,
      decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                    Text(
                      _getTitle(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Please select you want to create section',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                    ),
                ),
              ],
            ),
          ),
              const SizedBox(width: 16),
              SizedBox(
                height: 40,
                child: FilledButton(
                  onPressed: _oneShortState.isComplete ? _handleCreate : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _oneShortState.isComplete 
                        ? Colors.blue 
                        : Colors.grey.shade300,
                    foregroundColor: _oneShortState.isComplete 
                        ? Colors.white 
                        : Colors.grey.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'CREATE',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
            ),
          ],
        ),
    );
  }

  Widget _buildStepIndicator() {
    final stepsCompleted = _oneShortState.stepsCompleted;
    
    // Hide if no steps completed
    if (stepsCompleted == 0) {
      return const SizedBox.shrink();
    }

    // Show dots based on stepsCompleted
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final stepNumber = index + 1;
        final isActive = stepNumber == stepsCompleted;
        final isCompleted = stepNumber < stepsCompleted;

        return Row(
      children: [
        Container(
              width: isActive ? 8 : 6,
              height: 6,
          decoration: BoxDecoration(
                color: isActive || isCompleted
                    ? Colors.blue
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            if (index < 3) ...[
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 1,
                color: isCompleted ? Colors.blue : Colors.grey.shade300,
              ),
              const SizedBox(width: 8),
            ],
          ],
        );
      }),
    );
  }

  Widget _buildLevelSelector() {
    return Container(
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
            'Select your level',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          // Material Design 3 compliant dropdown with perfect vertical centering
          SizedBox(
            height: 56,
            child: DropdownButtonFormField<String>(
              value: _oneShortState.selectedLevel,
              onChanged: (value) {
                if (value != null) _setLevel(value);
              },
              decoration: InputDecoration(
                hintText: 'Choose JLPT level',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                ),
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
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                // Material Design 3: 56dp height with perfect vertical centering
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                isDense: true,
                // Ensure consistent baseline alignment
                alignLabelWithHint: false,
              ),
              isExpanded: true,
              icon: const Icon(
                Icons.arrow_drop_down,
                color: Colors.grey,
              ),
              iconSize: 24,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.0, // Prevent extra line height
              ),
              // Material Design 3: 48dp menu item height
              itemHeight: 48,
              items: _jlptLevels.map((String level) {
                return DropdownMenuItem<String>(
                  value: level,
                  child: Container(
                    height: 48,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      level,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
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
            'Categories Select',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
        SizedBox(
          height: 40,
            child: ListView.separated(
            scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _oneShortState.selectedCategory == category;
                return GestureDetector(
                  onTap: () => _setCategory(category),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.shade300,
                      ),
                    ),
              child: Text(
                      category,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ),
                );
              },
            ),
          ),
        ],
        ),
      );
    }

  Widget _buildPromptSelector() {
    final hasSelections =
        _oneShortState.selectedLevel != null && _oneShortState.selectedCategory != null;

    if (!hasSelections) {
          return Container(
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
        child: Center(
          child: Text(
            'First select the level and categories',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
      ),
    );
  }

    final level = _toJlptLevel(_oneShortState.selectedLevel);
    if (level == null) return const SizedBox.shrink();

          return Container(
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
            'Select Prompt',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          PromptCarousel(
            prompts: _matchingPrompts,
            selected: _oneShortState.selectedPromptId != null && _matchingPrompts.isNotEmpty
                ? _matchingPrompts.firstWhere(
                    (p) => p.id == _oneShortState.selectedPromptId,
                    orElse: () => _matchingPrompts.first,
                  )
                : null,
            onSelect: (prompt) => _setPrompt(prompt.id),
            onTapCustom: _openCustomPromptSheet,
            visibleLimit: _visibleLimit,
            onVisibleLimitChanged: (newLimit) {
              setState(() {
                _visibleLimit = newLimit;
              });
              _refreshPrompts();
            },
            ),
          ],
        ),
    );
  }

  Widget _buildTitleInput() {
    return Container(
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
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            onChanged: _setTitle,
            maxLength: 60,
            decoration: InputDecoration(
              hintText: 'Demo Title Name',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              helperText: 'Enter your One-Short title (max 60 characters).',
              counterText: '', // Hide character counter
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

  String _getTitle() {
    return 'Add One-Short';
  }

  String _getPromptTitle() {
    switch (_oneShortState.selectedPromptId) {
      case 'rainy_day_promise':
        return 'Rainy day promise';
      case 'first_snow_train':
        return 'First snow, last train';
      default:
        return '';
    }
  }

  String _getContextText() {
    switch (_oneShortState.selectedPromptId) {
      case 'rainy_day_promise':
        return 'Two old friends meet again at a bus stop on a rainy afternoon in Tokyo.';
      case 'first_snow_train':
        return 'Two people miss the last train home and walk together through the first snow of the season.';
      default:
        return '';
    }
  }

  String _getDuration() {
    switch (_oneShortState.selectedPromptId) {
      case 'rainy_day_promise':
        return '4–6 minutes';
      case 'first_snow_train':
        return '6–8 minutes';
      default:
        return '';
    }
  }

  IconData _getCategoryIcon() {
    switch (_oneShortState.selectedCategory) {
      case 'Love':
        return Icons.favorite;
      case 'Comedy':
        return Icons.sentiment_very_satisfied;
      case 'Horror':
        return Icons.psychology;
      case 'Cultural':
        return Icons.museum;
      case 'Adventure':
        return Icons.explore;
      case 'Fantasy':
        return Icons.auto_awesome;
      case 'Drama':
        return Icons.theater_comedy;
      case 'Business':
        return Icons.business;
      case 'Sci-Fi':
        return Icons.rocket_launch;
      case 'Mystery':
        return Icons.search;
      default:
        return Icons.favorite;
    }
  }

  String _getAssetPathForCategory(String category) {
    const Map<String, String> assetMap = {
      'adventure': 'assets/images/one_short/Adventure.jpg',
      'business': 'assets/images/one_short/Business_Learning.jpg',
      'comedy': 'assets/images/one_short/comedy.jpg',
      'cultural': 'assets/images/one_short/cultural.jpg',
      'drama': 'assets/images/one_short/Drama.jpg',
      'fantasy': 'assets/images/one_short/Fantasy.jpg',
      'horror': 'assets/images/one_short/horror.jpg',
      'love': 'assets/images/one_short/love.jpg',
      'mystery_detective': 'assets/images/one_short/Mystery_Detective.jpg',
      'scifi_technology': 'assets/images/one_short/Sci-Fi_Technology.jpg',
    };
    return assetMap[category.toLowerCase()] ?? 'assets/images/one_short/love.jpg';
  }

}

// Old PaperSheetWidget removed - now using reusable component from lib/ui/widgets/paper_sheet_widget.dart

// Entry point function
void showAddMonoSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _AddMonoSheet(),
  );
}