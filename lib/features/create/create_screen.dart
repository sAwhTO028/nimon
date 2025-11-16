import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../ui/create/widgets/one_short_paper_card.dart';
import '../../data/prompt_repository.dart';

// Import OneShortState and extension from add_mono_bottom_sheet
class OneShortState {
  final String? selectedLevel;
  final String? selectedCategory;
  final String? selectedPromptId;
  final String title;
  final String? customPromptTitle;
  final String? customPromptContext;
  final String? customPromptDuration;

  const OneShortState({
    this.selectedLevel,
    this.selectedCategory,
    this.selectedPromptId,
    this.title = '',
    this.customPromptTitle,
    this.customPromptContext,
    this.customPromptDuration,
  });

  OneShortState copyWith({
    String? selectedLevel,
    String? selectedCategory,
    String? selectedPromptId,
    String? title,
    String? customPromptTitle,
    String? customPromptContext,
    String? customPromptDuration,
  }) {
    return OneShortState(
      selectedLevel: selectedLevel ?? this.selectedLevel,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedPromptId: selectedPromptId ?? this.selectedPromptId,
      title: title ?? this.title,
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

enum CreateTab { oneShort, storySeries, promptEpisode }

class CreateScreen extends StatefulWidget {
  final String? initialTab;

  const CreateScreen({super.key, this.initialTab});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  late CreateTab _selectedTab;
  late OneShortState _oneShortState;
  final TextEditingController _titleController = TextEditingController();

  final List<String> _jlptLevels = ['N5', 'N4', 'N3', 'N2', 'N1'];
  final List<String> _categories = ['Love', 'Comedy', 'Horror', 'Cultural', 'Adventure', 'Fantasy', 'Drama', 'Business', 'Sci-Fi', 'Mystery'];
  
  // Repository-driven prompt matching
  List<Prompt> _matchingPrompts = const [];
  Prompt? _selectedPrompt;
  int _visibleLimit = 5;
  
  // Horizontal paged list state
  int _promptPage = 0;
  static const int _pageSize = 3; // 3 cards per page
  late final PageController _promptPageController;
  final TextEditingController _cpTitle = TextEditingController();
  final TextEditingController _cpContext = TextEditingController();
  String _cpDuration = '5–7 minutes';

  @override
  void initState() {
    super.initState();
    _oneShortState = const OneShortState();
    _promptPageController = PageController();
    
    // Set initial tab based on parameter
    switch (widget.initialTab) {
      case 'oneShort':
        _selectedTab = CreateTab.oneShort;
        break;
      case 'series':
        _selectedTab = CreateTab.storySeries;
        break;
      case 'promptEpisode':
        _selectedTab = CreateTab.promptEpisode;
        break;
      default:
        _selectedTab = CreateTab.oneShort;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _cpTitle.dispose();
    _cpContext.dispose();
    _promptPageController.dispose();
    super.dispose();
  }

  void _updateOneShortState(OneShortState newState) {
    setState(() {
      _oneShortState = newState;
    });
  }

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
    _selectedPrompt = null;
    final level = _toJlptLevel(_oneShortState.selectedLevel);
    final category = _oneShortState.selectedCategory;
    if (level != null && category != null) {
      final found = PromptRepository.find(
        level: level,
        category: category,
        limit: 15,
      );
      _matchingPrompts = found.isNotEmpty
          ? found
          : PromptRepository.fallbackFor(level, category, count: 15);
      // Update _selectedPrompt if promptId matches
      if (_oneShortState.selectedPromptId != null) {
        try {
          _selectedPrompt = _matchingPrompts.firstWhere(
            (p) => p.id == _oneShortState.selectedPromptId,
          );
        } catch (e) {
          _selectedPrompt = null;
        }
      }
    } else {
      _matchingPrompts = const [];
    }
    _promptPage = 0; // reset when filters change
    if (_promptPageController.hasClients) {
      _promptPageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }
    setState(() {});
  }
  
  

  void _setLevel(String level) {
    setState(() {
      _oneShortState = _oneShortState.copyWith(
      selectedLevel: level,
        selectedCategory: null,
        selectedPromptId: null,
      );
      _visibleLimit = 5;
      _selectedPrompt = null;
      _promptPage = 0;
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
      _selectedPrompt = null;
      _promptPage = 0;
    });
    _refreshPrompts();
  }

  void _setPrompt(Prompt prompt) {
    setState(() {
      _oneShortState = _oneShortState.copyWith(
        selectedPromptId: prompt.id,
        customPromptTitle: null,
        customPromptContext: null,
        customPromptDuration: null,
      );
      _selectedPrompt = prompt;
    });
  }

  void _setTitle(String title) {
    setState(() {
      _oneShortState = _oneShortState.copyWith(title: title);
    });
  }

  Future<void> _openCustomPromptSheet() async {
    _cpTitle.clear();
    _cpContext.clear();
    _cpDuration = '5–7 minutes';
    
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add Custom Prompt',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                // Duration FIRST - Accordion selector
                _DurationAccordionSelector(
                  selectedDuration: _cpDuration,
                  onDurationSelected: (duration) {
                    setState(() => _cpDuration = duration);
                  },
                ),
                const SizedBox(height: 16),
                // Title SECOND
                TextField(
                  controller: _cpTitle,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Title (3–60 chars)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // Description THIRD
                TextField(
                  controller: _cpContext,
                  maxLength: 300,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Description / Context (min 10 chars)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final t = _cpTitle.text.trim();
                          final c = _cpContext.text.trim();
                          
                          if (t.length < 3 || t.length > 60) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Title must be 3–60 characters.'),
                              ),
                            );
                            return;
                          }
                          
                          if (c.length < 10) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Description must be at least 10 characters.'),
                              ),
                            );
                            return;
                          }
                          
