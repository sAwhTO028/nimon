import 'package:flutter/material.dart';
import '../../../data/prompt_repository.dart';
import '../../widgets/one_short_prompt_card.dart';

class BuildPromptSection extends StatefulWidget {
  final JlptLevel? selectedLevel;
  final String? selectedCategory;
  final Prompt? selectedPrompt;
  final int currentStep;
  final ValueChanged<Prompt> onPromptSelected;

  const BuildPromptSection({
    super.key,
    required this.selectedLevel,
    required this.selectedCategory,
    required this.selectedPrompt,
    required this.currentStep,
    required this.onPromptSelected,
  });

  @override
  State<BuildPromptSection> createState() => _BuildPromptSectionState();
}

class _BuildPromptSectionState extends State<BuildPromptSection> {
  final ScrollController _horizontalController = ScrollController();
  List<Prompt> _loadedPrompts = [];
  int _loadedCount = 0;
  bool _isLoadingMore = false;
  final int _batchSize = 5;
  final int _maxPrompts = 15;

  @override
  void initState() {
    super.initState();
    _loadInitialPrompts();
    _horizontalController.addListener(_onHorizontalScroll);
  }

  @override
  void didUpdateWidget(BuildPromptSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if level or category changed
    if (oldWidget.selectedLevel != widget.selectedLevel ||
        oldWidget.selectedCategory != widget.selectedCategory) {
      _loadInitialPrompts();
    }
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  void _loadInitialPrompts() {
    if (widget.selectedLevel == null || widget.selectedCategory == null) {
      _loadedPrompts = [];
      _loadedCount = 0;
      return;
    }

    setState(() {
      _loadedPrompts = PromptRepository.find(
        level: widget.selectedLevel!,
        category: widget.selectedCategory!,
        limit: _batchSize,
        offset: 0,
      );
      _loadedCount = _loadedPrompts.length;
    });
  }

  void _onHorizontalScroll() {
    // Load next batch when near end of horizontal scroll
    // Only trigger if we have exactly 5 prompts loaded (full horizontal carousel)
    if (_horizontalController.hasClients &&
        _horizontalController.position.pixels >=
            _horizontalController.position.maxScrollExtent * 0.7 &&
        !_isLoadingMore &&
        _loadedCount < _maxPrompts &&
        _loadedCount == _batchSize &&
        _loadedPrompts.length == _batchSize) {
      _loadNextBatch();
    }
  }

  Future<void> _loadNextBatch() async {
    if (widget.selectedLevel == null || widget.selectedCategory == null) return;
    if (_isLoadingMore || _loadedCount >= _maxPrompts) return;

    setState(() {
      _isLoadingMore = true;
    });

    // Simulate loading delay for smooth animation
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    final nextBatch = PromptRepository.find(
      level: widget.selectedLevel!,
      category: widget.selectedCategory!,
      limit: _batchSize,
      offset: _loadedCount,
    );

    setState(() {
      _loadedPrompts.addAll(nextBatch);
      _loadedCount = _loadedPrompts.length;
      _isLoadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Text('Select Prompt', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _content(context),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    // Show prompt list only when both level and category are selected
    if (widget.selectedLevel == null || widget.selectedCategory == null) {
      if (widget.selectedLevel == null) {
        return _emptyCard(
          context,
          title: 'First select the level',
          subtitle: 'Choose JLPT level to continue.',
        );
      } else {
        return _emptyCard(
          context,
          title: 'Select a category to see prompts',
          subtitle: 'Choose a category after selecting your level.',
        );
      }
    }

    // Both selected but no prompts loaded yet
    if (_loadedPrompts.isEmpty && !_isLoadingMore) {
      return _emptyCard(
        context,
        title: 'No prompts for this combination yet. Please try another.',
        subtitle: '',
      );
    }

    // Hybrid UI: Horizontal carousel for first 5, vertical list for rest
    final horizontalPrompts = _loadedPrompts.take(5).toList();
    final verticalPrompts = _loadedPrompts.length > 5
        ? _loadedPrompts.sublist(5)
        : <Prompt>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Horizontal carousel for first 5 prompts
        if (horizontalPrompts.isNotEmpty) ...[
          SizedBox(
            height: 180,
            child: ListView.builder(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              itemCount: horizontalPrompts.length,
              itemBuilder: (context, index) {
                final p = horizontalPrompts[index];
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < horizontalPrompts.length - 1 ? 12 : 0,
                  ),
                  child: SizedBox(
                    width: 280,
                    child: OneShortPromptCard(
                      prompt: p,
                      selected: widget.selectedPrompt?.id == p.id,
                      onTap: () => widget.onPromptSelected(p),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Vertical list for prompts 6-15
        if (verticalPrompts.isNotEmpty) ...[
          ...verticalPrompts.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OneShortPromptCard(
                  prompt: p,
                  selected: widget.selectedPrompt?.id == p.id,
                  onTap: () => widget.onPromptSelected(p),
                ),
              )),
          // Loading indicator when loading more
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ] else if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),

        // Add Custom Prompt card (show if less than 5 prompts or after all prompts)
        if (_loadedPrompts.length < 5 || _loadedCount >= _maxPrompts)
          _buildAddCustomPromptCard(context),
      ],
    );
  }

  Widget _buildAddCustomPromptCard(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () => _showCustomPromptDialog(context),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: kElevationToShadow[1],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Add Custom Prompt',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomPromptDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contextController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Custom Prompt'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title (max 60 characters)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 60,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contextController,
                decoration: const InputDecoration(
                  labelText: 'Description/Context (max 300 characters)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                maxLength: 300,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              final description = contextController.text.trim();

              if (title.isEmpty || description.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in all fields')),
                );
                return;
              }

              if (widget.selectedLevel == null || widget.selectedCategory == null) {
                Navigator.pop(dialogContext);
                return;
              }

              // Create custom prompt
              final customPrompt = Prompt(
                id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
                title: title.toUpperCase(),
                context: description,
                category: widget.selectedCategory!,
                level: widget.selectedLevel!,
                duration: PromptRepository.durationStringFor(widget.selectedLevel!),
              );

              // Add to repository
              PromptRepository.addCustomPrompt(customPrompt);

              // Add to loaded prompts if under limit
              setState(() {
                if (_loadedCount < _maxPrompts) {
                  _loadedPrompts.add(customPrompt);
                  _loadedCount = _loadedPrompts.length;
                }
              });

              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Custom prompt added!')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(BuildContext context, {required String title, required String subtitle}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: kElevationToShadow[1],
        border: Border.all(color: theme.dividerColor.withOpacity(.12)),
      ),
      child: subtitle.isEmpty
          ? Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
              ),
            )
          : Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(subtitle, style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
