import 'package:flutter/material.dart';
import 'package:nimon/core/design_system/nimon_breakpoints.dart';
import 'package:nimon/core/design_system/nimon_tokens.dart';
import 'package:nimon/core/design_system/nimon_typography.dart';

class NimonDrawerAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  const NimonDrawerAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.destructive = false,
  });
}

class NimonDrawerSection extends StatelessWidget {
  final String label;
  final List<NimonDrawerAction> actions;

  const NimonDrawerSection({
    super.key,
    required this.label,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wc = NimonBreakpoints.of(context);
    final s = theme.space;
    final r = theme.radii;
    final type = theme.type;

    final sectionStyle = type.metadata(theme, wc).copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
          letterSpacing: 0.08,
          fontWeight: FontWeight.w700,
        );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: s.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: s.x3),
            child: Text(label.toUpperCase(), style: sectionStyle),
          ),
          SizedBox(height: s.x2),
          ClipRRect(
            borderRadius: r.radiusXl,
            child: Material(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.28 : 0.55,
              ),
              child: Column(
                children: [
                  for (int i = 0; i < actions.length; i++) ...[
                    _DrawerRow(action: actions[i]),
                    if (i != actions.length - 1)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.06),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerRow extends StatelessWidget {
  final NimonDrawerAction action;

  const _DrawerRow({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wc = NimonBreakpoints.of(context);
    final s = theme.space;
    final type = theme.type;

    final textStyle = type.sectionTitle(theme, wc).copyWith(
          fontSize: wc == NimonWidthClass.compact ? 16 : 17,
          fontWeight: FontWeight.w600,
          color: action.destructive
              ? theme.colorScheme.error
              : theme.colorScheme.onSurface,
        );

    final iconColor = action.destructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface.withValues(alpha: 0.86);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.x3, vertical: s.x3),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Icon(action.icon, size: 20, color: iconColor),
              ),
              SizedBox(width: s.x2),
              Expanded(
                child: Text(
                  action.label,
                  style: textStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: s.x2),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
