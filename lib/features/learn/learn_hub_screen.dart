import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/learn/learn_explanation_language.dart';
import 'package:nimon/features/learn/learn_explanation_language_provider.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// Grid entry from Mono; [contentId] ties learning to the current reading post.
class LearnHubScreen extends ConsumerStatefulWidget {
  final String contentId;
  final String? coverImageUrl;
  final String? coverFallbackAsset;
  final String? storyTitle;
  final String? level;
  final String? category;
  final String? unlock;
  final String? description;

  const LearnHubScreen({
    super.key,
    this.contentId = 'mono',
    this.coverImageUrl,
    this.coverFallbackAsset,
    this.storyTitle,
    this.level,
    this.category,
    this.unlock,
    this.description,
  });

  @override
  ConsumerState<LearnHubScreen> createState() => _LearnHubScreenState();
}

class _LearnHubScreenState extends ConsumerState<LearnHubScreen> {
  static const _bg = Color(0xFFF6F3EA);
  static const _ink = Color(0xFF1A1917);
  static const _cardRadius = 18.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref.read(learnExplanationLanguageProvider.notifier).reloadFromPrefs(),
      );
    });
  }

  Widget _cover(BuildContext context) {
    final url = widget.coverImageUrl?.trim();
    final fallback = widget.coverFallbackAsset;

    Widget img;
    if (url != null && url.isNotEmpty) {
      img = Image.network(
        url,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (_, __, ___) {
          if (fallback == null) return const SizedBox.shrink();
          return Image.asset(
            fallback,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          );
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const ColoredBox(color: Color(0x14000000));
        },
      );
    } else if (fallback != null) {
      img = Image.asset(
        fallback,
        fit: BoxFit.cover,
        alignment: Alignment.center,
      );
    } else {
      img = const ColoredBox(color: Color(0x14000000));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            img,
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.10),
                    Colors.black.withOpacity(0.22),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _learnCard(
    BuildContext context, {
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white.withOpacity(0.86),
      elevation: 0,
      borderRadius: BorderRadius.circular(_cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_cardRadius),
        onTap: onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label（${widget.contentId}）')),
              );
            },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_cardRadius),
            border: Border.all(color: const Color(0x14000000)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0x0A000000),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 24, color: _ink),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Reuses the project’s existing “4 small stat cards in one row” pattern
  /// (see `StoryDetailScreen._fixedTagsRow` / `_buildStatCard`).
  Widget _fixedInfoRow({
    required String level,
    required String category,
    required String unlock,
  }) {
    const gap = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        const horizontalPadding = 0.0; // already padded by the page
        final cardWidth = (screenWidth - horizontalPadding - gap * 3) / 4;

        final cards = <Widget>[
          _statCard(
            context,
            icon: Icons.school_outlined,
            value: level,
            caption: 'Level',
            width: cardWidth,
          ),
          _statCard(
            context,
            icon: Icons.favorite_border,
            value: category,
            caption: 'Category',
            width: cardWidth,
          ),
          _statCard(
            context,
            icon: Icons.download_for_offline_outlined,
            value: 'Download',
            caption: 'Use offline',
            width: cardWidth,
          ),
          _statCard(
            context,
            icon: Icons.lock_outline,
            value: unlock,
            caption: 'Unlock',
            width: cardWidth,
          ),
        ];

        if (screenWidth < 320) {
          return Wrap(
            spacing: gap,
            runSpacing: 8,
            children: cards,
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: gap),
            Expanded(child: cards[1]),
            const SizedBox(width: gap),
            Expanded(child: cards[2]),
            const SizedBox(width: gap),
            Expanded(child: cards[3]),
          ],
        );
      },
    );
  }

  Widget _statCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String caption,
    required double width,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final v = value.trim().isEmpty ? '—' : value.trim();

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      child: SizedBox(
        width: width,
        height: 80,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.86),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x14000000), width: 1),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {},
              child: Semantics(
                label: '$v $caption',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      v,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String t) {
    final theme = Theme.of(context);
    return Text(
      t,
      style: theme.textTheme.titleMedium?.copyWith(
        color: _ink,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final tiles = <(String, IconData)>[
      ('Vocabulary / Kanji', Icons.font_download_outlined),
      ('Grammar Learn', Icons.rule_folder_outlined),
      ('Quiz Practice', Icons.quiz_outlined),
      ('Listening / Pronunciation', Icons.hearing_outlined),
    ];

    final title = (widget.storyTitle ?? '').trim();
    final showTitle = title.isNotEmpty ? title : 'Mono Story';
    final vLevel = (widget.level ?? '').trim().isNotEmpty
        ? widget.level!.trim()
        : '—';
    final vCategory = (widget.category ?? '').trim().isNotEmpty
        ? widget.category!.trim()
        : '—';
    final vUnlock =
        (widget.unlock ?? '').trim().isNotEmpty ? widget.unlock!.trim() : '—';
    final vDesc = (widget.description ?? '').trim();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          // This page does not render the floating dock; only pad by the real device inset.
          padding: EdgeInsets.fromLTRB(18, 10, 18, bottomInset + 18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        NimonCircleNavButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          tooltip: 'Back',
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Learn',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: _ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        PopupMenuButton<LearnExplanationLanguage>(
                          tooltip: 'Explanation language',
                          icon: const Icon(Icons.translate_outlined),
                          color: Colors.white,
                          onSelected: (v) {
                            unawaited(
                              ref
                                  .read(learnExplanationLanguageProvider
                                      .notifier)
                                  .setLanguage(v),
                            );
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: LearnExplanationLanguage.english,
                              child: Text('English meanings'),
                            ),
                            PopupMenuItem(
                              value: LearnExplanationLanguage.myanmar,
                              child: Text('Myanmar meanings'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _cover(context),
                  const SizedBox(height: 14),
                  Text(
                    showTitle,
                    textAlign: TextAlign.start,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _fixedInfoRow(
                    level: vLevel,
                    category: vCategory,
                    unlock: vUnlock,
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle(context, "What's inside"),
                  const SizedBox(height: 10),
                  _InsideCard(text: vDesc),
                  const SizedBox(height: 18),
                  _sectionTitle(context, 'Learning'),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount:
                        MediaQuery.sizeOf(context).width >= 600 ? 3 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      for (final t in tiles)
                        _learnCard(
                          context,
                          label: t.$1,
                          icon: t.$2,
                          onTap: t.$1 == 'Vocabulary / Kanji'
                              ? () => context.push(
                                    '/learn/${widget.contentId}/vocabulary',
                                  )
                              : t.$1 == 'Grammar Learn'
                                  ? () => context.push(
                                        '/learn/${widget.contentId}/grammar',
                                      )
                                  : t.$1 == 'Quiz Practice'
                                      ? () => context.push(
                                            '/learn/${widget.contentId}/quiz',
                                          )
                                      : t.$1 == 'Listening / Pronunciation'
                                          ? () {
                                              final lang = ref.read(
                                                learnExplanationLanguageProvider,
                                              );
                                              context.push(
                                                '/learn/${widget.contentId}/listening',
                                                extra: <String, Object?>{
                                                  'storyTitle': showTitle,
                                                  'explanationLanguage':
                                                      LearnExplanationLanguagePrefs
                                                          .encode(lang),
                                                },
                                              );
                                            }
                                          : null,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InsideCard extends StatefulWidget {
  final String text;
  const _InsideCard({required this.text});

  @override
  State<_InsideCard> createState() => _InsideCardState();
}

class _InsideCardState extends State<_InsideCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = widget.text.trim();
    final hasText = t.isNotEmpty;
    final maxLines = _expanded ? 999 : 4;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              hasText ? t : '—',
              maxLines: hasText ? maxLines : 1,
              overflow: hasText && !_expanded ? TextOverflow.ellipsis : null,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: const Color(0xFF1A1917),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (hasText) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    foregroundColor: const Color(0xFF1A1917),
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? 'See less' : 'See more'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
