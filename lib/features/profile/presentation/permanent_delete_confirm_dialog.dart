import 'package:flutter/material.dart';

/// Second confirmation for permanent delete: requires typing `DELETE`.
class PermanentDeleteTypedConfirmDialog extends StatefulWidget {
  const PermanentDeleteTypedConfirmDialog({super.key});

  @override
  State<PermanentDeleteTypedConfirmDialog> createState() =>
      _PermanentDeleteTypedConfirmDialogState();
}

class _PermanentDeleteTypedConfirmDialogState
    extends State<PermanentDeleteTypedConfirmDialog> {
  final TextEditingController _controller = TextEditingController();

  bool get _ok => _controller.text.trim() == 'DELETE';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Are you absolutely sure?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('This cannot be undone.'),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('permanentDeleteTypeField'),
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Type DELETE to confirm',
            ),
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('permanentDeleteFinalConfirm'),
          onPressed: _ok ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: const Text('Permanently delete'),
        ),
      ],
    );
  }
}
