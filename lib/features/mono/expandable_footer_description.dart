import 'package:flutter/material.dart';

/// Story Basics line for the Mono feed footer: two-line preview with optional
/// [See more] / [See less].
class ExpandableFooterDescription extends StatefulWidget {
  const ExpandableFooterDescription({
    super.key,
    required this.text,
    required this.inkMuted,
  });

  final String text;
  final Color inkMuted;

  static const int previewMaxLines = 2;

  /// Whether [text] needs more than [maxLines] when laid out at [maxWidth].
  @visibleForTesting
  static bool textExceedsPreviewLines({
    required String text,
    required TextStyle style,
    required double maxWidth,
    int maxLines = previewMaxLines,
  }) {
    final t = text.trim();
    if (t.isEmpty || maxWidth <= 0) return false;
    final painter = TextPainter(
      text: TextSpan(text: t, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  @override
  State<ExpandableFooterDescription> createState() =>
      _ExpandableFooterDescriptionState();
}

class _ExpandableFooterDescriptionState
    extends State<ExpandableFooterDescription> {
  bool _expanded = false;

  /// Keeps the footer compact while still exposing full copy (scroll if needed).
  static const double _expandedScrollMaxHeight = 172;

  TextStyle _descriptionStyle(ThemeData theme) {
    final base = theme.textTheme.labelSmall ?? const TextStyle();
    return base.copyWith(
      color: widget.inkMuted,
      fontWeight: FontWeight.w600,
      fontSize: 10.5,
      letterSpacing: 0.15,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.text.trim();
    if (t.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final style = _descriptionStyle(theme);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final exceeds = ExpandableFooterDescription.textExceedsPreviewLines(
          text: t,
          style: style,
          maxWidth: w,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_expanded)
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: _expandedScrollMaxHeight,
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Text(
                    t,
                    style: style,
                    softWrap: true,
                  ),
                ),
              )
            else
              Text(
                t,
                style: style,
                maxLines: ExpandableFooterDescription.previewMaxLines,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
              ),
            if (exceeds) ...[
              const SizedBox(height: 2),
              TextButton(
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: widget.inkMuted,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'See less' : 'See more',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: widget.inkMuted,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
