import 'package:flutter/material.dart';

/// --- Duration Accordion Field (replace your Dropdown) ---
class DurationAccordionField extends StatefulWidget {
  final List<String> options;
  final String? initialValue;
  final ValueChanged<String> onChanged;
  final String label;

  const DurationAccordionField({
    super.key,
    required this.options,
    required this.onChanged,
    this.initialValue,
    this.label = 'Duration',
  });

  @override
  State<DurationAccordionField> createState() => _DurationAccordionFieldState();
}

class _DurationAccordionFieldState extends State<DurationAccordionField>
    with TickerProviderStateMixin {
  bool _open = false;
  late String? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  void _select(String v) {
    setState(() {
      _value = v;
      _open = false;
    });
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius,
          border: Border.all(color: const Color(0xFFE6E6E6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header row (tap to expand/collapse)
            InkWell(
              borderRadius: borderRadius,
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() => _open = !_open);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(widget.label,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.grey)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _value ?? 'Select…',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _value == null
                              ? Colors.grey.shade400
                              : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 180),
                      turns: _open ? 0.5 : 0.0,
                      child: const Icon(Icons.expand_more, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            // Accordion content
            if (_open)
              Container(
                padding:
                    const EdgeInsets.only(left: 8, right: 8, bottom: 8, top: 0),
                child: Column(
                  children: [
                    for (final opt in widget.options)
                      _DurationOptionTile(
                        text: opt,
                        selected: _value == opt,
                        onTap: () => _select(opt),
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

class _DurationOptionTile extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _DurationOptionTile({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected ? Theme.of(context).colorScheme.primary.withOpacity(0.08) : Colors.white,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.timer_outlined,
                    size: 18,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black87,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

