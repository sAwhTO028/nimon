import 'package:flutter/material.dart';

/// Uppercase section label for Profile → Workspace lists (Drafts / Editing).
///
/// Uses [ColorScheme.onSurfaceVariant] so labels stay readable in dark mode.
class ProfileWorkspaceSectionHeader extends StatelessWidget {
  const ProfileWorkspaceSectionHeader({super.key, required this.title});

  /// Display title; shown uppercased (e.g. "Drafts" → "DRAFTS").
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
      child: Text(
        title.toUpperCase(),
        key: ValueKey('profile_workspace_section_${title.toLowerCase()}'),
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: cs.onSurfaceVariant,
          height: 1.0,
        ),
      ),
    );
  }
}
