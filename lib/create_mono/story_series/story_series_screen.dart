import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/category_chips_selector.dart';

/// Data model for joined story series
class StorySeriesData {
  final String level;
  final String seriesTitle;
  final String episodeTitle;
  final int currentEp;
  final String description;
  final String category;

  const StorySeriesData({
    required this.level,
    required this.seriesTitle,
    required this.episodeTitle,
    required this.currentEp,
    required this.description,
    required this.category,
  });
}

/// Join search state enum
enum JoinSearchState { initial, valid, invalid }

/// Shared constant for smart card border radius (matches One-Short prompt cards)
final BorderRadius kSmartCardRadius = BorderRadius.circular(16);

/// Fixed height constant for Story-Series smart cards
const double kStorySeriesCardHeight = 180.0;

/// Shared horizontal padding constant for card content alignment
const double kCardHorizontalPadding = 20.0;

/// Premium Material-style Smart Card widget for Story Series carousel
class StorySeriesSmartCard extends StatelessWidget {
  final String modeLabel;
  final String level;
  final String seriesTitle;
  final String episodeTitle;
  final String description;
  final String category;
  final bool isActive;
  final XFile? coverImage;
  final VoidCallback? onTapCover;

  const StorySeriesSmartCard({
    super.key,
    required this.modeLabel,
    required this.level,
    required this.seriesTitle,
    required this.episodeTitle,
    required this.description,
    required this.category,
    this.isActive = false,
    this.coverImage,
    this.onTapCover,
  });

  Widget _buildCover() {
    final hasImage = coverImage != null;
    return SizedBox(
      width: 72,
      height: 96,
      child: ClipRRect(
        borderRadius: kSmartCardRadius,
        child: hasImage
            ? Image(
                image: FileImage(File(coverImage!.path)),
                fit: BoxFit.cover,
              )
            : _buildAddCoverPlaceholder(),
      ),
    );
  }

