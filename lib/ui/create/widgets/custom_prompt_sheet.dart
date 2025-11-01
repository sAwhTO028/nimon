import 'package:flutter/material.dart';
import '../../../data/prompt_repository.dart';

class CustomPromptSheet extends StatefulWidget {
  final JlptLevel level;
  final String category;

  const CustomPromptSheet({
    super.key,
    required this.level,
    required this.category,
  });

  @override
  State<CustomPromptSheet> createState() => _CustomPromptSheetState();
}

class _CustomPromptSheetState extends State<CustomPromptSheet> {
  final _titleController = TextEditingController();
  final _contextController = TextEditingController();
  final _durationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Set default duration based on level
    _durationController.text = PromptRepository.durationStringFor(widget.level);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contextController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  bool _isValid() {
    final title = _titleController.text.trim();
    final context = _contextController.text.trim();
    final duration = _durationController.text.trim();

    return title.length >= 3 &&
        title.length <= 60 &&
        context.length >= 3 &&
        duration.isNotEmpty;
  }

  void _onSave() {
    if (!_formKey.currentState!.validate() || !_isValid()) {
      return;
    }

    final prompt = Prompt(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim().toUpperCase(),
      context: _contextController.text.trim(),
      duration: _durationController.text.trim(),
      category: widget.category,
      level: widget.level,
    );

    Navigator.pop(context, prompt);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add Custom Prompt',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Form fields
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Duration FIRST
                    TextFormField(
                      controller: _durationController,
                      decoration: const InputDecoration(
                        labelText: 'Duration',
                        hintText: 'e.g., 4–6 minutes',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) {
                          return 'Duration is required';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    // Title SECOND
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'Enter prompt title (3-60 characters)',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 60,
                      autofocus: true,
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.length < 3) {
                          return 'Title must be at least 3 characters';
                        }
                        if (v.length > 60) {
                          return 'Title must not exceed 60 characters';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    // Context THIRD
                    TextFormField(
                      controller: _contextController,
                      decoration: const InputDecoration(
                        labelText: 'Description/Context',
                        hintText: 'Enter story context (3+ characters)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 6,
                      maxLength: 300,
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.length < 3) {
                          return 'Context must be at least 3 characters';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              // Buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isValid() ? _onSave : null,
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

