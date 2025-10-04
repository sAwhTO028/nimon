import 'package:flutter/material.dart';
import '../../../models/section_key.dart';
import '../../../data/story_repo.dart';
import '../../see_more/see_more_page.dart';

/// Standardized section header widget for consistent styling across all home screen sections
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAllTap;
  final VoidCallback? onTap; // New: for making entire header clickable
  final SectionKey? sectionKey; // New: for automatic navigation
  final StoryRepo? storyRepo; // New: for passing to SeeMorePage
  final bool showSeeAll;
  final EdgeInsets padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAllTap,
    this.onTap,
    this.sectionKey,
    this.storyRepo,
    this.showSeeAll = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Determine the tap handler
    VoidCallback? tapHandler;
    if (onTap != null) {
      tapHandler = onTap;
    } else if (sectionKey != null && sectionKey!.supportsSeeMore) {
      tapHandler = () => _navigateToSeeMore(context);
    } else if (onSeeAllTap != null) {
      tapHandler = onSeeAllTap;
    } else if (showSeeAll) {
      tapHandler = () => _showComingSoonSnackbar(context);
    }
    
    return Padding(
      padding: padding,
      child: showSeeAll && tapHandler != null
          ? InkWell(
              onTap: tapHandler,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ).copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      size: 24,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ],
                ),
              ),
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ).copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
    );
  }

  void _navigateToSeeMore(BuildContext context) {
    if (sectionKey == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SeeMorePage(
          section: sectionKey!,
          storyRepo: storyRepo,
        ),
      ),
    );
  }

  void _showComingSoonSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('See all $title coming soon!'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
