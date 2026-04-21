import 'package:flutter/material.dart';

/// V1 floating dock: Mono | Add (center) | Profile — same geometry as the shell.
class FloatingDockNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final ThemeData theme;

  const FloatingDockNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.theme,
  });

  static const dockRadius = 26.0;
  static const dockPillHeight = 60.0;
  static const dockOuterBottomPad = 12.0;

  /// Total height from physical screen bottom to dock pill top (padding + inset + pill).
  static double dockOccupiedZoneHeight(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return dockOuterBottomPad + bottomInset + dockPillHeight;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final dockFill = Color.lerp(
          colorScheme.surface,
          Colors.white,
          0.35,
        ) ??
        colorScheme.surface;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, dockOuterBottomPad + bottomInset),
      child: Material(
        color: dockFill.withOpacity(0.94),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.14),
        borderRadius: BorderRadius.circular(dockRadius),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: dockPillHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _DockNavItem(
                  icon: Icons.menu_book_outlined,
                  selectedIcon: Icons.menu_book_rounded,
                  label: 'Mono',
                  isSelected: selectedIndex == 0,
                  onTap: () => onItemTapped(0),
                  colorScheme: colorScheme,
                  emphasize: false,
                ),
              ),
              Expanded(
                child: _DockNavItem(
                  icon: Icons.add_rounded,
                  selectedIcon: Icons.add_rounded,
                  label: 'Add',
                  isSelected: false,
                  onTap: () => onItemTapped(1),
                  colorScheme: colorScheme,
                  emphasize: true,
                ),
              ),
              Expanded(
                child: _DockNavItem(
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  label: 'Profile',
                  isSelected: selectedIndex == 2,
                  onTap: () => onItemTapped(2),
                  colorScheme: colorScheme,
                  emphasize: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockNavItem extends StatelessWidget {
  static const _iconBandH = 28.0;
  static const _iconSize = 20.0;
  static const _iconGap = 4.0;
  static const _labelFontSize = 10.0;

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final bool emphasize;

  const _DockNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
    required this.emphasize,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Colors.grey.shade600;
    final inactive = muted.withOpacity(0.88);
    final selectedColor = colorScheme.primary;
    final iconColor = emphasize
        ? colorScheme.primary
        : (isSelected ? selectedColor : inactive);
    final labelColor = emphasize
        ? colorScheme.primary
        : (isSelected ? selectedColor : inactive);
    final labelWeight = emphasize
        ? FontWeight.w700
        : (isSelected ? FontWeight.w600 : FontWeight.w500);

    final iconCore = Icon(
      isSelected ? selectedIcon : icon,
      color: iconColor,
      size: _iconSize,
    );

    final Widget iconBand = SizedBox(
      height: _iconBandH,
      child: Center(
        child: emphasize
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.13),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: iconCore,
                ),
              )
            : iconCore,
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FloatingDockNavBar.dockRadius),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                iconBand,
                const SizedBox(height: _iconGap),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: _labelFontSize,
                    height: 1.0,
                    leadingDistribution: TextLeadingDistribution.proportional,
                    color: labelColor,
                    fontWeight: labelWeight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
