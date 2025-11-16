import 'package:flutter/material.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;

  const StepIndicator({
    super.key,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final step = index + 1;
          final isActive = step == currentStep;
          final isCompleted = step < currentStep;

          return Row(
            children: [
              Container(
                width: isActive ? 10 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive || isCompleted ? Colors.blue : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(isActive ? 3 : 3),
                ),
              ),
              if (index < 3) ...[
                const SizedBox(width: 8),
                Container(
                  width: 20,
                  height: 1,
                  color: isCompleted ? Colors.blue : Colors.grey.shade300,
                ),
                const SizedBox(width: 8),
              ],
            ],
          );
        }),
      ),
    );
  }
}





