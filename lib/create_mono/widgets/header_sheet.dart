import 'package:flutter/material.dart';
import '../create_mono_screen.dart';

class HeaderSheet extends StatelessWidget {
  final CreationType type;
  final bool canCreate;
  final VoidCallback onCreate;

  const HeaderSheet({
    super.key,
    required this.type,
    required this.canCreate,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E6E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pill handle (3 short bars)
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Title and CREATE button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTitle(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Please select you want to create section',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                height: 40,
                child: FilledButton(
                  onPressed: canCreate ? onCreate : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: canCreate ? Colors.blue : Colors.grey.shade300,
                    foregroundColor: canCreate ? Colors.white : Colors.grey.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'CREATE',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (type) {
      case CreationType.oneShort:
        return 'Add One-Short';
      case CreationType.storySeries:
        return 'Add Story-Series';
      case CreationType.promptEpisode:
        return 'Add Prompt-Episode';
    }
  }
}