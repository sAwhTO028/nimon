import 'package:flutter/material.dart';

/// Shared circular control for page-level navigation (back / close).
///
/// Light filled circle, subtle border, and [Icons.arrow_back_ios_new_rounded] by
/// default so every screen reads the same. Use [NimonBackButton] in [AppBar.leading].
class NimonCircleNavButton extends StatelessWidget {
  const NimonCircleNavButton({
    super.key,
    required this.onPressed,
    this.icon = Icons.arrow_back_ios_new_rounded,
    this.tooltip,
    this.semanticLabel,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;
  final String? semanticLabel;

  static const double diameter = 40;
  static const double iconSize = 20;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final fill = brightness == Brightness.light
        ? Colors.white
        : scheme.surfaceContainerHighest;
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.38);
    final iconTint = scheme.onSurface.withValues(alpha: 0.80);

    Widget circle = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Ink(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
          ),
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: iconTint,
            ),
          ),
        ),
      ),
    );

    final tip = tooltip;
    if (tip != null && tip.trim().isNotEmpty) {
      circle = Tooltip(message: tip, child: circle);
    }

    final label = semanticLabel ?? tip;
    if (label != null && label.trim().isNotEmpty) {
      circle = Semantics(
        button: true,
        label: label,
        child: circle,
      );
    }

    return circle;
  }
}

/// [AppBar] leading slot: same circular style as [NimonCircleNavButton], sized for
/// the toolbar. Hides when the route cannot pop unless [onPressed] is provided.
class NimonBackButton extends StatelessWidget {
  const NimonBackButton({
    super.key,
    this.onPressed,
    this.tooltip,
    this.icon = Icons.arrow_back_ios_new_rounded,
  });

  final VoidCallback? onPressed;
  final String? tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final explicit = onPressed != null;
    final canPop = route?.canPop ?? false;
    if (!explicit && !canPop) {
      return const SizedBox.shrink();
    }

    void handle() {
      final fn = onPressed;
      if (fn != null) {
        fn();
      } else {
        Navigator.of(context).maybePop();
      }
    }

    final backTooltip = tooltip ??
        (icon == Icons.arrow_back_ios_new_rounded
            ? MaterialLocalizations.of(context).backButtonTooltip
            : (icon == Icons.close_rounded ? 'Close' : null));

    return SizedBox(
      width: 56,
      height: 56,
      child: Center(
        child: NimonCircleNavButton(
          onPressed: handle,
          icon: icon,
          tooltip: backTooltip,
          semanticLabel: backTooltip,
        ),
      ),
    );
  }
}
