import 'package:flutter/material.dart';

class PremiumBanner extends StatelessWidget {
  const PremiumBanner({
    super.key,
    this.onTap,
    this.title = 'Unlock JLPT Advanced Stories',
    this.subtitle = 'Ad-free, offline reading, N3–N1 exclusives',
    this.ctaText = 'Upgrade',
  });

  final VoidCallback? onTap;
  final String title;
  final String subtitle;
  final String ctaText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primaryContainer,
                cs.primary.withOpacity(.90),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Left icon / illustration circle
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: cs.onPrimary.withOpacity(.10),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: cs.onPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                // Texts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: cs.onPrimary.withOpacity(.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // CTA
                FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.onPrimary,
                    foregroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    textStyle: textTheme.labelLarge,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(ctaText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
