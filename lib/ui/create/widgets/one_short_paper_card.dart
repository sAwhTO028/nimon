// lib/ui/create/one_short_paper_view.dart
import 'package:flutter/material.dart';

// ===== CJK and Locale Helpers =====
bool isCJK(Locale? l) =>
  l != null && const ['ja','zh','ko'].contains(l.languageCode);

int maxContextLines(BuildContext c, {Locale? locale}) {
  final w = MediaQuery.sizeOf(c).width;
  final cjk = isCJK(locale);
  // smaller screens: fewer lines; CJK can show 1 extra line comfortably
  if (w < 360) return cjk ? 5 : 4;
  if (w < 420) return cjk ? 6 : 5;
  return cjk ? 7 : 6;
}

TextStyle bodyStyle(BuildContext c, {bool dim=false}) {
  final cjk = isCJK(Localizations.maybeLocaleOf(c));
  return TextStyle(
    fontSize: cjk ? 12.5 : 12.5,
    height: cjk ? 1.5 : 1.35,     // better readability for CJK
    color: dim ? Colors.black54 : Colors.black87,
    fontFamilyFallback: const [
      'Noto Sans CJK JP', 'Noto Sans CJK KR', 'Noto Sans CJK SC',
      'Noto Sans JP', 'Noto Sans KR', 'Noto Sans SC', 'Noto Sans',
      'Roboto'
    ],
  );
}

