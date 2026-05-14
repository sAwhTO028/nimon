import 'package:flutter/material.dart';

/// On-card primary text (term, title) in creator learn modules.
Color learnCreatorModulePrimaryTextColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;

/// Secondary lines (reading, summaries, type chip).
Color learnCreatorModuleSecondaryTextColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

/// Card fill aligned with [ColorScheme.surface].
Color learnCreatorModuleCardSurfaceColor(BuildContext context) =>
    Theme.of(context).colorScheme.surface;

/// Subtle card outline.
Color learnCreatorModuleCardBorderColor(BuildContext context) =>
    Theme.of(context).colorScheme.outlineVariant;

/// Text + icon actions on learn cards (matches primary TextButton emphasis).
Color learnCreatorModuleActionForegroundColor(BuildContext context) =>
    Theme.of(context).colorScheme.primary;
