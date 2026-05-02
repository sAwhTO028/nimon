import 'package:flutter/material.dart';
import 'package:nimon/data/story_repo.dart';
import 'package:nimon/models/story.dart';
import 'package:nimon/core/story_categories.dart';
import '../../../models/section_key.dart';
import 'community_collection_card.dart';
import 'section_header.dart';

class CommunitySection extends StatefulWidget {
  final StoryRepo repo;
  final VoidCallback? onSeeAllTap;

  const CommunitySection({
    super.key,
    required this.repo,
    this.onSeeAllTap,
  });

  @override
  State<CommunitySection> createState() => _CommunitySectionState();
}

class _CommunitySectionState extends State<CommunitySection> {
  late Future<List<_CommunityCollectionData>> _collectionsFuture;

  @override
  void initState() {
    super.initState();
    _collectionsFuture = _loadCommunityCollections();
  }

  Future<List<_CommunityCollectionData>> _loadCommunityCollections() async {
    // Get a subset of stories for the community section
    final stories = await widget.repo.getStories();
    final collections = <_CommunityCollectionData>[];

    // Take the first 3 stories for the community section
    for (final story in stories.take(3)) {
      final episodes = await widget.repo.getEpisodesByStory(story.id);
      
      collections.add(_CommunityCollectionData(
        story: story,
        episodes: episodes,
      ));
    }

    return collections;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return FutureBuilder<List<_CommunityCollectionData>>(
      future: _collectionsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 350,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final collections = snapshot.data!;
        if (collections.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
              child: SectionHeader(
                title: 'From the Community',
                sectionKey: SectionKey.fromTheCommunity,
                storyRepo: widget.repo,
                onSeeAllTap: widget.onSeeAllTap,
              ),
            ),
            // Horizontal scrolling community collections
            SizedBox(
              height: 350, // Set a fixed height to prevent overflow
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: collections.length,
                itemBuilder: (context, index) {
                  final collection = collections[index];
                  final story = collection.story;
                  final episodes = collection.episodes;
                  final category = story.tags.isNotEmpty ? story.tags.first : 'Story';
                  
                  // Map episodes to CommunityEpisode format
                  // Use local assets if available, otherwise fall back to placeholder URLs
                  final communityEpisodes = episodes.take(3).map((ep) {
                    String thumbnailUrl;
                    if (ep.thumbnailUrl != null && ep.thumbnailUrl!.isNotEmpty) {
                      thumbnailUrl = ep.thumbnailUrl!;
                    } else {
                      // Try to use local asset based on category
                      final assetPath = StoryCategories.getEpisodeThumbnailPath(category, ep.index);
                      thumbnailUrl = assetPath ?? 
                          'https://picsum.photos/seed/${story.id}_${ep.index}/100/100';
                    }
                    
                    return CommunityEpisode(
                      title: ep.title ?? 'Episode ${ep.index}',
                      episodeNumber: ep.index,
                      thumbnailUrl: thumbnailUrl,
                    );
                  }).toList();

                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: CommunityCollectionCard(
                        title: story.title,
                        authorLine: 'by Community Writers',
                        description: story.description,
                        coverUrl: story.coverUrl ?? 
                            'https://picsum.photos/seed/${story.id}/200/300',
                        jlptLevel: story.jlptLevel,
                        totalEpisodes: episodes.length,
                        storyType: category,
                        episodes: communityEpisodes,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

// Internal data holder for community collections
class _CommunityCollectionData {
  final Story story;
  final List<Episode> episodes;

  _CommunityCollectionData({
    required this.story,
    required this.episodes,
  });
}
