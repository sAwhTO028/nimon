import 'package:flutter/material.dart';
import '../../../models/episode_model.dart';
import '../../../models/episode_meta.dart';
import 'episode_modal_sheet.dart';

/// Shows a Material 3 compliant Episode Modal Bottom Sheet
/// 
/// Features:
/// - M3 spec compliant design with proper elevation and colors
/// - DraggableScrollableSheet with proper size constraints
/// - Safe area handling to avoid bottom navigation overlap
/// - Proper dismissal gestures (tap scrim, swipe down)
/// - Responsive design for landscape/tablet
/// - Haptic feedback and smooth animations
/// 
/// Parameters:
/// - [context]: The build context to show the sheet in
/// - [episode]: Episode data to display
/// - [onStartReading]: Callback when user taps "Start Reading"
/// - [onSave]: Callback when user taps "Save for Later"
/// 
/// Returns a Future that completes when the sheet is dismissed.
Future<void> showEpisodeModal(
  BuildContext context,
  EpisodeModel episode, {
  VoidCallback? onStartReading,
  VoidCallback? onSave,
}) {
  final mediaQuery = MediaQuery.of(context);
  final screenHeight = mediaQuery.size.height;
  
  // Adjust initial size for very small devices
  final initialChildSize = screenHeight < 640 ? 0.50 : 0.55;
  
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    barrierColor: Colors.black.withOpacity(0.35),
    elevation: 2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(28),
      ),
    ),
    builder: (context) => DraggableScrollableSheet(
      minChildSize: 0.45,
      initialChildSize: initialChildSize,
      maxChildSize: 0.95, // Ensure <= 1.0 to avoid assertion
      snap: true,
      expand: false,
      builder: (context, scrollController) {
        return EpisodeModalSheet(
          episode: episode,
          controller: scrollController,
          onStartReading: onStartReading,
          onSave: onSave,
        );
      },
    ),
  );
}

/// Convenience function to show modal from EpisodeMeta
Future<void> showEpisodeModalFromMeta(
  BuildContext context,
  EpisodeMeta meta, {
  VoidCallback? onStartReading,
  VoidCallback? onSave,
}) {
  final episode = EpisodeModel.fromEpisodeMeta(meta);
  return showEpisodeModal(
    context,
    episode,
    onStartReading: onStartReading,
    onSave: onSave,
  );
}
