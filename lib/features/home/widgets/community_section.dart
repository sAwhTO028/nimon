import 'package:flutter/material.dart';
import 'community_collection_card.dart';

class CommunitySection extends StatelessWidget {
  final VoidCallback? onSeeAllTap;

  const CommunitySection({
    super.key,
    this.onSeeAllTap,
  });

  // Demo data for community collections
  static final List<CommunityCollectionData> _demoCollections = [
    CommunityCollectionData(
      title: 'Myanmar Hits',
      description: 'Stories from Myanmar community writers with authentic cultural insights and language learning.',
      coverUrl: 'https://picsum.photos/seed/1/200/300',
      jlptLevel: 'N2',
      storyType: 'Cultural',
      totalEpisodes: 20,
      episodes: [
        CommunityEpisode(
          title: 'Traditional Festival',
          episodeNumber: 1,
          thumbnailUrl: 'https://picsum.photos/seed/101/100/100',
        ),
        CommunityEpisode(
          title: 'Market Stories',
          episodeNumber: 2,
          thumbnailUrl: 'https://picsum.photos/seed/102/100/100',
        ),
        CommunityEpisode(
          title: 'Family Traditions',
          episodeNumber: 3,
          thumbnailUrl: 'https://picsum.photos/seed/103/100/100',
        ),
      ],
    ),
    CommunityCollectionData(
      title: 'Tokyo Adventures',
      description: 'Explore modern Tokyo through engaging stories and everyday conversations.',
      coverUrl: 'https://picsum.photos/seed/2/200/300',
      jlptLevel: 'N3',
      storyType: 'Adventure',
      totalEpisodes: 15,
      episodes: [
        CommunityEpisode(
          title: 'Train Station Chaos',
          episodeNumber: 1,
          thumbnailUrl: 'https://picsum.photos/seed/201/100/100',
        ),
        CommunityEpisode(
          title: 'Café Culture',
          episodeNumber: 2,
          thumbnailUrl: 'https://picsum.photos/seed/202/100/100',
        ),
        CommunityEpisode(
          title: 'Night Life',
          episodeNumber: 3,
          thumbnailUrl: 'https://picsum.photos/seed/203/100/100',
        ),
      ],
    ),
    CommunityCollectionData(
      title: 'Business Japanese',
      description: 'Professional Japanese conversations and business etiquette for workplace success.',
      coverUrl: 'https://picsum.photos/seed/3/200/300',
      jlptLevel: 'N1',
      storyType: 'Professional',
      totalEpisodes: 25,
      episodes: [
        CommunityEpisode(
          title: 'Meeting Etiquette',
          episodeNumber: 1,
          thumbnailUrl: 'https://picsum.photos/seed/301/100/100',
        ),
        CommunityEpisode(
          title: 'Email Writing',
          episodeNumber: 2,
          thumbnailUrl: 'https://picsum.photos/seed/302/100/100',
        ),
        CommunityEpisode(
          title: 'Client Relations',
          episodeNumber: 3,
          thumbnailUrl: 'https://picsum.photos/seed/303/100/100',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
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
        // Horizontal scrolling community collections
        SizedBox(
          height: 350, // Set a fixed height to prevent overflow
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _demoCollections.length,
            itemBuilder: (context, index) {
              final collection = _demoCollections[index];
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: CommunityCollectionCard(
                    title: collection.title,
                    authorLine: 'by Community Writers',
                    description: collection.description,
                    coverUrl: collection.coverUrl,
                    jlptLevel: collection.jlptLevel,
                    totalEpisodes: collection.totalEpisodes,
                    storyType: collection.storyType,
                    episodes: collection.episodes,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// Data model for community collections
class CommunityCollectionData {
  final String title;
  final String description;
  final String coverUrl;
  final String jlptLevel;
  final String storyType;
  final int totalEpisodes;
  final List<CommunityEpisode> episodes;

  CommunityCollectionData({
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.jlptLevel,
    required this.storyType,
    required this.totalEpisodes,
    required this.episodes,
  });
}
