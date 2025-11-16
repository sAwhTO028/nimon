import 'package:flutter/material.dart';
import '../../data/prompt_repository.dart';

class OneShortPromptCard extends StatelessWidget {
  final Prompt prompt;
  final bool selected;
  final VoidCallback? onTap;

  const OneShortPromptCard({
    super.key,
    required this.prompt,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Material 3 styling with consistent borderRadius
    return Container(
      // Margin between cards for proper spacing
      margin: const EdgeInsets.only(bottom: 6.0),
      child: Material(
        color: selected ? const Color(0xFFEEF5FF) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: selected ? 2 : 0,
        shadowColor: Colors.black.withOpacity(0.05),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant.withOpacity(0.5),
                width: selected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prompt.title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: .1)),
                    const SizedBox(height: 2),
                    Text(
                      'Context: ${prompt.context}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Duration: ${prompt.duration}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            )),
                        const Spacer(),
                        Container(
                          margin: const EdgeInsets.only(right: 0),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            prompt.category,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (selected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 24,
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


