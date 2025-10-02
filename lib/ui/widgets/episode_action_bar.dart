import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/share_utils.dart';
import '../../models/episode_meta.dart';

/// A reusable action bar widget for episode details with Save for Later, Share, and Start Reading buttons.
/// 
/// Features:
/// - Material 3 design with proper button styles and spacing
/// - Responsive layout that works on phones and landscape
/// - Fixed width secondary buttons (Save for Later, Share)
/// - Flexible primary button (Start Reading) that takes remaining space
/// - Proper accessibility support with semantic labels
/// - Safe area handling to avoid bottom navigation overlap
/// - State-aware button disabling during operations
class EpisodeActionBar extends StatefulWidget {
  final VoidCallback onSave;
  final VoidCallback? onShare;
  final VoidCallback onStart;
  final bool isLoading;
  final EpisodeMeta? episodeMeta; // Optional for built-in sharing

  const EpisodeActionBar({
    super.key,
    required this.onSave,
    this.onShare,
    required this.onStart,
    this.isLoading = false,
    this.episodeMeta,
  });

  @override
  State<EpisodeActionBar> createState() => _EpisodeActionBarState();
}

class _EpisodeActionBarState extends State<EpisodeActionBar> {
  bool _isSharing = false;

  Future<void> _handleShare() async {
    if (_isSharing) return;
    
    setState(() => _isSharing = true);
    
    try {
      // Add haptic feedback for better UX
      await HapticFeedback.lightImpact();
      
      if (widget.onShare != null) {
        widget.onShare!();
      } else if (widget.episodeMeta != null) {
        // Use built-in sharing if no custom callback provided
        await ShareUtils.shareEpisode(context, widget.episodeMeta!);
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const gap = SizedBox(width: 8); // Smaller gap to fit 3 buttons
    
    // Share button (icon only for compact design)
    final shareBtn = SizedBox(
      width: 48,
      height: 48,
      child: OutlinedButton(
        onPressed: (widget.isLoading || _isSharing) ? null : _handleShare,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.5),
            width: 1,
          ),
          padding: EdgeInsets.zero,
        ),
        child: _isSharing 
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              )
            : Icon(
                Icons.ios_share_rounded,
                size: 20,
                color: theme.colorScheme.onSurface,
              ),
      ),
    );

    // Save for Later button
    final saveBtn = Expanded(
      child: OutlinedButton.icon(
        onPressed: widget.isLoading ? null : widget.onSave,
        icon: Icon(
          Icons.bookmark_border_rounded,
          size: 20,
        ),
        label: Text(
          'Save for Later',
          style: theme.textTheme.labelLarge,
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
    );

    // Start Reading button (primary)
    final startBtn = Expanded(
      flex: 2, // Give more space to the primary button
      child: FilledButton.icon(
        onPressed: (widget.isLoading || _isSharing) ? null : widget.onStart,
        icon: const Icon(Icons.play_arrow_rounded, size: 22),
        label: const Text('Start Reading'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
        ),
      ),
    );

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Semantics(
        container: true,
        label: 'Episode actions',
        child: Row(
          children: [
            // Share button (icon only)
            Semantics(
              button: true,
              label: 'Share episode',
              child: shareBtn,
            ),
            gap,
            
            // Save for Later button
            Semantics(
              button: true,
              label: 'Save episode for later',
              child: saveBtn,
            ),
            gap,
            
            // Start Reading button (primary)
            Semantics(
              button: true,
              label: 'Start reading episode',
              child: startBtn,
            ),
          ],
        ),
      ),
    );
  }
}
