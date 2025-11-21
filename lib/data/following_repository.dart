import '../models/following_writer.dart';

/// Repository for managing following writers data
class FollowingRepository {
  /// Fetch the list of writers that the user is following
  /// Currently returns mock data for UI testing
  Future<List<FollowingWriter>> fetchFollowingWriters() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    // Mock data - 3-5 writers for testing
    return [
      const FollowingWriter(
        id: '1',
        name: 'Yuki Tanaka',
        avatarUrl: null, // Will use initial fallback
      ),
      const FollowingWriter(
        id: '2',
        name: 'Hiroshi Yamada',
        avatarUrl: null,
      ),
      const FollowingWriter(
        id: '3',
        name: 'Sakura Nakamura',
        avatarUrl: null,
      ),
      const FollowingWriter(
        id: '4',
        name: 'Kenji Suzuki',
        avatarUrl: null,
      ),
      const FollowingWriter(
        id: '5',
        name: 'Mika Kobayashi',
        avatarUrl: null,
      ),
    ];
  }
}

/// Singleton instance for FollowingRepository
final followingRepo = FollowingRepository();

