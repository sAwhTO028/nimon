import 'package:flutter/material.dart';
import 'package:nimon/features/profile/mono_story_list_row.dart';
import 'package:nimon/features/profile/public_profile_data.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// Public folder contents as seen by learners (no owner controls).
class PublicFolderDetailScreen extends StatelessWidget {
  const PublicFolderDetailScreen({
    super.key,
    required this.folderId,
  });

  final String folderId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bundle = nimonDemoPublicProfile;
    final folder = bundle.folderById(folderId);
    final stories = folder == null
        ? const <PublicStory>[]
        : bundle.storiesForFolder(folder);

    return Scaffold(
      appBar: AppBar(
        title: Text(folder?.name ?? 'Collection'),
        centerTitle: false,
        leading: const NimonBackButton(),
      ),
      body: folder == null
          ? Center(
              child: Text(
                'This folder is not available.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if ((folder.description ?? '').trim().isNotEmpty) ...[
                  Text(
                    folder.description!.trim(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  '${folder.storyCount} stor${folder.storyCount == 1 ? 'y' : 'ies'}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (ctx) {
                    final dividerColor =
                        scheme.outlineVariant.withValues(alpha: 0.28);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < stories.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              thickness: 0.5,
                              color: dividerColor,
                            ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Open “${stories[i].title}” — coming soon',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: MonoStoryListRow(
                                title: stories[i].title,
                                description: stories[i].description,
                                jlptLevel: stories[i].jlptLevel,
                                thumbnailUrl: stories[i].thumbnailUrl,
                                onMenuTap: null,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }
}
