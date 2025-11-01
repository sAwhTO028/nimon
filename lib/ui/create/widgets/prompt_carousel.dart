import 'package:flutter/material.dart';
import '../../../data/prompt_repository.dart';
import '../../widgets/one_short_prompt_card.dart';

class PromptCarousel extends StatefulWidget {
  final List<Prompt> prompts;
  final Prompt? selected;
  final ValueChanged<Prompt> onSelect;
  final VoidCallback onTapCustom;
  final int visibleLimit;
  final ValueChanged<int> onVisibleLimitChanged;

  const PromptCarousel({
    super.key,
    required this.prompts,
    required this.selected,
    required this.onSelect,
    required this.onTapCustom,
    required this.visibleLimit,
    required this.onVisibleLimitChanged,
  });

  @override
  State<PromptCarousel> createState() => _PromptCarouselState();
}

class _PromptCarouselState extends State<PromptCarousel> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when scrolling near end (80% threshold)
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >
            _scrollController.position.maxScrollExtent * 0.8 &&
        widget.visibleLimit < 15) {
      widget.onVisibleLimitChanged(widget.visibleLimit + 5 < 15
          ? widget.visibleLimit + 5
          : 15);
    }

    // Update current page for dots indicator (excludes custom card)
    if (_scrollController.hasClients) {
      final cardWidth = 300.0 + 12.0; // card width + padding
      // Subtract custom card width to get prompt-only scroll position
      final promptScrollPos = (_scrollController.position.pixels - cardWidth).clamp(0, double.infinity);
      final newPage = (promptScrollPos / cardWidth).floor();
      if (newPage != _currentPage && newPage >= 0) {
        setState(() {
          _currentPage = newPage;
        });
      }
    }
  }

  Widget _buildCustomCard(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 300,
        child: InkWell(
          onTap: widget.onTapCustom,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: kElevationToShadow[1],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: theme.colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'Custom Prompt',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capped = widget.prompts.take(widget.visibleLimit).toList();
    
    // Page count excludes custom card (only count prompt cards, 5 per page)
    final pageCount = (capped.length / 5.0).ceil();

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 1 + capped.length, // 1 for custom card
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildCustomCard(context);
              }
              final prompt = capped[index - 1]; // Adjust for custom card
              return Padding(
                padding: EdgeInsets.only(
                  right: (index - 1) < capped.length - 1 ? 12 : 0,
                ),
                child: SizedBox(
                  width: 300,
                  child: OneShortPromptCard(
                    key: ValueKey('prompt_${prompt.id}'), // Stable key for rebuild optimization
                    prompt: prompt,
                    selected: widget.selected?.id == prompt.id,
                    onTap: () => widget.onSelect(prompt),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Dots indicator (excludes custom card, shows pages of 5 prompts each)
        if (pageCount > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pageCount, (index) {
              final isActive = index == _currentPage.clamp(0, pageCount - 1);
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
          ),
      ],
    );
  }
}

