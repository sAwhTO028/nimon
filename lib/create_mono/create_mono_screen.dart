import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'one_short_tab.dart';
import 'widgets/header_sheet.dart';

enum CreationType { oneShort, storySeries, promptEpisode }

class CreateMonoState {
  final CreationType type;
  final OneShortState oneShortState;

  const CreateMonoState({
    this.type = CreationType.oneShort,
    this.oneShortState = const OneShortState(),
  });

  CreateMonoState copyWith({
    CreationType? type,
    OneShortState? oneShortState,
  }) {
    return CreateMonoState(
      type: type ?? this.type,
      oneShortState: oneShortState ?? this.oneShortState,
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
                canCreate: _canCreate(state),
                onCreate: () => _handleCreate(context, state),
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

  bool _canCreate(CreateMonoState state) {
    switch (state.type) {
      case CreationType.oneShort:
        return state.oneShortState.isComplete;
      case CreationType.storySeries:
      case CreationType.promptEpisode:
        return false;
    }
  }

  void _handleCreate(BuildContext context, CreateMonoState state) {
    switch (state.type) {
      case CreationType.oneShort:
        final payload = {
          'jlpt': state.oneShortState.jlpt,
          'category': state.oneShortState.category,
          'promptId': state.oneShortState.promptId,
          'title': state.oneShortState.title,
        };
        print('One-Short payload: $payload');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Created One-Short!')),
        );
        break;
      case CreationType.storySeries:
      case CreationType.promptEpisode:
        break;
    }
  }
}