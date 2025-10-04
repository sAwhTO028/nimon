import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../../models/section_key.dart';
import '../../models/filter_state.dart';
import '../../models/story.dart';
import '../../data/story_repo.dart';
import '../../widgets/story_card.dart';
import 'widgets/filter_bottom_sheet.dart';

/// Page that shows all stories for a specific section with filtering capabilities
class SeeMorePage extends StatefulWidget {
  final SectionKey section;
  final StoryRepo? storyRepo;

  const SeeMorePage({
    super.key,
    required this.section,
    this.storyRepo,
  });

  @override
  State<SeeMorePage> createState() => _SeeMorePageState();
}

class _SeeMorePageState extends State<SeeMorePage> {
  late Future<List<Story>> _storiesFuture;
  FilterState _filterState = const FilterState();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  void _loadStories() {
    if (widget.storyRepo != null) {
      if (_filterState.hasActiveFilters) {
        _storiesFuture = widget.storyRepo!.getFilteredStories(widget.section, _filterState);
      } else {
        _storiesFuture = widget.storyRepo!.getStoriesBySection(widget.section);
      }
    } else {
      // Fallback to empty list if no repo provided
      _storiesFuture = Future.value(<Story>[]);
    }
  }

  void _applyFilter(FilterState newFilter) {
    setState(() {
      _filterState = newFilter;
      _isLoading = true;
    });
    
    _loadStories();
    
    setState(() {
      _isLoading = false;
    });
  }

  void _openFilter() {
    showModalBottomSheet<FilterState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheet(
        currentFilter: _filterState,
        onApply: _applyFilter,
      ),
    );
  }

  void _onStoryTap(Story story) {
    // Navigate to story details - implement based on your routing
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening "${story.title}"...'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        leading: const BackButton(),
        centerTitle: true,
        title: Text(
          widget.section.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _openFilter,
                tooltip: 'Filter stories',
              ),
              if (_filterState.hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_filterState.activeFilterCount}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<Story>>(
        future: _storiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load stories',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _loadStories();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          final stories = snapshot.data ?? [];
          
          if (stories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_books_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No stories found',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _filterState.hasActiveFilters
                        ? 'Try adjusting your filters'
                        : 'Check back later for new content',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_filterState.hasActiveFilters) ...[
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => _applyFilter(const FilterState()),
                      child: const Text('Clear Filters'),
                    ),
                  ],
                ],
              ),
            );
          }
          
          return ListView.separated(
            physics: Platform.isIOS 
                ? const BouncingScrollPhysics()
                : const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: stories.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final story = stories[index];
              return StoryCard(
                story: story,
                heroTag: 'story_${story.id}_${widget.section.identifier}',
                onTap: () => _onStoryTap(story),
              );
            },
          );
        },
      ),
    );
  }
}

