import 'package:flutter/material.dart';

class HorizontalSection<T> extends StatelessWidget {
  const HorizontalSection({
    super.key,
    required this.title,
    required this.items,
    required this.itemBuilder,
    required this.onTap,
    this.itemExtent,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.gap = 12,
    this.trailing,
  });

  final String title;
  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  final void Function(T) onTap;
  final double? itemExtent; // height of the row
  final EdgeInsets padding;
  final double gap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowHeight = itemExtent ?? 220;

    return Padding(
      padding: padding.copyWith(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + optional trailing (e.g., See all)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          SizedBox(
            height: rowHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, __) => SizedBox(width: gap),
              itemBuilder: (context, index) {
                final item = items[index];
                return InkWell(
                  onTap: () => onTap(item),
                  borderRadius: BorderRadius.circular(12),
                  child: itemBuilder(context, item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
