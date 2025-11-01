import 'package:flutter/material.dart';

class BuildStepIndicator extends StatelessWidget {
  final int currentStep; // 0..4 (count of completed items)
  const BuildStepIndicator({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    // Render exactly 4 dots; filled when (index+1) <= currentStep (1-indexed)
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        // Dots indexed 1..4: dot at index i (0-indexed) is filled when (i+1) <= currentStep
        // Equivalent to: index + 1 <= currentStep, which is index < currentStep
        final isHighlighted = (index + 1) <= currentStep;

        return Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isHighlighted
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            if (index < 3) ...[
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 1,
                color: isHighlighted
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
              ),
              const SizedBox(width: 8),
            ],
          ],
        );
      }),
    );
  }
}

