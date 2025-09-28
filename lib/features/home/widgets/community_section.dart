import 'package:flutter/material.dart';
import 'community_card_new.dart';
import 'community_models.dart';

class CommunitySection extends StatelessWidget {
  final List<CommunityCardVM> communities;
  final ValueChanged<CommunityCardVM>? onCardTap;
  final ValueChanged<CommunityEpisodeVM>? onEpisodeTap;
  final VoidCallback? onSeeAllTap;

  const CommunitySection({
    super.key,
    required this.communities,
    this.onCardTap,
    this.onEpisodeTap,
    this.onSeeAllTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Row(
            children: [
              Text(
                'From the Community',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              // "See all" button
              Material(
                color: theme.colorScheme.primaryContainer.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: onSeeAllTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: Text(
                        'See all >',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Horizontal carousel with dynamic height
        SizedBox(
          height: 240, // Reduced height to prevent overflow
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: communities.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final community = communities[index];
              return CommunityCard(
                vm: community,
                onCardTap: () => onCardTap?.call(community),
                onEpisodeTap: onEpisodeTap,
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
