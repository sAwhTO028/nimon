import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'one_short_tab.dart';
import 'widgets/header_sheet.dart';
import 'mono_draft_v1.dart';

enum CreationType { oneShort, storySeries, promptEpisode }

class CreateMonoState {
  final CreationType type;
  final OneShortState oneShortState;
  final List<MonoDraftV1> drafts;

  const CreateMonoState({
    this.type = CreationType.oneShort,
    this.oneShortState = const OneShortState(),
    this.drafts = const [],
  });

  CreateMonoState copyWith({
    CreationType? type,
    OneShortState? oneShortState,
    List<MonoDraftV1>? drafts,
  }) {
    return CreateMonoState(
      type: type ?? this.type,
      oneShortState: oneShortState ?? this.oneShortState,
      drafts: drafts ?? this.drafts,
    );
  }
}

class CreateMonoNotifier extends StateNotifier<CreateMonoState> {
  CreateMonoNotifier() : super(const CreateMonoState());

  void setType(CreationType type) {
    state = state.copyWith(type: type);
  }

  void updateOneShortState(OneShortState oneShortState) {
    state = state.copyWith(oneShortState: oneShortState);
  }

  void saveOneShortDraft() {
    final s = state.oneShortState;
    final id = 'draft_one_short';
    final content = s.toMonoContent(id: id);
    final legacy = s.toLegacyBodyText();
    final title = s.title.trim();
    final jlpt = s.jlpt.trim();

    final draft = MonoDraftV1(
      id: id,
      title: title.isEmpty ? 'Untitled' : title,
      jlptLevel: jlpt.isEmpty ? 'N5' : jlpt,
      content: content,
      legacyBodyText: legacy,
      updatedAt: DateTime.now(),
      published: false,
    );

    final next = [...state.drafts];
    final idx = next.indexWhere((d) => d.id == id);
    if (idx >= 0) {
      next[idx] = draft;
    } else {
      next.insert(0, draft);
    }
    state = state.copyWith(drafts: next);
  }

  /// V1 publish validation: title + jlpt + at least one Japanese line.
  /// Explanations and furigana are optional.
  bool canPublishOneShort() {
    final s = state.oneShortState;
    if (s.title.trim().isEmpty) return false;
    if (s.jlpt.trim().isEmpty) return false;
    if (!s.hasAtLeastOneLine) return false;
    return true;
  }

  /// Publish: store a published snapshot in drafts list (V1).
  void publishOneShort() {
    final s = state.oneShortState;
    final id = 'published_one_short';
    final content = s.toMonoContent(id: id);
    final legacy = s.toLegacyBodyText();
    final draft = MonoDraftV1(
      id: id,
      title: s.title.trim(),
      jlptLevel: s.jlpt.trim(),
      content: content,
      legacyBodyText: legacy,
      updatedAt: DateTime.now(),
      published: true,
    );
    state = state.copyWith(drafts: [draft, ...state.drafts]);
  }
}

final createMonoProvider = StateNotifierProvider<CreateMonoNotifier, CreateMonoState>((ref) {
  return CreateMonoNotifier();
});

class CreateMonoScreen extends ConsumerWidget {
  const CreateMonoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createMonoProvider);
    final notifier = ref.read(createMonoProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              HeaderSheet(
                type: state.type,
                canPublish: notifier.canPublishOneShort(),
                onSaveDraft: () {
                  notifier.saveOneShortDraft();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All changes saved locally.')),
                  );
                },
                onPublish: () {
                  if (!notifier.canPublishOneShort()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Add title, level, and at least 1 line'),
                      ),
                    );
                    return;
                  }
                  notifier.publishOneShort();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Published (V1 mock)')),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildContent(state, notifier),
              const SizedBox(height: 16),
              _buildBottomTabs(state, notifier),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(CreateMonoState state, CreateMonoNotifier notifier) {
    switch (state.type) {
      case CreationType.oneShort:
        return OneShortTab(
          state: state.oneShortState,
          onStateChanged: (newState) => notifier.updateOneShortState(newState),
        );
      case CreationType.storySeries:
        return _buildPlaceholder('Story-Series (coming next)');
      case CreationType.promptEpisode:
        return _buildPlaceholder('Prompt-Episode (coming next)');
    }
  }

  Widget _buildPlaceholder(String text) {
    return Container(
      height: 400,
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
      child: Center(
        child: Text(
          'Coming soon',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomTabs(CreateMonoState state, CreateMonoNotifier notifier) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
      child: Row(
        children: [
          Expanded(
            child: _buildTab(
              'One-Short',
              CreationType.oneShort,
              state.type == CreationType.oneShort,
              () => notifier.setType(CreationType.oneShort),
            ),
          ),
          Expanded(
            child: _buildTab(
              'Story-Series',
              CreationType.storySeries,
              state.type == CreationType.storySeries,
              () => notifier.setType(CreationType.storySeries),
            ),
          ),
          Expanded(
            child: _buildTab(
              'Prompt-Episode',
              CreationType.promptEpisode,
              state.type == CreationType.promptEpisode,
              () => notifier.setType(CreationType.promptEpisode),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, CreationType type, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Publish/save is handled via [CreateMonoNotifier] (V1 lightweight).
}