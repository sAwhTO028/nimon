import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:nimon/data/story_repo.dart';

enum MonoItemType { question, note, sentence, dialogue, hook }

class MonoFeedItem {
  final String id;
  final String writerName;
  final String writerHandle;
  final String level; // All, N5..N1
  final MonoItemType type;
  final String? title;
  final String textContent;
  final String? shortDescription;

  const MonoFeedItem({
    required this.id,
    required this.writerName,
    required this.writerHandle,
    required this.level,
    required this.type,
    required this.textContent,
    this.title,
    this.shortDescription,
  });
}

class MonoScreen extends StatefulWidget {
  final StoryRepo repo;
  const MonoScreen({super.key, required this.repo});

  @override
  State<MonoScreen> createState() => _MonoScreenState();
}

class _MonoScreenState extends State<MonoScreen> {
  static const _levels = <String>['All', 'N5', 'N4', 'N3', 'N2', 'N1'];

  static const _mockItems = <MonoFeedItem>[
    MonoFeedItem(
      id: 'm1',
      writerName: 'Yuki',
      writerHandle: '@yuki',
      level: 'N5',
      type: MonoItemType.sentence,
      title: 'Daily phrase',
      textContent: '今日はいい天気ですね。',
      shortDescription: '“Nice weather today, isn’t it?”',
    ),
    MonoFeedItem(
      id: 'm2',
      writerName: 'Haru',
      writerHandle: '@haru',
      level: 'N5',
      type: MonoItemType.question,
      textContent: '「～です」と「～ます」の違いは？',
      shortDescription: 'Quick reminder: polite forms for nouns/adjectives vs verbs.',
    ),
    MonoFeedItem(
      id: 'm3',
      writerName: 'Mika',
      writerHandle: '@mika',
      level: 'N4',
      type: MonoItemType.note,
      title: 'Small note',
      textContent: '「もう」= already / anymore.\n「まだ」= still / not yet.',
    ),
    MonoFeedItem(
      id: 'm4',
      writerName: 'Ken',
      writerHandle: '@ken',
      level: 'N4',
      type: MonoItemType.dialogue,
      title: 'Mini dialogue',
      textContent:
          'A: 今、時間ある？\nB: ちょっとだけ。\nA: じゃあ、駅まで一緒に行こう。',
    ),
    MonoFeedItem(
      id: 'm5',
      writerName: 'Sora',
      writerHandle: '@sora',
      level: 'N3',
      type: MonoItemType.hook,
      title: 'Story hook',
      textContent: '彼は「大丈夫」と言った。\nでも、その声は震えていた。',
      shortDescription: 'Notice how contrast is created with でも.',
    ),
    MonoFeedItem(
      id: 'm6',
      writerName: 'Aki',
      writerHandle: '@aki',
      level: 'N3',
      type: MonoItemType.question,
      textContent: '「ようにする」ってどういうニュアンス？',
      shortDescription: '“Make a habit of…” / “Try to…” (effort + repetition).',
    ),
    MonoFeedItem(
      id: 'm7',
      writerName: 'Rin',
      writerHandle: '@rin',
      level: 'N2',
      type: MonoItemType.note,
      title: 'Contrast',
      textContent: '「にもかかわらず」= despite / in spite of.',
    ),
    MonoFeedItem(
      id: 'm8',
      writerName: 'Nao',
      writerHandle: '@nao',
      level: 'N1',
      type: MonoItemType.sentence,
      textContent: '彼の言い分は筋が通っているとは言い難い。',
      shortDescription: 'Pattern: 〜とは言い難い (hard to say that…).',
    ),
  ];

  String _selectedLevel = 'All';
  late final PageController _feedController;
  final Set<String> _bookmarkedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _feedController = PageController();
  }

  @override
  void dispose() {
    _feedController.dispose();
    super.dispose();
  }

  List<MonoFeedItem> get _filteredItems {
    if (_selectedLevel == 'All') return _mockItems;
    return _mockItems.where((i) => i.level == _selectedLevel).toList();
  }

  void _openLearn(MonoFeedItem item) {
    // Existing route shape is /learn/:id (Learn screen currently ignores param)
    context.push('/learn/${item.id}');
  }

  Future<void> _share(MonoFeedItem item) async {
    final text = [
      'Nimon Mono',
      '${item.level} • ${_typeLabel(item.type)}',
      '${item.writerName} (${item.writerHandle})',
      if ((item.title ?? '').trim().isNotEmpty) item.title!,
      '',
      item.textContent,
      if ((item.shortDescription ?? '').trim().isNotEmpty) '\n${item.shortDescription}',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _filteredItems;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Feed
            if (items.isEmpty)
              Center(
                child: Text(
                  'No items for $_selectedLevel',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              )
            else
              PageView.builder(
                key: ValueKey(_selectedLevel),
                controller: _feedController,
                scrollDirection: Axis.vertical,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isBookmarked = _bookmarkedIds.contains(item.id);
                  return _MonoFeedPage(
                    item: item,
                    isBookmarked: isBookmarked,
                    onLearn: () => _openLearn(item),
                    onToggleBookmark: () {
                      setState(() {
                        if (isBookmarked) {
                          _bookmarkedIds.remove(item.id);
                        } else {
                          _bookmarkedIds.add(item.id);
                        }
                      });
                    },
                    onShare: () => _share(item),
                  );
                },
              ),

            // Top bar (level filter)
            Positioned(
              left: 16,
              right: 16,
              top: 8,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black.withOpacity(0.08)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLevel,
                        borderRadius: BorderRadius.circular(12),
                        items: [
                          for (final lv in _levels)
                            DropdownMenuItem<String>(
                              value: lv,
                              child: Text(lv),
                            ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _selectedLevel = v);
                        },
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black.withOpacity(0.08)),
                    ),
                    child: Text(
                      'Mono',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonoFeedPage extends StatelessWidget {
  final MonoFeedItem item;
  final bool isBookmarked;
  final VoidCallback onLearn;
  final VoidCallback onToggleBookmark;
  final VoidCallback onShare;

  const _MonoFeedPage({
    required this.item,
    required this.isBookmarked,
    required this.onLearn,
    required this.onToggleBookmark,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // Center card
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 72, 88, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Badge(text: item.level),
                          _Badge(text: _typeLabel(item.type)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${item.writerName}  ${item.writerHandle}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.black.withOpacity(0.70),
                        ),
                      ),
                      if ((item.title ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          item.title!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        item.textContent,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((item.shortDescription ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          item.shortDescription!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.35,
                            color: Colors.black.withOpacity(0.68),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Right actions
        Positioned(
          right: 12,
          top: 0,
          bottom: 0,
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionButton(
                  icon: Icons.school_outlined,
                  label: 'Learn',
                  onTap: onLearn,
                ),
                const SizedBox(height: 14),
                _ActionButton(
                  icon: isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                  label: 'Bookmark',
                  onTap: onToggleBookmark,
                ),
                const SizedBox(height: 14),
                _ActionButton(
                  icon: Icons.ios_share,
                  label: 'Share',
                  onTap: onShare,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.92),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withOpacity(0.08)),
              ),
              child: Icon(icon, size: 22),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 66,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.black.withOpacity(0.70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _typeLabel(MonoItemType type) {
  switch (type) {
    case MonoItemType.question:
      return 'Question';
    case MonoItemType.note:
      return 'Note';
    case MonoItemType.sentence:
      return 'Sentence';
    case MonoItemType.dialogue:
      return 'Dialogue';
    case MonoItemType.hook:
      return 'Hook';
  }
}
