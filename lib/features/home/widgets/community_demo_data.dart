import 'community_models.dart';

class CommunityDemoData {
  static List<CommunityCardVM> getCommunities() {
    return [
      CommunityCardVM(
        title: "Myanmar Hits",
        level: "N2",
        description: "Story Descriptions Story Descriptions Story Descriptions Story Descriptions Story Descriptions.....",
        genre: "Love",
        totalEpisodes: 20,
        coverUrl: "https://picsum.photos/seed/myanmar/200/300",
        episodes: [
          CommunityEpisodeVM(
            title: "Episode Title One",
            number: 1,
            thumb: "https://picsum.photos/seed/ep1/100/100",
          ),
          CommunityEpisodeVM(
            title: "Episode Title Two",
            number: 2,
            thumb: "https://picsum.photos/seed/ep2/100/100",
          ),
          CommunityEpisodeVM(
            title: "Episode Title Three",
            number: 3,
            thumb: "https://picsum.photos/seed/ep3/100/100",
          ),
        ],
      ),
      CommunityCardVM(
        title: "Tokyo Stories",
        level: "N3",
        description: "Explore the vibrant streets of Tokyo through these captivating stories that bring the city to life.",
        genre: "Adventure",
        totalEpisodes: 15,
        coverUrl: "https://picsum.photos/seed/tokyo/200/300",
        episodes: [
          CommunityEpisodeVM(
            title: "Shibuya Crossing",
            number: 1,
            thumb: "https://picsum.photos/seed/tokyo1/100/100",
          ),
          CommunityEpisodeVM(
            title: "Cherry Blossoms",
            number: 2,
            thumb: "https://picsum.photos/seed/tokyo2/100/100",
          ),
          CommunityEpisodeVM(
            title: "Night Lights",
            number: 3,
            thumb: "https://picsum.photos/seed/tokyo3/100/100",
          ),
        ],
      ),
      CommunityCardVM(
        title: "Kyoto Tales",
        level: "N1",
        description: "Traditional stories from the ancient capital, filled with wisdom and cultural richness.",
        genre: "Historical",
        totalEpisodes: 25,
        coverUrl: "https://picsum.photos/seed/kyoto/200/300",
        episodes: [
          CommunityEpisodeVM(
            title: "Temple Wisdom",
            number: 1,
            thumb: "https://picsum.photos/seed/kyoto1/100/100",
          ),
          CommunityEpisodeVM(
            title: "Garden Secrets",
            number: 2,
            thumb: "https://picsum.photos/seed/kyoto2/100/100",
          ),
          CommunityEpisodeVM(
            title: "Ancient Paths",
            number: 3,
            thumb: "https://picsum.photos/seed/kyoto3/100/100",
          ),
        ],
      ),
    ];
  }
}