Widget fadingClampedText(
  BuildContext c, {
  required String text,
  required int maxLines,
  required TextStyle style,
}) {
  final bg = Theme.of(c).cardColor; // Use card background color
  return ClipRRect(
    borderRadius: BorderRadius.zero,
    clipBehavior: Clip.hardEdge,
    child: Stack(
      children: [
        Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          style: style.copyWith(
            decoration: TextDecoration.none, // Avoid underline artifacts
          ),
        ),
        Positioned(
          left: 0, right: 0, bottom: 0, height: 20,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(0, 0.2),
                  end: Alignment.bottomCenter,
                  colors: [
                    bg.withOpacity(0.0), // transparent fade start
                    bg,                  // blend into card background
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class ExpandableText extends StatefulWidget {
  final String text;
  final int trimLines;
  final TextStyle? style;
  const ExpandableText(this.text,{super.key,this.trimLines=6,this.style});
  @override State<ExpandableText> createState()=>_ExpandableTextState();
}
class _ExpandableTextState extends State<ExpandableText> {
  bool expanded=false;
  @override Widget build(BuildContext context){
    final txt = Text(
      widget.text,
      softWrap: true,
      style: widget.style,
      maxLines: expanded ? null : widget.trimLines,
      overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:[
        txt,
        const SizedBox(height: 6),
        GestureDetector(
          onTap: ()=>setState(()=>expanded=!expanded),
          child: Text(
            expanded ? 'Show less' : 'Read more',
            style: const TextStyle(
              color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class OneShortPaper {
  final String jlpt; // Empty string if not selected
  final String title; // Empty string if not entered
  final String theme; // Empty string if prompt not selected
  final String context; // Empty string if prompt not selected
  final String category; // Empty string if not selected
  final String durationText; // Empty string if prompt not selected

  OneShortPaper({
    required this.jlpt,
    required this.title,
    required this.theme,
    required this.context,
    required this.category,
    required this.durationText,
  });
}

String assetForCategory(String cat) {
  final key = cat.trim().toLowerCase();
  const base = 'assets/images/one_short';
  switch (key) {
    case 'love':
      return '$base/love.jpg';
    case 'comedy':
      return '$base/comedy.jpg';
    case 'horror':
      return '$base/horror.jpg';
    case 'cultural':
      return '$base/cultural.jpg';
    case 'adventure':
      return '$base/adventure.jpg';
    case 'business':
      return '$base/business.jpg';
    case 'drama':
      return '$base/drama.jpg';
    case 'fantasy':
      return '$base/fantasy.jpg';
    case 'mystery_detective':
      return '$base/mystery_detective.jpg';
    case 'scifi_technology':
      return '$base/scifi_technology.jpg';
    default:
      return '$base/love.jpg';
  }
}

class OneShortPaperCard extends StatelessWidget {
  final OneShortPaper data;
  const OneShortPaperCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    const inset = 6.0;
    const pad = 16.0;
    final hasCategory = data.category.isNotEmpty;
    final imgPath = hasCategory ? assetForCategory(data.category) : 'assets/images/one_short/love.jpg';

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Material(
        color: Colors.white,
        elevation: 8,
        shadowColor: const Color(0x26000000),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showBottomSheet(context),
          child: Stack(
            children: [
              // Card content
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(pad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Image - only show if category selected
                      if (hasCategory) ...[
                        SizedBox(
                          height: 68,
                          width: 68,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              imgPath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image,
                                color: Colors.black26,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ] else ...[
                        const SizedBox(height: 20),
                      ],
                      // Title - show placeholder if empty
                      Text(
                        data.title.isEmpty ? 'Enter title...' : data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: data.title.isEmpty ? Colors.grey.shade400 : Colors.black87,
                          fontStyle: data.title.isEmpty ? FontStyle.italic : FontStyle.normal,
                          fontFamilyFallback: const [
                            'Noto Sans CJK JP', 'Noto Sans CJK KR', 'Noto Sans CJK SC',
                            'Noto Sans JP', 'Noto Sans KR', 'Noto Sans SC', 'Noto Sans',
                            'Roboto'
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Theme - only show if prompt selected
                      if (data.theme.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            data.theme,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFEE6565),
                              fontFamilyFallback: const [
                                'Noto Sans CJK JP', 'Noto Sans CJK KR', 'Noto Sans CJK SC',
                                'Noto Sans JP', 'Noto Sans KR', 'Noto Sans SC', 'Noto Sans',
                                'Roboto'
                              ],
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 0),
                      const SizedBox(height: 6),
                      // Context - only show if prompt selected
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: data.context.isEmpty
                              ? Text(
                                  'Select a prompt to see context...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              : fadingClampedText(
                                  context,
                                  text: data.context,
                                  maxLines: maxContextLines(context, locale: Localizations.maybeLocaleOf(context)),
                                  style: bodyStyle(context),
                                ),
                        ),
                      ),
                      // Duration - only show if prompt selected
                      if (data.durationText.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  data.durationText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: const Text(
                          'One-Short paper',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // JLPT Pill - locked to true top-right (only show if jlpt is not empty)
              if (data.jlpt.isNotEmpty)
                Positioned(
                  top: 6, right: 6,  // DO NOT wrap by outer padding
                  child: Container(
                    height: 24,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F1F4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      data.jlpt,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBottomSheet(BuildContext context) {
    // Guard: Don't show preview if no prompt/level/category is selected
    final hasLevel = data.jlpt.isNotEmpty;
    final hasCategory = data.category.isNotEmpty;
    final hasPrompt = data.theme.isNotEmpty && data.context.isNotEmpty;
    
    if (!hasLevel || !hasCategory || !hasPrompt) {
      // Show helpful bottom sheet with navigation actions
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Complete your selection',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Please select Level, Category, and Prompt first.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!hasLevel)
                    _buildActionButton(
                      ctx,
                      'Go to Level',
                      Icons.trending_up,
                      () => Navigator.pop(ctx),
                    ),
                  if (!hasCategory && hasLevel)
                    _buildActionButton(
                      ctx,
                      'Go to Category',
                      Icons.category,
                      () => Navigator.pop(ctx),
                    ),
                  if (!hasPrompt && hasLevel && hasCategory)
                    _buildActionButton(
                      ctx,
                      'Go to Prompt',
                      Icons.auto_stories,
                      () => Navigator.pop(ctx),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    final img = assetForCategory(data.category);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Theme + JLPT
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.theme,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFEE6565),
                          fontFamilyFallback: const [
                            'Noto Sans CJK JP', 'Noto Sans CJK KR', 'Noto Sans CJK SC',
                            'Noto Sans JP', 'Noto Sans KR', 'Noto Sans SC', 'Noto Sans',
                            'Roboto'
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F1F4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        data.jlpt,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Text(
                  data.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamilyFallback: const [
                      'Noto Sans CJK JP', 'Noto Sans CJK KR', 'Noto Sans CJK SC',
                      'Noto Sans JP', 'Noto Sans KR', 'Noto Sans SC', 'Noto Sans',
                      'Roboto'
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        img,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image,
                          size: 40,
                          color: Colors.black26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SingleChildScrollView( // always safe for very long texts
                        child: ExpandableText(
                          data.context,
                          trimLines: isCJK(Localizations.maybeLocaleOf(context)) ? 8 : 6,
                          style: bodyStyle(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 18,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Duration: ${data.durationText}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildActionButton(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}
