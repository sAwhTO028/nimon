import 'dart:async';
import 'package:flutter/material.dart';

enum JlptLevel { n5, n4, n3, n2, n1 }
enum MonoKind { oneShort, story }
enum StoryMode { byCode, byCategory }

class OneShortItem {
  final String category;
  final String title;
  final String duration;

  OneShortItem(this.category, this.title, this.duration);
}

class AddMonoDemoPage extends StatelessWidget {
  const AddMonoDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mono')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (_, i) => ListTile(
          leading: CircleAvatar(
            radius: 28,
            backgroundImage: AssetImage('assets/sample_$i.jpg'),
          ),
          title: Text('Story #${i + 1} – Rainy Kyoto'),
          subtitle: const Text('Description overall……'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
              color: Colors.white,
            ),
            child: const Text('N5'),
          ),
        ),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: 5,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddMonoBottomSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Call this to show the bottom sheet
void showAddMonoBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (ctx) => const _AddMonoSheet(),
  );
}

class _AddMonoSheet extends StatefulWidget {
  const _AddMonoSheet();

  @override
  State<_AddMonoSheet> createState() => _AddMonoSheetState();
}

class _AddMonoSheetState extends State<_AddMonoSheet> {
  // --- State ---
  bool expandLevel = true;
  JlptLevel? level = JlptLevel.n4; // mock preselect N4
  MonoKind monoKind = MonoKind.story; // mock preselect Story

  // Story-only inputs
  final codeCtrl = TextEditingController(); // story code
  
  // Episode title editing
  bool isEditingTitle = false;
  final episodeTitleCtrl = TextEditingController();
  
  // One-Short category selection
  String? selectedCategory;
  bool showCategoryDetails = false;
  String? selectedOneShort;
  final PageController _oneShortPageController = PageController();
  int _currentOneShortPage = 0;
  final categories = const [
    'Love', 'Comedy', 'Horror', 'Cultural', 'Adventure', 
    'Fantasy', 'Drama', 'Business', 'Sci-Fi', 'Mystery'
  ];

  // Story-Type mode selection
  StoryMode storyMode = StoryMode.byCode;
  String? selectedStoryCategory;
  String? codeSearchError;
  Timer? _debounceTimer;
  final PageController _storyPageController = PageController();
  int _currentStoryPage = 0;
  final ScrollController _categoryScrollController = ScrollController();
  bool _isTransitioning = false;

  // Limit content
  bool premiumOnly = false;
  int? coinLimit; // 10 / 30 / 50

  @override
  void initState() {
    super.initState();
    _categoryScrollController.addListener(_handleCategoryScroll);
  }

  void _handleCategoryScroll() {
    if (_isTransitioning || _currentStoryPage != 0) return;
    
    if (_categoryScrollController.hasClients) {
      final currentScroll = _categoryScrollController.position.pixels;
      final maxScroll = _categoryScrollController.position.maxScrollExtent;
      
      // Debug: Print scroll position to understand the behavior
      print('Scroll: $currentScroll / $maxScroll');
      
      // Trigger transition when user scrolls to the rightmost position (end of categories)
      // This makes more sense: scroll right through categories → reach end → go to Story Code
      if (currentScroll >= maxScroll - 10) {
        print('Triggering transition to Story Code');
        _transitionToStoryCode();
      }
    }
  }

  void _transitionToStoryCode() {
    if (_isTransitioning) return;
    
    setState(() {
      _isTransitioning = true;
    });
    
    // Add a small delay to ensure smooth transition
    Future.delayed(const Duration(milliseconds: 50), () {
      _storyPageController.animateToPage(
        1, // Story Code page (now index 1)
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ).then((_) {
        setState(() {
          _isTransitioning = false;
        });
      });
    });
  }

  void _transitionToCategory() {
    if (_isTransitioning) return;
    
    setState(() {
      _isTransitioning = true;
    });
    
    _storyPageController.animateToPage(
      0, // Category page (now index 0)
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    ).then((_) {
      setState(() {
        _isTransitioning = false;
      });
    });
  }

