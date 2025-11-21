import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/data/story_repo.dart';
import 'package:nimon/models/story.dart';
import 'package:nimon/ui/ui.dart';

/// Tab enum for profile content types
enum ProfileTab { oneShort, storySeries, aiStories }

/// Profile state model
class ProfileState {
  final int uploadedCount;
  final int processingCount;
  final ProfileTab activeTab;

  const ProfileState({
    this.uploadedCount = 0,
    this.processingCount = 0,
    this.activeTab = ProfileTab.oneShort,
  });

  ProfileState copyWith({
    int? uploadedCount,
    int? processingCount,
    ProfileTab? activeTab,
  }) =>
      ProfileState(
        uploadedCount: uploadedCount ?? this.uploadedCount,
        processingCount: processingCount ?? this.processingCount,
        activeTab: activeTab ?? this.activeTab,
      );
}

class ProfileScreen extends StatefulWidget {
  final StoryRepo repo;
  const ProfileScreen({super.key, required this.repo});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late ProfileState _state;
  late Future<List<Story>> _storiesFuture;
  late PageController _pageController;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _state = const ProfileState();
    _storiesFuture = widget.repo.getStories();
    _pageController = PageController();
    _tabController = TabController(length: 2, vsync: this);

    // Sync TabController with PageController when tab is tapped
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // Only sync when tab change is complete (not during animation)
    if (!_tabController.indexIsChanging && _tabController.index != _pageController.page?.round()) {
      _pageController.animateToPage(
        _tabController.index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleTabChanged(ProfileTab tab) {
    setState(() {
      _state = _state.copyWith(activeTab: tab);
    });
  }

  void _handleEditProfile() {
    // TODO: Navigate to edit profile screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit Profile - Coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Calculate bottom padding: nav bar height + device safe area + extra spacing
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const double bottomNavHeight = 64.0; // Navigation bar height
    const double extraBottomPadding = 40.0; // Extra spacing to prevent overflow

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false, // Handle padding manually to account for nav bar
        child: Column(
          children: [
            _ProfileHeader(
              state: _state,
              onEditProfile: _handleEditProfile,
            ),
            _ProfileStatusRow(state: _state),
            _ProfileTabBar(controller: _tabController),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  // Sync TabController when page is swiped
                  if (_tabController.index != index) {
                    _tabController.animateTo(index);
                  }
                },
                children: [
                  _Page1Content(
                    state: _state,
                    onTabChanged: _handleTabChanged,
                    storiesFuture: _storiesFuture,
                    bottomPadding: bottomNavHeight + bottomPadding + extraBottomPadding,
                  ),
                  _Page2Placeholder(
                    bottomPadding: bottomNavHeight + bottomPadding + extraBottomPadding,
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

/// Profile header widget
class _ProfileHeader extends StatelessWidget {
  final ProfileState state;
  final VoidCallback onEditProfile;

  const _ProfileHeader({
    required this.state,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile image
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.grey.shade200,
            child: Icon(
              Icons.person,
              size: 32,
              color: Colors.grey.shade600,
            ),
            // TODO: Replace with actual profile image
            // backgroundImage: AssetImage('assets/images/demo_profile.png'),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Just4withYou', // TODO: bind real writer name
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@just4withyou', // placeholder handle
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatChip(label: 'Following', value: '0'),
                    const SizedBox(width: 12),
                    _StatChip(label: 'Followers', value: '0'),
                    const SizedBox(width: 12),
                    _StatChip(label: 'Stories', value: '0'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onEditProfile,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Edit Profile'),
          ),
        ],
      ),
    );
  }
}

/// Stat chip widget for follower/following/stories count
class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.black.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

/// Status row with Uploaded/Processing buttons
class _ProfileStatusRow extends StatelessWidget {
  final ProfileState state;

  const _ProfileStatusRow({required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _StatusCard(
              icon: Icons.cloud_done_rounded,
              label: 'Uploaded',
              value: state.uploadedCount.toString(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatusCard(
              icon: Icons.schedule_rounded,
              label: 'Processing',
              value: state.processingCount.toString(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab bar for Uploaded/Processing tabs
class _ProfileTabBar extends StatelessWidget {
  final TabController controller;

  const _ProfileTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TabBar(
        controller: controller,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: primaryColor, width: 2),
          insets: const EdgeInsets.symmetric(horizontal: 16),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: primaryColor,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_done_rounded,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text('Uploaded'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text('Processing'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Status card widget
class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatusCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 88,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Page 1 content with segmented control and story list
class _Page1Content extends StatelessWidget {
  final ProfileState state;
  final ValueChanged<ProfileTab> onTabChanged;
  final Future<List<Story>> storiesFuture;
  final double bottomPadding;

  const _Page1Content({
    required this.state,
    required this.onTabChanged,
    required this.storiesFuture,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: double.infinity,
      child: Column(
        children: [
          _ProfileFilterSegmentedControl(
            selected: state.activeTab,
            onChanged: onTabChanged,
          ),
          Expanded(
            child: FutureBuilder<List<Story>>(
              future: storiesFuture,
              builder: (context, snapshot) {
                final stories = snapshot.data ?? const <Story>[];
                return _ProfileStoryList(
                  activeTab: state.activeTab,
                  stories: stories,
                  bottomPadding: bottomPadding,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Page 2 placeholder
class _Page2Placeholder extends StatelessWidget {
  final double bottomPadding;

  const _Page2Placeholder({
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: double.infinity,
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Text(
            'Page 2 - Coming Soon',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ),
      ),
    );
  }
}

/// Segmented control widget for profile filter (Page 1 only)
class _ProfileFilterSegmentedControl extends StatelessWidget {
  final ProfileTab selected;
  final ValueChanged<ProfileTab> onChanged;

  const _ProfileFilterSegmentedControl({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTypeChip(
            label: 'One-Short',
            isSelected: selected == ProfileTab.oneShort,
            onTap: () => onChanged(ProfileTab.oneShort),
            primaryColor: primaryColor,
          ),
          const SizedBox(width: 8),
          _buildTypeChip(
            label: 'Story-Series',
            isSelected: selected == ProfileTab.storySeries,
            onTap: () => onChanged(ProfileTab.storySeries),
            primaryColor: primaryColor,
          ),
          const SizedBox(width: 8),
          _buildTypeChip(
            label: 'AI-Stories',
            isSelected: selected == ProfileTab.aiStories,
            onTap: () => onChanged(ProfileTab.aiStories),
            primaryColor: primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color primaryColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Story list widget
class _ProfileStoryList extends StatelessWidget {
  final ProfileTab activeTab;
  final List<Story> stories;
  final double bottomPadding;

  const _ProfileStoryList({
    required this.activeTab,
    required this.stories,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: Filter stories by activeTab when backend supports it
    final filteredStories = stories.take(30).toList();

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        bottomPadding,
      ),
      itemCount: filteredStories.length,
      itemBuilder: (context, index) {
        final story = filteredStories[index];
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
          child: _ProfileStoryCard(story: story),
        );
      },
    );
  }
}

/// Story card widget (reusing existing design)
class _ProfileStoryCard extends StatelessWidget {
  final Story story;

  const _ProfileStoryCard({required this.story});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: story.coverUrl != null
                  ? Image.network(
                      story.coverUrl!,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                    )
                  : _buildPlaceholderImage(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title,
                    style: theme.textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Description overall……',
                    maxLines: 1,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Episode – 0${(story.likes % 9) + 1}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Chip(
                  label: Text(story.jlptLevel),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                const SizedBox(height: 8),
                Icon(
                  Icons.edit_note,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 88,
      height: 88,
      color: Colors.grey.shade200,
      child: Icon(
        Icons.image_outlined,
        size: 32,
        color: Colors.grey.shade400,
      ),
    );
  }
}

