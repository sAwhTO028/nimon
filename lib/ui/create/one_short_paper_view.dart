import 'package:flutter/material.dart';
import '../../data/prompt_repository.dart';
import 'widgets/build_prompt_section.dart';
import 'widgets/build_step_indicator.dart';

class OneShortPaperView extends StatefulWidget {
  const OneShortPaperView({super.key});

  @override
  State<OneShortPaperView> createState() => _OneShortPaperViewState();
}

class _OneShortPaperViewState extends State<OneShortPaperView> {
  JlptLevel? _level;
  String? _category;
  Prompt? _prompt;
  final TextEditingController _titleCtl = TextEditingController();
  
  /// Count completed items (each = 1 step). Order does NOT matter.
  int _completedSteps() {
    int c = 0;
    if (_level != null) c++;
    if (_category != null) c++;
    if (_prompt != null) c++;
    if (_titleCtl.text.trim().isNotEmpty) c++;
    return c;
  }

  void _onTitleChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    // Clear any stale state
    _level = null;
    _category = null;
    _prompt = null;
    _titleCtl.text = '';
    _titleCtl.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _titleCtl.removeListener(_onTitleChanged);
    _titleCtl.dispose();
    super.dispose();
  }

  void _onLevelChanged(JlptLevel? v) {
    setState(() {
      _level = v;
      _category = null;
      _prompt = null;
    });
  }

  void _onCategoryChanged(String? v) {
    setState(() {
      _category = v;
      _prompt = null;
    });
  }

  void _onPromptSelected(Prompt p) {
    setState(() {
      _prompt = p;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuildStepIndicator(currentStep: _completedSteps()),
        const SizedBox(height: 24),
        _buildLevelSelector(),
        const SizedBox(height: 16),
        _buildCategorySelector(),
        const SizedBox(height: 16),
        BuildPromptSection(
          selectedLevel: _level,
          selectedCategory: _category,
          selectedPrompt: _prompt,
          currentStep: _completedSteps(),
          onPromptSelected: _onPromptSelected,
        ),
        const SizedBox(height: 16),
        _buildTitleInput(),
      ],
    );
  }


  Widget _buildLevelSelector() {
    final List<String> _jlptLevels = ['N5', 'N4', 'N3', 'N2', 'N1'];
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
          SizedBox(
            height: 56,
            child: DropdownButtonFormField<String>(
              value: _jlptLevelToString(_level),
              onChanged: (value) {
                if (value != null) {
                  _onLevelChanged(_stringToJlptLevel(value));
                } else {
                  _onLevelChanged(null);
                }
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                isDense: true,
              ),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              iconSize: 24,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.0,
              ),
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
    final List<String> _categories = [
      'Love',
      'Comedy',
      'Horror',
      'Cultural',
      'Adventure',
      'Fantasy',
      'Drama',
      'Business',
      'Sci-Fi',
      'Mystery'
    ];
    final isEnabled = _level != null;

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
                final isSelected = _category == category;
                return GestureDetector(
                  onTap: isEnabled
                      ? () => _onCategoryChanged(isSelected ? null : category)
                      : null,
                  child: Opacity(
                    opacity: isEnabled ? 1.0 : 0.5,
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    final isEnabled = _prompt != null;
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
            controller: _titleCtl,
            enabled: isEnabled,
            // No onChanged needed - listener handles step recomputation
            maxLength: 60,
            decoration: InputDecoration(
              hintText: 'Demo Title Name',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              helperText: 'Enter your One-Short title (max 60 characters).',
              counterText: '',
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
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  JlptLevel? _stringToJlptLevel(String s) {
    switch (s) {
      case 'N5':
        return JlptLevel.n5;
      case 'N4':
        return JlptLevel.n4;
      case 'N3':
        return JlptLevel.n3;
      case 'N2':
        return JlptLevel.n2;
      case 'N1':
        return JlptLevel.n1;
    }
    return null;
  }

  String? _jlptLevelToString(JlptLevel? level) {
    switch (level) {
      case JlptLevel.n5:
        return 'N5';
      case JlptLevel.n4:
        return 'N4';
      case JlptLevel.n3:
        return 'N3';
      case JlptLevel.n2:
        return 'N2';
      case JlptLevel.n1:
        return 'N1';
      case null:
        return null;
    }
  }
}