  // --- Helpers ---
  int _filledCount() {
    int c = 0;
    if (level != null) c++;
    c++; // monoKind chosen
    if (monoKind == MonoKind.story) {
      // Story-Type requires either code or category based on current page
      if (_currentStoryPage == 0 && selectedStoryCategory != null) c++;
      if (_currentStoryPage == 1 && codeCtrl.text.trim().isNotEmpty) c++;
    } else {
      // One-Short requires category selection and One-Short selection
      if (selectedCategory != null) c++;
      if (selectedOneShort != null) c++;
    }
    if (episodeTitleCtrl.text.trim().isNotEmpty) c++;
    return c.clamp(0, 4);
  }

  bool get canStart => _filledCount() >= 4;

  Color get border => const Color(0x11000000);

  Widget _dragHandle() => Center(
        child: Container(
          width: 64,
          height: 6,
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!isEditingTitle) ...[
                      Text(
                        episodeTitleCtrl.text.isEmpty ? 'Episode Title' : episodeTitleCtrl.text,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => isEditingTitle = true),
                        child: const Icon(Icons.edit, size: 16, color: Colors.white70),
                      ),
                    ] else ...[
                      Expanded(
                        child: TextField(
                          controller: episodeTitleCtrl,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Episode Title',
                            hintStyle: TextStyle(color: Colors.white70),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (value) => setState(() => isEditingTitle = false),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Please select you want to create section',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _progress() {
    final filled = _filledCount();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: List.generate(4, (i) {
          final active = i < filled;
          return Expanded(
            child: Container(
              height: 6,
              margin: EdgeInsets.only(right: i == 3 ? 0 : 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: active ? Colors.black87 : Colors.black12,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _levelPicker() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => expandLevel = !expandLevel),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    level != null ? level!.name.toUpperCase() : 'Please Select Your Level',
                    style: TextStyle(
                      color: level != null ? Colors.black87 : Colors.grey.shade600,
                      fontSize: 16,
                      fontWeight: level != null ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                Icon(
                  expandLevel ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: JlptLevel.values.map((lv) {
              final label = lv.name.toUpperCase();
              final selected = level == lv;
              return GestureDetector(
                onTap: () => setState(() {
                  level = lv;
                  expandLevel = false; // Close accordion after selection
                }),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: selected ? Colors.blue.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? Colors.blue : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(label, style: TextStyle(
                      color: selected ? Colors.blue.shade800 : Colors.black87,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    )),
                  ),
                ),
              );
            }).toList(),
          ),
          crossFadeState: expandLevel ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ],
    );
  }

  Widget _monoType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => monoKind = MonoKind.oneShort),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: monoKind == MonoKind.oneShort ? Colors.blue.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: monoKind == MonoKind.oneShort ? Colors.blue : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text('One-Short', style: TextStyle(
                      color: monoKind == MonoKind.oneShort ? Colors.blue.shade800 : Colors.black87,
                      fontWeight: monoKind == MonoKind.oneShort ? FontWeight.w600 : FontWeight.w500,
                    )),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => monoKind = MonoKind.story),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: monoKind == MonoKind.story ? Colors.red.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: monoKind == MonoKind.story ? Colors.red : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text('Story-Type', style: TextStyle(
                      color: monoKind == MonoKind.story ? Colors.red.shade800 : Colors.black87,
                      fontWeight: monoKind == MonoKind.story ? FontWeight.w600 : FontWeight.w500,
                    )),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (monoKind == MonoKind.story) ...[
          const SizedBox(height: 16),
          _storySwipeView(),
        ],
        if (monoKind == MonoKind.oneShort) ...[
          const SizedBox(height: 12),
          _categorySelector(),
        ],
      ],
    );
  }

  Widget _storySwipeView() {
    return Column(
      children: [
        // PageView for swipe functionality - match One-Short height
        SizedBox(
          height: 68, // Match One-Short: 16px title + 8px spacing + 40px chips + 4px buffer
          child: PageView(
            controller: _storyPageController,
            onPageChanged: (index) {
              setState(() {
                _currentStoryPage = index;
                storyMode = index == 0 ? StoryMode.byCategory : StoryMode.byCode;
                // Clear focus when switching to story code page
                if (index == 1) {
                  FocusScope.of(context).unfocus();
                }
              });
            },
            children: [
              // By Category Page (first)
              Semantics(
                label: 'By Category page',
                child: _storyCategorySelector(),
              ),
              // By Code Page (second)
              Semantics(
                label: 'By Code page',
                child: _storyCodeInput(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Page Indicator
        _pageIndicator(),
      ],
    );
  }

  Widget _pageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final isActive = _currentStoryPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? Colors.blue : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }


  Widget _oneShortHorizontalCards() {
    final oneShortItems = _getOneShortItemsForCategory(selectedCategory!);
    
    if (oneShortItems.isEmpty) {
      return Center(
        child: Text(
          'No One-Shorts in this category yet.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {}, // Stop gesture bubbling
      onHorizontalDragUpdate: (_) {}, // Capture horizontal drags
      onHorizontalDragEnd: (_) {}, // Complete horizontal gesture capture
      child: PageView.builder(
        controller: _oneShortPageController,
        physics: const PageScrollPhysics(), // Enable page scrolling
        clipBehavior: Clip.hardEdge, // Clip to container bounds
        allowImplicitScrolling: false, // Disable implicit scrolling
        onPageChanged: (index) {
          setState(() {
            _currentOneShortPage = index;
          });
        },
        itemCount: oneShortItems.length,
        itemBuilder: (context, index) {
          final item = oneShortItems[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced vertical margins
            child: _oneShortHorizontalCard(item),
          );
        },
      ),
    );
  }

  Widget _oneShortHorizontalCard(OneShortItem item) {
    final isSelected = selectedOneShort == item.title;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedOneShort = isSelected ? null : item.title;
        });
        print('Selected One-Short: ${item.title}');
      },
      child: Container(
        width: double.infinity, // Full width within container
        child: Material(
          elevation: 4, // Reduced elevation for contained shadow
          shadowColor: Colors.black26,
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12), // Match container radius
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: double.infinity, // Ensure full width
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12), // Match container radius
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.short_text,
                      color: isSelected ? Colors.blue.shade600 : Colors.blue.shade400,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.w600, 
                          color: isSelected ? Colors.blue.shade800 : Colors.black87
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_circle,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Category: ${item.category}',
                  style: TextStyle(
                    fontSize: 14, 
                    color: isSelected ? Colors.blue.shade700 : Colors.black87, 
                    fontWeight: FontWeight.w500
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Duration: ${item.duration}',
                  style: TextStyle(
                    fontSize: 14, 
                    color: isSelected ? Colors.blue.shade600 : Colors.black87
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<OneShortItem> _getOneShortItemsForCategory(String category) {
    // Mock data - in real app, this would be filtered by category and level
    switch (category) {
      case 'Love':
        return [
          OneShortItem('Love', 'Daily Conversation', '5-10 minutes'),
          OneShortItem('Love', 'Coffee Shop Meeting', '3-5 minutes'),
          OneShortItem('Love', 'First Date', '8-12 minutes'),
          OneShortItem('Love', 'Valentine\'s Day', '6-8 minutes'),
          OneShortItem('Love', 'Anniversary Dinner', '10-15 minutes'),
        ];
      case 'Comedy':
        return [
          OneShortItem('Comedy', 'Funny Office Story', '4-6 minutes'),
          OneShortItem('Comedy', 'Weekend Adventure', '6-8 minutes'),
          OneShortItem('Comedy', 'Family Dinner', '5-7 minutes'),
          OneShortItem('Comedy', 'Pet Stories', '3-5 minutes'),
          OneShortItem('Comedy', 'Travel Mishaps', '7-10 minutes'),
        ];
      case 'Horror':
        return [
          OneShortItem('Horror', 'Midnight Walk', '7-10 minutes'),
          OneShortItem('Horror', 'Old House', '8-12 minutes'),
          OneShortItem('Horror', 'Forest Trail', '6-9 minutes'),
          OneShortItem('Horror', 'Stormy Night', '5-8 minutes'),
          OneShortItem('Horror', 'Abandoned School', '9-13 minutes'),
        ];
      case 'Cultural':
        return [
          OneShortItem('Cultural', 'Traditional Festival', '6-9 minutes'),
          OneShortItem('Cultural', 'Family Traditions', '5-8 minutes'),
          OneShortItem('Cultural', 'Local Customs', '4-7 minutes'),
          OneShortItem('Cultural', 'Historical Story', '8-12 minutes'),
          OneShortItem('Cultural', 'Art and Music', '7-10 minutes'),
        ];
      case 'Adventure':
        return [
          OneShortItem('Adventure', 'Mountain Climbing', '8-12 minutes'),
          OneShortItem('Adventure', 'Ocean Journey', '10-15 minutes'),
          OneShortItem('Adventure', 'Desert Trek', '6-9 minutes'),
          OneShortItem('Adventure', 'City Exploration', '5-8 minutes'),
          OneShortItem('Adventure', 'Wildlife Safari', '7-11 minutes'),
        ];
      case 'Fantasy':
        return [
          OneShortItem('Fantasy', 'Magic Forest', '9-13 minutes'),
          OneShortItem('Fantasy', 'Dragon Quest', '12-18 minutes'),
          OneShortItem('Fantasy', 'Fairy Tale', '6-9 minutes'),
          OneShortItem('Fantasy', 'Wizard School', '8-12 minutes'),
          OneShortItem('Fantasy', 'Enchanted Castle', '10-15 minutes'),
        ];
      case 'Drama':
        return [
          OneShortItem('Drama', 'Family Conflict', '8-12 minutes'),
          OneShortItem('Drama', 'Life Decisions', '10-15 minutes'),
          OneShortItem('Drama', 'Friendship Test', '6-9 minutes'),
          OneShortItem('Drama', 'Career Choices', '7-11 minutes'),
          OneShortItem('Drama', 'Personal Growth', '9-13 minutes'),
        ];
      case 'Business':
        return [
          OneShortItem('Business', 'Startup Journey', '8-12 minutes'),
          OneShortItem('Business', 'Meeting Challenge', '5-8 minutes'),
          OneShortItem('Business', 'Team Building', '6-9 minutes'),
          OneShortItem('Business', 'Client Presentation', '7-10 minutes'),
          OneShortItem('Business', 'Success Story', '9-13 minutes'),
        ];
      case 'Sci-Fi':
        return [
          OneShortItem('Sci-Fi', 'Space Mission', '10-15 minutes'),
          OneShortItem('Sci-Fi', 'Time Travel', '8-12 minutes'),
          OneShortItem('Sci-Fi', 'Robot Story', '6-9 minutes'),
          OneShortItem('Sci-Fi', 'Future World', '9-13 minutes'),
          OneShortItem('Sci-Fi', 'Alien Contact', '7-11 minutes'),
        ];
      case 'Mystery':
        return [
          OneShortItem('Mystery', 'Missing Person', '8-12 minutes'),
          OneShortItem('Mystery', 'Strange Events', '6-9 minutes'),
          OneShortItem('Mystery', 'Secret Code', '7-10 minutes'),
          OneShortItem('Mystery', 'Hidden Clues', '5-8 minutes'),
          OneShortItem('Mystery', 'Final Revelation', '9-13 minutes'),
        ];
      default:
        return [
          OneShortItem(category, 'Sample Story 1', '5-8 minutes'),
          OneShortItem(category, 'Sample Story 2', '6-9 minutes'),
          OneShortItem(category, 'Sample Story 3', '4-7 minutes'),
          OneShortItem(category, 'Sample Story 4', '7-10 minutes'),
          OneShortItem(category, 'Sample Story 5', '8-12 minutes'),
        ];
    }
  }

  Widget _oneShortIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(1, (index) {
        // Single dot for One-Short (always active)
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 24,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _oneShortPageIndicator() {
    final oneShortItems = _getOneShortItemsForCategory(selectedCategory!);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(oneShortItems.length, (index) {
        final isActive = _currentOneShortPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? Colors.blue : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }


  Widget _storyCodeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Story Code',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GestureDetector(
            onPanEnd: (details) {
              // Detect rightward swipe to go back to categories
              if (details.velocity.pixelsPerSecond.dx > 500) {
                _transitionToCategory();
              }
            },
            child: Semantics(
              label: 'Story Code input',
              textField: true,
              child: TextField(
            controller: codeCtrl,
                onChanged: (value) {
                  setState(() {});
                  _onCodeChanged(value);
                },
                onSubmitted: _onCodeSubmitted,
                textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Enter Story Code',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: Semantics(
                    label: 'Search story code',
                    button: true,
                    child: IconButton(
                      onPressed: () {
                        if (codeCtrl.text.trim().isNotEmpty) {
                          _onCodeSubmitted(codeCtrl.text);
                        }
                      },
                icon: const Icon(Icons.search),
                    ),
                  ),
                  errorText: codeSearchError,
                ),
              ),
              ),
            ),
          ),
      ],
    );
  }

  // Pure category selector component - shared between One-Short and Story-Type
  Widget _buildCategorySelector({
    required String? selectedCategory,
    required Function(String) onCategorySelected,
    ScrollController? scrollController,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Category',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.builder(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = selectedCategory == category;
              return _buildCategoryChip(
                category: category,
                isSelected: isSelected,
                onTap: () => onCategorySelected(category),
                scrollController: scrollController,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _storyCategorySelector() {
    // Reuse the exact same component as One-Short - no modifications
    return _buildCategorySelector(
      selectedCategory: selectedStoryCategory,
      onCategorySelected: (category) => setState(() => selectedStoryCategory = category),
      scrollController: _categoryScrollController,
    );
  }

  // Shared category chip component used by both One-Short and Story-Type
  Widget _buildCategoryChip({
    required String category,
    required bool isSelected,
    required VoidCallback onTap,
    required ScrollController? scrollController,
  }) {
    return Padding(
      padding: EdgeInsets.only(right: 8), // Consistent spacing
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              category,
              style: TextStyle(
                color: isSelected ? Colors.blue.shade800 : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _categorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reuse the exact same category selector component
        _buildCategorySelector(
          selectedCategory: selectedCategory,
          onCategorySelected: (category) => setState(() => selectedCategory = category),
          scrollController: null,
        ),
        // One-Short Details content when category is selected
        if (selectedCategory != null) ...[
          const SizedBox(height: 12),
          // One-Short Details title
          Row(
            children: [
              Text(
                'One-Short Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  // Navigate to full One-Short list page
                  print('Navigate to One-Short list for category: $selectedCategory');
                },
                child: Text(
                  'See more',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Clipped carousel container
          ClipRRect(
            borderRadius: BorderRadius.circular(12), // Match parent card radius
            clipBehavior: Clip.hardEdge,
            child: Container(
              width: double.infinity,
              height: 140, // Reduced height for better visibility
              child: _oneShortHorizontalCards(),
            ),
          ),
          const SizedBox(height: 8),
          // Page indicator inside the card
          _oneShortPageIndicator(),
        ],
      ],
    );
  }

  Widget _categoryDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getCategoryIcon(selectedCategory!),
                color: Colors.blue.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                selectedCategory!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getCategoryDescription(selectedCategory!),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Love': return Icons.favorite;
      case 'Comedy': return Icons.sentiment_very_satisfied;
      case 'Horror': return Icons.warning;
      case 'Cultural': return Icons.public;
      case 'Adventure': return Icons.explore;
      case 'Fantasy': return Icons.auto_awesome;
      case 'Drama': return Icons.theater_comedy;
      case 'Business': return Icons.business;
      case 'Sci-Fi': return Icons.rocket_launch;
      case 'Mystery': return Icons.help_outline;
      default: return Icons.category;
    }
  }

  String _getCategoryDescription(String category) {
    switch (category) {
      case 'Love': return 'Romantic stories focusing on relationships, emotions, and personal connections.';
      case 'Comedy': return 'Humorous and light-hearted stories designed to entertain and make you laugh.';
      case 'Horror': return 'Suspenseful and frightening stories that create tension and excitement.';
      case 'Cultural': return 'Stories that explore different cultures, traditions, and social customs.';
      case 'Adventure': return 'Exciting stories with action, exploration, and thrilling experiences.';
      case 'Fantasy': return 'Imaginative stories with magical elements, mythical creatures, and supernatural themes.';
      case 'Drama': return 'Serious stories focusing on character development and emotional depth.';
      case 'Business': return 'Stories about entrepreneurship, corporate life, and professional challenges.';
      case 'Sci-Fi': return 'Futuristic stories with advanced technology, space exploration, and scientific concepts.';
      case 'Mystery': return 'Puzzle-solving stories with secrets, clues, and unexpected revelations.';
      default: return 'A story in this category.';
    }
  }

  Widget _limitContent() {
    Widget coin(int v) {
      final sel = coinLimit == v;
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: sel ? Colors.amber.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? Colors.amber : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 16, color: Colors.amber.shade600),
            const SizedBox(width: 8),
            Text('$v', style: TextStyle(
              fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
              color: sel ? Colors.amber.shade800 : Colors.black87,
            )),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: premiumOnly ? Colors.red.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: premiumOnly ? Colors.red : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 16, color: premiumOnly ? Colors.red : Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text('Premium User', style: TextStyle(
                    fontWeight: premiumOnly ? FontWeight.w600 : FontWeight.w500,
                    color: premiumOnly ? Colors.red.shade800 : Colors.black87,
                  )),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() {
                coinLimit = 10;
                premiumOnly = false;
              }),
              child: coin(10),
            ),
            GestureDetector(
              onTap: () => setState(() {
                coinLimit = 30;
                premiumOnly = false;
              }),
              child: coin(30),
            ),
            GestureDetector(
              onTap: () => setState(() {
                coinLimit = 50;
                premiumOnly = false;
              }),
              child: coin(50),
            ),
            GestureDetector(
              onTap: () => setState(() {
                coinLimit = 70;
                premiumOnly = false;
              }),
              child: coin(70),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Reader needs coins or premium to open this content.',
          style: TextStyle(color: Colors.black.withOpacity(.6)),
        ),
      ],
    );
  }

  Widget _storyDetailsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.book,
                color: Colors.blue.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Story Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_currentStoryPage == 0) ...[
            Text(
              'Category: $selectedStoryCategory',
              style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
          ] else ...[
          Text(
            'Story Code: ${codeCtrl.text}',
            style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          ],
          Text(
            'Story Title: RAINY KYOTO',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 2),
          Text(
            'Next Episode: 03',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        color: filled ? const Color(0xFFE6F2FF) : Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (filled) const Icon(Icons.check_circle, size: 18, color: Colors.blue),
          if (filled) const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _onCodeChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (value.trim().isNotEmpty) {
        // Mock search - in real app, this would call an API
        setState(() {
          codeSearchError = null; // Clear error on successful search
        });
      }
    });
  }

  void _onCodeSubmitted(String value) {
    _debounceTimer?.cancel();
    if (value.trim().isNotEmpty) {
      // Mock search - in real app, this would call an API
      setState(() {
        codeSearchError = null; // Clear error on successful search
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _storyPageController.dispose();
    _categoryScrollController.dispose();
    _oneShortPageController.dispose();
    codeCtrl.dispose();
    episodeTitleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A), // Dark background
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * .85,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dragHandle(),
                _header(context),
                _progress(),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    physics: const ClampingScrollPhysics(), // Disable horizontal scrolling
                    scrollDirection: Axis.vertical, // Ensure vertical only
                    clipBehavior: Clip.none, // Don't clip child shadows
                    padding: const EdgeInsets.only(bottom: 20),
                    children: [
                      // Level
                      _section(title: 'Select your level', child: _levelPicker()),
                      // Mono Type
                      _section(title: 'Select Mono Type', child: _monoType()),
                            // Story Details Card
                            if (monoKind == MonoKind.story && 
                                ((_currentStoryPage == 0 && selectedStoryCategory != null) ||
                                 (_currentStoryPage == 1 && codeCtrl.text.trim().isNotEmpty))) 
                              _storyDetailsCard(),
                            // Limit
                            _section(title: 'Limit Your Content', child: _limitContent()),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final btn = InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(32),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? Colors.black : Colors.black.withOpacity(.2),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.black12),
        ),
        child: const Text('START',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: .6)),
      ),
    );
    return AnimatedOpacity(duration: const Duration(milliseconds: 120), opacity: 1, child: btn);
  }
}