                          setState(() {
                            _oneShortState = _oneShortState.copyWith(
                              customPromptTitle: t,
                              customPromptContext: c,
                              customPromptDuration: _cpDuration,
                              selectedPromptId: null,
                            );
                          });
                          
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Custom prompt saved!')),
                          );
                        },
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleCreate() {
    if (_oneShortState.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Created One-Short!')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Create',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_selectedTab == CreateTab.oneShort)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
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
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSegmentedControl(),
          Expanded(
            child: IndexedStack(
              index: _selectedTab.index,
              children: [
                _buildOneShortContent(),
                _buildPlaceholder('Story-Series'),
                _buildPlaceholder('Prompt-Episode'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentedButton(
              'One-Short',
              CreateTab.oneShort,
              _selectedTab == CreateTab.oneShort,
            ),
          ),
          Expanded(
            child: _buildSegmentedButton(
              'Story-Series',
              CreateTab.storySeries,
              _selectedTab == CreateTab.storySeries,
            ),
          ),
          Expanded(
            child: _buildSegmentedButton(
              'Prompt-Episode',
              CreateTab.promptEpisode,
              _selectedTab == CreateTab.promptEpisode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedButton(String label, CreateTab tab, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.black87 : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildOneShortContent() {
    return SingleChildScrollView(
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
                  key: ValueKey('${_oneShortState.selectedLevel}_${_oneShortState.selectedCategory}_${_oneShortState.selectedPromptId}_${_oneShortState.title}'),
                  data: OneShortPaper(
                    jlpt: _oneShortState.selectedLevel ?? '',
                    title: _oneShortState.title,
                    theme: _activePromptTitle,
                    context: _activePromptContext,
                    category: _oneShortState.selectedCategory ?? '',
                    durationText: _activePromptDuration,
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
          const SizedBox(height: 32),
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
    // Compute readiness: both level and category must be selected
    final bool _isReadyForPrompts = 
        _oneShortState.selectedLevel != null && _oneShortState.selectedCategory != null;
    
    // Return nothing when not ready (no container, no spacing)
    if (!_isReadyForPrompts) {
      return const SizedBox.shrink();
    }
    
    // Render the full section when ready
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), // smaller bottom padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            'Select Prompt (DEBUG 3:46)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          // Fixed-height horizontal PageView (3 cards per page)
          _buildPromptContent(),
          const SizedBox(height: 8),
          // Page indicator dots
          _buildPromptPageIndicator(),
          const SizedBox(height: 12),
          // "+ Custom Prompt" button (always below the list)
          buildCustomPromptButton(onTap: _openCustomPromptSheet),
        ],
      ),
    );
  }

  // Helper function to chunk prompts into pages of 5
  List<List<Prompt>> _chunkBy5(List<Prompt> items) {
    final List<List<Prompt>> pages = [];
    for (var i = 0; i < items.length; i += 5) {
      pages.add(items.sublist(i, i + 5 > items.length ? items.length : i + 5));
    }
    return pages;
  }

  Widget _buildPromptContent() {
    // This method is only called when ready (checked in _buildPromptSelector)
    final level = _toJlptLevel(_oneShortState.selectedLevel);
    if (level == null) return const SizedBox.shrink();
    
    return _buildPromptList();
  }

  Widget _buildPromptList() {
    final level = _toJlptLevel(_oneShortState.selectedLevel);
    if (level == null) return const SizedBox.shrink();

    final total = _matchingPrompts.length;

    // Empty state
    if (total == 0) {
      return Center(
        child: _emptyStateWithCustomButton(),
      );
    }

    // Calculate fixed height for exactly 3 cards
    const double promptCardHeight = 116.0; // Fixed card height
    const double promptCardSpacing = 12.0; // Spacing between cards
    final double promptsAreaHeight =
        (promptCardHeight * 3) + (promptCardSpacing * 2);

    // Calculate page count (3 cards per page)
    final int pageCount = (total / _pageSize).ceil();

    // Ensure current page is valid
    if (_promptPage >= pageCount) {
      _promptPage = (pageCount > 0) ? pageCount - 1 : 0;
    }

    // Horizontal PageView with 3 cards per page
    return SizedBox(
      height: promptsAreaHeight,
      child: PageView.builder(
        controller: _promptPageController,
        itemCount: pageCount,
        onPageChanged: (index) {
          setState(() {
            _promptPage = index;
          });
        },
        itemBuilder: (context, pageIndex) {
          final start = pageIndex * _pageSize;
          final end = (start + _pageSize < total) ? start + _pageSize : total;
          final pageItems = _matchingPrompts.sublist(start, end);

          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < pageItems.length; i++) ...[
                _promptCard(pageItems[i],
                    _selectedPrompt?.id == pageItems[i].id),
                if (i < pageItems.length - 1)
                  const SizedBox(height: 12.0),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildPromptPageIndicator() {
    final total = _matchingPrompts.length;
    if (total == 0) return const SizedBox.shrink();

    final int pageCount = (total / _pageSize).ceil();
    if (pageCount <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final isActive = index == _promptPage;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            width: isActive ? 8 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }

  Widget _promptCard(Prompt p, bool selected) {
    return SizedBox(
      width: double.infinity,
      height: 116, // Fixed height for all prompt cards
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEEF5FF) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : const Color(0xFFE6E6E6),
                width: selected ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: InkWell(
              onTap: () => _setPrompt(p),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          p.title,
                          style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (p.context.isNotEmpty) ...[
                    const SizedBox(height: 6),
            Text(
                      p.context,
              style: TextStyle(
                fontSize: 13,
                        color: Colors.black54,
                height: 1.35,
              ),
                      maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
            Text(
                        p.duration,
              style: TextStyle(
                fontSize: 11,
                          color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                          p.category,
                          style: const TextStyle(
                            fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
            ),
          ),
        if (selected)
          Positioned(
            right: 10,
            top: 10,
            child: Icon(
              Icons.check_circle,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
      ],
    ),
    );
  }

  Widget _emptyStateWithCustomButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Text(
        'No prompts for the selected level & category. Try another combo or add a custom prompt.',
        style: Theme.of(context).textTheme.bodyMedium,
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

  Widget buildCustomPromptButton({required VoidCallback onTap, Key? key}) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1F000000)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              offset: Offset(0, 2),
              color: Color(0x11000000),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            const Icon(Icons.add, size: 20),
            const SizedBox(width: 8),
            Text(
              'Custom Prompt',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.construction,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '$title Coming Soon',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This feature is under development',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPromptTitle() {
    return _selectedPrompt?.title ?? '';
  }

  String _getContextText() {
    return _selectedPrompt?.context ?? '';
  }

  String _getDuration() {
    return _selectedPrompt?.duration ?? '';
  }

  String get _activePromptTitle => 
      _oneShortState.customPromptTitle?.trim().isNotEmpty == true
          ? _oneShortState.customPromptTitle!.trim()
          : _getPromptTitle();

  String get _activePromptContext => 
      _oneShortState.customPromptContext?.trim().isNotEmpty == true
          ? _oneShortState.customPromptContext!.trim()
          : _getContextText();

  String get _activePromptDuration => 
      _oneShortState.customPromptDuration?.trim().isNotEmpty == true
          ? _oneShortState.customPromptDuration!.trim()
          : _getDuration();

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

// Empty state card widget
class EmptyPromptCard extends StatelessWidget {
  const EmptyPromptCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'First select the level and categories',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.black54,
          ),
        ),
      ),
    );
  }
}

// Info card widget for no matches
class InfoPromptCard extends StatelessWidget {
  final String text;
  const InfoPromptCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.left,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

/// Duration enum for the accordion selector
enum CustomPromptDuration {
  threeToFive,
  fiveToSeven,
  sevenToNine,
}

String _durationLabel(CustomPromptDuration value) {
  switch (value) {
    case CustomPromptDuration.threeToFive:
      return '3–5 minutes';
    case CustomPromptDuration.fiveToSeven:
      return '5–7 minutes';
    case CustomPromptDuration.sevenToNine:
      return '7–9 minutes';
  }
}

CustomPromptDuration _durationFromString(String value) {
  switch (value) {
    case '3–5 minutes':
      return CustomPromptDuration.threeToFive;
    case '5–7 minutes':
      return CustomPromptDuration.fiveToSeven;
    case '7–9 minutes':
      return CustomPromptDuration.sevenToNine;
    default:
      return CustomPromptDuration.fiveToSeven;
  }
}

String _durationToString(CustomPromptDuration value) {
  return _durationLabel(value);
}

/// Accordion-style Duration selector widget
class _DurationAccordionSelector extends StatefulWidget {
  final String selectedDuration;
  final ValueChanged<String> onDurationSelected;

  const _DurationAccordionSelector({
    required this.selectedDuration,
    required this.onDurationSelected,
  });

  @override
  State<_DurationAccordionSelector> createState() =>
      _DurationAccordionSelectorState();
}

class _DurationAccordionSelectorState
    extends State<_DurationAccordionSelector> {
  bool _isExpanded = false;
  late CustomPromptDuration _selectedDuration;
  
  static const List<CustomPromptDuration> _durationOptions = [
    CustomPromptDuration.threeToFive,
    CustomPromptDuration.fiveToSeven,
    CustomPromptDuration.sevenToNine,
  ];

  @override
  void initState() {
    super.initState();
    _selectedDuration = _durationFromString(widget.selectedDuration);
  }

  @override
  void didUpdateWidget(_DurationAccordionSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDuration != widget.selectedDuration) {
      _selectedDuration = _durationFromString(widget.selectedDuration);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          'Duration',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 8),
        // Collapsed/Expanded container
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              // Tappable row showing selected value - ONLY this header is tappable
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _durationLabel(_selectedDuration),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 200),
                        turns: _isExpanded ? 0.5 : 0,
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Animated expansion of options list - NOT wrapped in tap handler
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  child: SegmentedButton<CustomPromptDuration>(
                    segments: _durationOptions
                        .map(
                          (value) => ButtonSegment<CustomPromptDuration>(
                            value: value,
                            label: Text(_durationLabel(value)),
                          ),
                        )
                        .toList(),
                    selected: {_selectedDuration},
                    onSelectionChanged: (newSelection) {
                      if (newSelection.isNotEmpty) {
                        final selectedValue = newSelection.first;
                        final durationString = _durationToString(selectedValue);
                        
                        setState(() {
                          _selectedDuration = selectedValue;
                          _isExpanded = false;
                        });
                        
                        // Update parent form value
                        widget.onDurationSelected(durationString);
                      }
                    },
                  ),
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
