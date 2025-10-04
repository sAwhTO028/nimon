import 'package:flutter/material.dart';
import '../../../models/oneshot.dart';
import '../../../data/story_repo.dart';
import '../widgets/section_header.dart';
import '../../../shared/widgets/cards/oneshot_badged_card.dart';

/// Quick One-Shot For You section displaying personalized one-shot stories
class QuickOneShotSection extends StatefulWidget {
  const QuickOneShotSection({
    super.key,
    required this.storyRepo,
  });

  final StoryRepo storyRepo;

  @override
  State<QuickOneShotSection> createState() => _QuickOneShotSectionState();
}

class _QuickOneShotSectionState extends State<QuickOneShotSection> {
  List<OneShot> _oneShots = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadOneShots();
  }

  Future<void> _loadOneShots() async {
    try {
      final oneShots = await widget.storyRepo.fetchQuickOneShots();
      if (mounted) {
        setState(() {
          _oneShots = oneShots;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        const SectionHeader(
          title: 'Quick One-Shot For You',
          showSeeAll: true,
        ),
        const SizedBox(height: 16),
        
        // Content area (reduced height for more compact cards)
        SizedBox(
          height: 220,
          child: _buildContent(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    if (_hasError) {
      return _buildErrorState();
    }
    
    if (_oneShots.isEmpty) {
      return _buildEmptyState();
    }
    
    return _buildOneShotsList();
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      itemBuilder: (context, index) => _buildSkeletonCard(),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  color: Colors.grey[300],
                ),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.grey[400],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load one-shots',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadOneShots,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No one-shots yet',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for personalized recommendations',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOneShotsList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _oneShots.length,
      itemBuilder: (context, index) {
        final oneShot = _oneShots[index];
        return OneShotBadgedCard(
          oneShot: oneShot,
          onTap: () => _onOneShotTap(oneShot),
        );
      },
    );
  }

  void _onOneShotTap(OneShot oneShot) {
    // TODO: Navigate to one-shot reader or details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${oneShot.title}'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
