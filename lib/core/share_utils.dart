import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/episode_meta.dart';

/// Utility class for sharing episode content
class ShareUtils {
  /// Shares an episode with platform-specific share sheet
  /// 
  /// Creates a deeplink URL and episode description for sharing
  /// Falls back to clipboard copy if platform sharing is not available
  static Future<void> shareEpisode(BuildContext context, EpisodeMeta episode) async {
    try {
      // Generate episode deeplink (this would be your actual app's deep link format)
      final deeplink = 'https://nimon.app/episode/${episode.id}';
      
      // Create share text with episode details
      final shareText = '''
Check out this episode on Nimon! 📚

${episode.title}
${episode.episodeNo}
By ${episode.authorName}

${episode.preview.isNotEmpty ? '${episode.preview}\n\n' : ''}$deeplink
''';

      // For now, we'll copy to clipboard and show a snackbar
      // In a real app, you would use share_plus package or platform channels
      await Clipboard.setData(ClipboardData(text: shareText));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Episode link copied to clipboard!')),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Handle error gracefully
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Failed to share episode'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  /// Creates a shareable deeplink for an episode
  static String createEpisodeDeeplink(String episodeId) {
    return 'https://nimon.app/episode/$episodeId';
  }

  /// Creates formatted share text for an episode
  static String createShareText(EpisodeMeta episode) {
    final deeplink = createEpisodeDeeplink(episode.id);
    
    return '''
Check out this episode on Nimon! 📚

${episode.title}
${episode.episodeNo}
By ${episode.authorName}

${episode.preview.isNotEmpty ? '${episode.preview}\n\n' : ''}$deeplink
''';
  }
}
