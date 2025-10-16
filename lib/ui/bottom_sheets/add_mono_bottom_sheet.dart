import 'package:flutter/material.dart';

enum JlptLevel { n5, n4, n3, n2, n1 }
enum MonoKind { oneShort, story }

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
  final categories = const [
    'Love', 'Comedy', 'Horror', 'Cultural', 'Adventure', 
    'Fantasy', 'Drama', 'Business', 'Sci-Fi', 'Mystery'
  ];

  // Limit content
  bool premiumOnly = false;
  int? coinLimit; // 10 / 30 / 50


  // --- Helpers ---
  int _filledCount() {
    int c = 0;
    if (level != null) c++;
    c++; // monoKind chosen
    if (monoKind == MonoKind.story) {
      if (codeCtrl.text.trim().isNotEmpty) c++;
    } else {
      // One-Short requires category selection
      if (selectedCategory != null) c++;
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
          const SizedBox(height: 12),
          TextField(
            controller: codeCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Enter Story Code',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(
                onPressed: () {}, // mock search
                icon: const Icon(Icons.search),
              ),
            ),
          ),
        ],
        if (monoKind == MonoKind.oneShort) ...[
          const SizedBox(height: 12),
          _categorySelector(),
        ],
      ],
    );
  }


  Widget _categorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Select Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            if (selectedCategory != null) ...[
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => showCategoryDetails = !showCategoryDetails),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = selectedCategory == category;
              return Padding(
                padding: EdgeInsets.only(right: index < categories.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => selectedCategory = category),
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
            },
          ),
        ),
        if (showCategoryDetails && selectedCategory != null) ...[
          const SizedBox(height: 12),
          _categoryDetailsCard(),
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
          Text(
            'Story Code: ${codeCtrl.text}',
            style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
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

  @override
  void dispose() {
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
                    padding: const EdgeInsets.only(bottom: 20),
                    children: [
                      // Level
                      _section(title: 'Select your level', child: _levelPicker()),
                      // Mono Type
                      _section(title: 'Select Mono Type', child: _monoType()),
                            // Story Details Card
                            if (monoKind == MonoKind.story && codeCtrl.text.trim().isNotEmpty) _storyDetailsCard(),
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