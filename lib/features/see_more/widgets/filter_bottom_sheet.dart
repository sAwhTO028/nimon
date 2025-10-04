import 'package:flutter/material.dart';
import '../../../models/filter_state.dart';

/// Bottom sheet for filtering stories with level, category, and sort options
class FilterBottomSheet extends StatefulWidget {
  final FilterState currentFilter;
  final Function(FilterState) onApply;

  const FilterBottomSheet({
    super.key,
    required this.currentFilter,
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late FilterState _tempFilter;

  // Available filter options
  static const List<String> _levels = ['N5', 'N4', 'N3', 'N2', 'N1'];
  static const List<String> _categories = [
    'Love',
    'Comedy',
    'Horror',
    'Cultural',
    'Adventure',
    'Fantasy',
    'Drama',
    'Business',
    'Sci-Fi',
    'Mystery',
  ];

  @override
  void initState() {
    super.initState();
    _tempFilter = widget.currentFilter;
  }

  void _updateLevel(String? level) {
    setState(() {
      _tempFilter = _tempFilter.copyWith(selectedLevel: level);
    });
  }

  void _updateCategory(String? category) {
    setState(() {
      _tempFilter = _tempFilter.copyWith(selectedCategory: category);
    });
  }

  void _updateSortBy(SortBy sortBy) {
    setState(() {
      _tempFilter = _tempFilter.copyWith(sortBy: sortBy);
    });
  }

  void _clearFilters() {
    setState(() {
      _tempFilter = const FilterState();
    });
  }

  void _applyFilters() {
    widget.onApply(_tempFilter);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Filter Stories',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear All'),
                ),
              ],
            ),
          ),
          
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // JLPT Level Section
                  _buildSectionTitle('JLPT Level'),
                  const SizedBox(height: 12),
                  _buildLevelChips(),
                  
                  const SizedBox(height: 24),
                  
                  // Category Section
                  _buildSectionTitle('Category'),
                  const SizedBox(height: 12),
                  _buildCategoryChips(),
                  
                  const SizedBox(height: 24),
                  
                  // Sort By Section
                  _buildSectionTitle('Sort By'),
                  const SizedBox(height: 12),
                  _buildSortOptions(),
                  
                  const SizedBox(height: 32),
                  
                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _applyFilters,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _tempFilter.hasActiveFilters
                            ? 'Apply Filters (${_tempFilter.activeFilterCount})'
                            : 'Apply Filters',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildLevelChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // ALL option
        FilterChip(
          label: const Text('ALL'),
          selected: _tempFilter.selectedLevel == null,
          onSelected: (selected) {
            if (selected) _updateLevel(null);
          },
        ),
        // Individual levels
        ..._levels.map((level) => FilterChip(
          label: Text(level),
          selected: _tempFilter.selectedLevel == level,
          onSelected: (selected) {
            _updateLevel(selected ? level : null);
          },
        )),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // ALL option
        FilterChip(
          label: const Text('ALL'),
          selected: _tempFilter.selectedCategory == null,
          onSelected: (selected) {
            if (selected) _updateCategory(null);
          },
        ),
        // Individual categories
        ..._categories.map((category) => FilterChip(
          label: Text(category),
          selected: _tempFilter.selectedCategory == category,
          onSelected: (selected) {
            _updateCategory(selected ? category : null);
          },
        )),
      ],
    );
  }

  Widget _buildSortOptions() {
    return Column(
      children: SortBy.values.map((sortBy) {
        return RadioListTile<SortBy>(
          title: Text(sortBy.displayName),
          value: sortBy,
          groupValue: _tempFilter.sortBy,
          onChanged: (value) {
            if (value != null) _updateSortBy(value);
          },
          contentPadding: EdgeInsets.zero,
          dense: true,
        );
      }).toList(),
    );
  }
}