  Widget _buildAddCoverPlaceholder() {
    return InkWell(
      onTap: onTapCover,
      child: Container(
        width: 72,
        height: 96,
        color: Colors.grey.shade100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 28,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 6),
            Text(
              'Add Cover',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelChip(String levelLabel, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        levelLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String categoryLabel, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        categoryLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    
    return Container(
      height: kStorySeriesCardHeight,
      child: AnimatedScale(
        scale: isActive ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: kSmartCardRadius),
          elevation: isActive ? 4 : 1,
          shadowColor: Colors.black.withOpacity(isActive ? 0.12 : 0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: kSmartCardRadius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primaryColor.withOpacity(0.05),
                  Colors.white,
                ],
              ),
              border: Border.all(
                color: isActive
                    ? primaryColor.withOpacity(0.2)
                    : Colors.black.withOpacity(0.04),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Stack(
                children: [
                  // Cover image: left side, vertically centered
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildCover(),
                  ),
                  // Level chip: top-right
                  Align(
                    alignment: Alignment.topRight,
                    child: _buildLevelChip(level, primaryColor),
                  ),
                  // Category pill: bottom-right
                  Align(
                    alignment: Alignment.bottomRight,
                    child: _buildCategoryChip(category, theme),
                  ),
                  // Text block: center-left, shifted to the right of the cover image
                  Positioned.fill(
                    left: 120, // enough to clear the cover image width (72) + spacing (12) + extra margin
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // small label: "New Series" or "Join by Story Code"
                        Text(
                          modeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.black.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // main title
                        Text(
                          seriesTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // subtitle (episode title)
                        Text(
                          episodeTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.black.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // description / helper text
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.black.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Story Series Screen with Smart Card carousel and dynamic forms
class StorySeriesScreen extends StatefulWidget {
  const StorySeriesScreen({super.key});

  @override
  State<StorySeriesScreen> createState() => StorySeriesScreenState();
}

class StorySeriesScreenState extends State<StorySeriesScreen> {
  // Carousel state
  int activeCardIndex = 0; // 0 = New Series, 1 = Join by Code
  late final PageController _cardPageController;

  // Form controllers and state for Create New (Mode 0)
  final TextEditingController _seriesTitleController = TextEditingController();
  final TextEditingController _passCodeController = TextEditingController();
  final TextEditingController _episodeTitleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedLevel = 'N4';
  String? _selectedCategory;
  XFile? _newSeriesCover;
  bool _hasUserInteracted = false;

  // Form controllers and state for Join by Code (Mode 1)
  final TextEditingController _storyCodeController = TextEditingController();
  final TextEditingController _joinPassCodeController = TextEditingController();
  final TextEditingController _joinEpisodeTitleController =
      TextEditingController();
  final TextEditingController _joinDescriptionController =
      TextEditingController();

  // Join mode state
  JoinSearchState _joinSearchState = JoinSearchState.initial;
  bool _showJoinFields = false;
  bool _passcodeVisible = false;
  final GlobalKey _storyCodeFieldKey = GlobalKey();

  // Joined series data (from search)
  StorySeriesData? joinedSeries;

  static const List<String> _jlptLevels = ['N5', 'N4', 'N3', 'N2', 'N1'];
  // Match One-Short categories exactly
  static const List<String> _categories = [
    'Love',
    'Comedy',
    'Horror',
    'Cultural',
    'Adventure',
    'Fantasy',
    'Drama',
    'Business',
    'Sci-Fi',
    'Mystery'
  ];

  @override
  void initState() {
    super.initState();
    _cardPageController = PageController();

    // Listen to form changes for live Smart Card updates
    _seriesTitleController.addListener(_updateNewSeriesCard);
    _episodeTitleController.addListener(_updateNewSeriesCard);
    _descriptionController.addListener(_updateNewSeriesCard);
  }

  @override
  void dispose() {
    _cardPageController.dispose();
    _seriesTitleController.dispose();
    _passCodeController.dispose();
    _episodeTitleController.dispose();
    _descriptionController.dispose();
    _storyCodeController.dispose();
    _joinPassCodeController.dispose();
    _joinEpisodeTitleController.dispose();
    _joinDescriptionController.dispose();
    super.dispose();
  }

  void _onCardPageChanged(int index) {
    setState(() {
      activeCardIndex = index;
      // Reset join state when switching to New Series tab
      if (index == 0) {
        _joinSearchState = JoinSearchState.initial;
        _showJoinFields = false;
        joinedSeries = null;
      }
    });
  }

  void _updateNewSeriesCard() {
    if (activeCardIndex == 0) {
      if (!_hasUserInteracted) {
        setState(() {
          _hasUserInteracted = true;
        });
      } else {
        setState(() {}); // Rebuild to update Smart Card
      }
    }
  }

  void _onLevelChanged(String level) {
    setState(() {
      _selectedLevel = level;
      _hasUserInteracted = true;
    });
  }

  void _onCategoryChanged(String? category) {
    setState(() {
      _selectedCategory = category;
      _hasUserInteracted = true;
    });
  }

  Future<void> _pickNewSeriesCover() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      setState(() {
        _newSeriesCover = result;
        _hasUserInteracted = true;
      });
    }
  }

  Future<void> _searchStoryCode() async {
    final code = _storyCodeController.text.trim();
    if (code.isEmpty) return;

    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    setState(() {
      if (code == '123') {
        // Valid demo code
        _joinSearchState = JoinSearchState.valid;
        _showJoinFields = true;
        // Demo data for Smart Card
        joinedSeries = StorySeriesData(
          level: 'N4',
          seriesTitle: 'Sample Series Title',
          episodeTitle: 'Episode 1',
          currentEp: 1,
          description:
              'This is a demo story series generated from the provided code.',
          category: 'Demo',
        );
      } else {
        // Invalid code
        _joinSearchState = JoinSearchState.invalid;
        _showJoinFields = false;
        joinedSeries = null;
        // Trigger shake animation
        _triggerShakeAnimation();
      }
    });
  }

  void _triggerShakeAnimation() {
    // Shake animation will be handled in the widget
  }

  // Check if New Series is in empty state
  bool get _isNewSeriesEmptyState {
    return !_hasUserInteracted &&
        _selectedCategory == null &&
        _seriesTitleController.text.isEmpty &&
        _episodeTitleController.text.isEmpty &&
        _descriptionController.text.isEmpty;
  }

  // Join mode Smart Card content getters
  String _getJoinCardTitle() {
    switch (_joinSearchState) {
      case JoinSearchState.initial:
        return 'Enter Story Code';
      case JoinSearchState.valid:
        return joinedSeries?.seriesTitle ?? 'Sample Series Title';
      case JoinSearchState.invalid:
        return 'Story not found';
    }
  }

  String _getJoinCardEpisodeTitle() {
    switch (_joinSearchState) {
      case JoinSearchState.initial:
        return '';
      case JoinSearchState.valid:
        return joinedSeries?.episodeTitle ?? 'Episode 1';
      case JoinSearchState.invalid:
        return '';
    }
  }

  String _getJoinCardDescription() {
    switch (_joinSearchState) {
      case JoinSearchState.initial:
        return 'Search a series by its code and we will show details here.';
      case JoinSearchState.valid:
        return joinedSeries?.description ?? 'Demo story description.';
      case JoinSearchState.invalid:
        return 'Invalid Story Code. Please try again.';
    }
  }

  String _getJoinCardLevel() {
    switch (_joinSearchState) {
      case JoinSearchState.initial:
        return '–';
      case JoinSearchState.valid:
        return joinedSeries?.level ?? 'N4';
      case JoinSearchState.invalid:
        return '–';
    }
  }

  String _getJoinCardCategory() {
    switch (_joinSearchState) {
      case JoinSearchState.initial:
        return '–';
      case JoinSearchState.valid:
        return joinedSeries?.category ?? 'Demo';
      case JoinSearchState.invalid:
        return '–';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Smart Card carousel
            SizedBox(
              height: kStorySeriesCardHeight + 20, // card height + padding
              child: PageView.builder(
                controller: _cardPageController,
                itemCount: 2,
                onPageChanged: _onCardPageChanged,
                itemBuilder: (context, index) {
                  final isNewSeries = index == 0;
                  final isEmptyState = isNewSeries && _isNewSeriesEmptyState;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: StorySeriesSmartCard(
                      key: ValueKey(
                          '${isNewSeries}_${_joinSearchState}_${joinedSeries?.seriesTitle}'),
                      modeLabel:
                          isNewSeries ? 'New Series' : 'Join by Story Code',
                      level: isNewSeries
                          ? (isEmptyState ? 'N4' : _selectedLevel)
                          : _getJoinCardLevel(),
                      seriesTitle: isNewSeries
                          ? (isEmptyState
                              ? 'Please select your level and category'
                              : (_seriesTitleController.text.isNotEmpty
                                  ? _seriesTitleController.text
                                  : 'Series Title Name'))
                          : _getJoinCardTitle(),
                      episodeTitle: isNewSeries
                          ? (isEmptyState
                              ? 'Then enter a Series Title and Episode Title'
                              : (_episodeTitleController.text.isNotEmpty
                                  ? '${_episodeTitleController.text} (ep-1)'
                                  : 'Episode Title Name (ep-1)'))
                          : _getJoinCardEpisodeTitle(),
                      description: isNewSeries
                          ? (isEmptyState
                              ? 'Start by choosing a JLPT level and category below. We\'ll update this preview as you type.'
                              : (_descriptionController.text.isNotEmpty
                                  ? _descriptionController.text
                                  : 'Enter a description for your new story series.'))
                          : _getJoinCardDescription(),
                      category: isNewSeries
                          ? (isEmptyState
                              ? '—'
                              : (_selectedCategory ?? 'Category'))
                          : _getJoinCardCategory(),
                      isActive: index == activeCardIndex,
                      coverImage: isNewSeries ? _newSeriesCover : null,
                      onTapCover: isNewSeries ? _pickNewSeriesCover : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // Dot indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (index) {
                final isActive = index == activeCardIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    width: isActive ? 8 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            // Dynamic form area
            if (activeCardIndex == 0)
              _buildCreateNewForm()
            else
              _buildJoinByCodeForm(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateNewForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Select your level
        Container(
          padding: const EdgeInsets.all(16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select your level',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: DropdownButtonFormField<String>(
                  value: _selectedLevel,
                  onChanged: (value) {
                    if (value != null) _onLevelChanged(value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Choose JLPT level',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    isDense: true,
                  ),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  iconSize: 24,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.0,
                  ),
                  itemHeight: 48,
                  items: _jlptLevels.map((String level) {
                    return DropdownMenuItem<String>(
                      value: level,
                      child: Container(
                        height: 48,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          level,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Categories Select - using shared widget
        CategoryChipsSelector(
          categories: _categories,
          selectedCategory: _selectedCategory,
          onCategorySelected: _onCategoryChanged,
        ),
        const SizedBox(height: 16),
        // Series Title
        TextField(
          controller: _seriesTitleController,
          onChanged: (_) {
            setState(() {
              _hasUserInteracted = true;
            });
          },
          decoration: InputDecoration(
            labelText: 'Series Title',
            hintText: 'Enter series title',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        // New PassCode Number
        TextField(
          controller: _passCodeController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'New PassCode Number',
            hintText: 'Enter passcode',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        // Episode Title
        TextField(
          controller: _episodeTitleController,
          onChanged: (_) {
            setState(() {
              _hasUserInteracted = true;
            });
          },
          decoration: InputDecoration(
            labelText: 'Episode Title',
            hintText: 'Episode Title Name',
            suffixText: 'ep-1',
            suffixStyle: TextStyle(color: Colors.grey.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        // Description
        TextField(
          controller: _descriptionController,
          onChanged: (_) {
            setState(() {
              _hasUserInteracted = true;
            });
          },
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: 'Description',
            hintText: 'Enter description',
            alignLabelWithHint: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildJoinByCodeForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Story Code with search button and shake animation
        _ShakeWidget(
          key: _storyCodeFieldKey,
          shake: _joinSearchState == JoinSearchState.invalid,
          child: TextField(
            controller: _storyCodeController,
            decoration: InputDecoration(
              labelText: 'Story Code',
              hintText: 'Enter story code',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: _joinSearchState == JoinSearchState.invalid
                      ? Colors.red
                      : const Color(0xFFE6E6E6),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red, width: 1),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _searchStoryCode,
                tooltip: 'Search',
              ),
            ),
          ),
        ),
        // Accordion for hidden fields
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _showJoinFields
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    // Please Fill Story's Passcode with eye toggle
                    TextFormField(
                      controller: _joinPassCodeController,
                      keyboardType: TextInputType.number,
                      obscureText: !_passcodeVisible,
                      decoration: InputDecoration(
                        labelText: "Please Fill Story's Passcode",
                        hintText: 'Enter passcode',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE6E6E6)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE6E6E6)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Colors.blue, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passcodeVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _passcodeVisible = !_passcodeVisible;
                            });
                          },
                          tooltip: _passcodeVisible ? 'Hide' : 'Show',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Episode Title
                    TextField(
                      controller: _joinEpisodeTitleController,
                      decoration: InputDecoration(
                        labelText: 'Episode Title',
                        hintText: 'Episode Title Name',
                        suffixText: 'ep-${joinedSeries?.currentEp ?? 1}',
                        suffixStyle: TextStyle(color: Colors.grey.shade600),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE6E6E6)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE6E6E6)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Colors.blue, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Description
                    TextField(
                      controller: _joinDescriptionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Enter description',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE6E6E6)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE6E6E6)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Colors.blue, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // Getters for CREATE button validation
  bool get canCreateNewSeries =>
      _seriesTitleController.text.trim().isNotEmpty &&
      _episodeTitleController.text.trim().isNotEmpty;

  bool get canCreateJoinSeries =>
      _storyCodeController.text.trim().isNotEmpty &&
      _joinEpisodeTitleController.text.trim().isNotEmpty;
}

/// Shake animation widget for error feedback
class _ShakeWidget extends StatefulWidget {
  final Widget child;
  final bool shake;

  const _ShakeWidget({super.key, required this.child, required this.shake});

  @override
  State<_ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<_ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: -10, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 10, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: -10, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 10, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shake && !oldWidget.shake) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_animation.value, 0),
          child: widget.child,
        );
      },
    );
  }
}
