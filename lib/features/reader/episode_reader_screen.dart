import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nimon/models/story.dart';
import '../../data/episode_mock_data.dart'; // CANONICAL mock data source

/// DEPRECATED: Local mock text - kept as fallback only
/// The canonical source is now episode_mock_data.dart
/// This local constant is only used if episode_mock_data.dart is unavailable
/// TODO: Remove this after confirming episode_mock_data.dart is always available
const String _mockEpisodeText = '''
The rain continued to fall on the ancient streets of Kyoto. Lanterns swayed softly above the narrow alley, and the smell of wet stone mixed with the sweet scent of roasted sweet potatoes from a nearby stall. Yuki pulled his coat tighter and walked slowly, listening to the quiet sound of his own footsteps. He was on his way home from a long day of work. Usually he took the crowded main road, but tonight he chose this old backstreet because it reminded him of his childhood. The wooden houses, the low roofs, and the gentle glow of the lanterns made him feel calm inside.

As he turned the corner, he saw a small bookshop he had never noticed before. The sign was old, and the letters were almost erased by time. Through the foggy window he could see warm light and the shadow of tall bookshelves. Curiosity pulled him closer, and he opened the door slowly. A small bell rang above his head. Inside, the air was dry and smelled of paper and ink. Books were stacked everywhere—on shelves, on tables, even on the floor. Behind the counter sat an old man with round glasses and a gentle smile. He looked up as Yuki entered, as if he had been expecting him.

"Welcome," the old man said. "You are just in time." "In time for what?" Yuki asked, confused. He was sure the shop was completely new to him. He had walked this way many times in the past, but he had never seen it before. The old man pointed to a single book lying on the counter. It had a dark blue cover with a simple silver line drawn across it, like a river under the moon. There was no title, no author's name, only that lonely silver line. Something about it felt strangely familiar, and Yuki reached out his hand without thinking.

"This book," the old man said quietly, "contains stories that have not happened yet. They are waiting for someone to read them and bring them to life." Yuki laughed softly. "That sounds like a good fantasy novel," he said. "But I'm very tired today. I'm not sure I can start a new story." The old man shook his head. "You don't understand. This book is not about heroes in another world. It is about you. About the choices you will make from tonight on." His eyes were calm, but there was a strange strength behind them that made Yuki stop smiling.

For a moment, the sound of the rain outside grew louder. Yuki felt the weight of the book in his hands. It was heavier than it looked, as if the pages were filled with more than just ink. He slowly opened the cover. The first page was blank, completely white, with no words at all. "Is this some kind of joke?" he asked. The old man shook his head again. "The pages are empty because you have not lived them yet. As you make decisions, the words will appear. If you choose to be brave, the story will move in one direction. If you choose to run away, it will move in another."

Yuki looked down at the empty page. He thought about his life—about the work he did every day, about the dreams he used to have when he was younger, and about the quiet feeling that something was missing. The idea that his future could be written like a story made him feel both excited and afraid at the same time. "Can I really change my story?" he whispered. The old man nodded. "Everyone can. But most people never open the book. They just let the pages fill themselves with random words. You, however, have opened it. That is already your first decision."

Outside, the rain began to slow down. The sound softened, and Yuki could hear the distant ringing of a temple bell. He realized that the night was not just wet and cold—it was also full of possibility. He closed the book gently and held it against his chest. "I don't know what will happen," he said, "but I want to try." The old man smiled, and for a second his face seemed younger, almost like a reflection of Yuki himself. "Then go," he said. "Walk home with this book. Tomorrow, take one small action that you have been afraid to take. When you return and open the pages again, you will see the first lines of your new story."

Yuki bowed slightly and left the shop. When he stepped outside, the alley looked different. The lanterns shone a little brighter, and the puddles on the ground reflected the city lights like tiny mirrors. He walked forward, the mysterious book held firmly in his hand, feeling that each step was the beginning of something new. He did not notice that behind him, the old bookshop sign faded slowly into the darkness. By the time he reached the end of the alley and turned around, the shop was gone. Only the sound of the quiet Kyoto night remained, and the soft, endless possibilities written on the empty pages he carried home.

The next morning, Yuki woke up earlier than usual. The book sat on his nightstand, its dark blue cover catching the first light of dawn. He reached for it hesitantly, wondering if last night had been a dream. But the book was real, solid in his hands. He opened it slowly, half expecting to see the blank pages again. But this time, there were words. Just a few lines, written in elegant script that seemed to shimmer in the morning light.

"Today, you will meet someone who will change everything. They will be waiting at the coffee shop near the station, reading a book with a red cover. When you see them, you must choose: speak or walk away. This choice will determine the next chapter of your story."

Yuki read the words three times, his heart beating faster with each reading. Could this be real? Was someone actually waiting for him? He looked at the clock. If he left now, he would have time to stop at the coffee shop before work. But what if it was all nonsense? What if he made a fool of himself? He closed the book and got ready for work, trying to push the words from his mind. But they lingered, like a melody he couldn't forget.

As he walked to the station, his usual route took him past the coffee shop. He had walked past it hundreds of times without ever going inside. Today, something made him slow down. Through the window, he could see the warm interior, the smell of fresh coffee drifting out into the morning air. And there, in the corner by the window, sat a person reading a book with a red cover. Yuki's breath caught in his throat. It was real. The book had been right.

He stood there for what felt like an eternity, watching the person read. They looked peaceful, completely absorbed in their book. Yuki's hand moved to the door handle, then pulled back. What would he say? How would he explain why he was there? The old man's words echoed in his mind: "If you choose to be brave, the story will move in one direction. If you choose to run away, it will move in another."

Taking a deep breath, Yuki pushed open the door. The bell above it chimed softly, and the person looked up from their book. Their eyes met Yuki's, and in that moment, something shifted. It was as if they had been waiting for him, just as the book had said. "Hello," Yuki said, his voice barely above a whisper. "I know this sounds strange, but I think I was meant to meet you here."

The person smiled, a warm, genuine smile that made Yuki's nervousness fade away. "I was hoping you would come," they said. "My name is Aiko. And I think I know why you're here." They closed their book, revealing the red cover, and placed it on the table. "Would you like to sit down? I believe we have a story to write together."

Yuki sat across from Aiko, feeling as if he had stepped into a different world. The coffee shop around them seemed to fade away, leaving only the two of them and the mysterious book that had brought them together. "How did you know?" Yuki asked. Aiko's smile grew wider. "Because I have a book too," they said, pulling a similar dark blue book from their bag. "And mine told me to wait here for someone who would change everything. I think that someone is you."

As they talked, Yuki felt something he hadn't felt in years: hope. Real, genuine hope that his life could be different, that he could write a new story for himself. The pages of his book were no longer empty. They were filling with words, with possibilities, with a future he had never dared to imagine. And as he looked at Aiko, he realized that this was only the beginning. The book had been right. His story was just starting to unfold.
''';

/// Constants for reading UI
class _ReadingConstants {
  static const double horizontalPadding = 20.0;
  static const double verticalPadding = 24.0;
  static const double lineHeight = 1.8;
  static const double letterSpacing = 0.3;
}

/// Premium book-reading UI with paginated pages (like Apple Books / Google Play Books / Kindle)
class EpisodeReaderScreen extends StatefulWidget {
  final Episode episode;
  final String? storyId;

  const EpisodeReaderScreen({
    super.key,
    required this.episode,
    this.storyId,
  });

  @override
  State<EpisodeReaderScreen> createState() => _EpisodeReaderScreenState();
}

class _EpisodeReaderScreenState extends State<EpisodeReaderScreen> {
  late PageController _pageController;
  bool _isHeaderVisible = true;
  int _currentPageIndex = 0;
  List<String> _pages = [];
  Timer? _headerHideTimer;

  // Episode data (real or mock)
  late Episode _displayEpisode;
  bool _usingMockData = false;

  // Reading preferences
  FontSize _fontSize = FontSize.medium;
  ReadingTheme _theme = ReadingTheme.light;
  
  // Layout constraints for pagination
  double _contentWidth = 0;
  double _contentHeight = 0;
  bool _dimensionsReady = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeEpisode();
    _loadPreferences();
  }

  /// Initialize episode data - use real data if available, fallback to mock
  void _initializeEpisode() {
    // Check if episode has valid content
    final hasContent = widget.episode.blocks.isNotEmpty &&
        widget.episode.blocks.any((block) => block.text.isNotEmpty);

    if (hasContent) {
      _displayEpisode = widget.episode;
      _usingMockData = false;
    } else {
      // Use mock data as fallback
      _displayEpisode = _createMockEpisode();
      _usingMockData = true;
    }
  }

  /// Create a mock episode with sample text for UI testing
  /// Uses canonical mock data from episode_mock_data.dart
  Episode _createMockEpisode() {
    return Episode(
      id: widget.episode.id,
      storyId: widget.episode.storyId,
      index: widget.episode.index,
      blocks: [
        EpisodeBlock(
          type: BlockType.narration,
          // Use canonical mock data, fallback to local constant if unavailable
          text: getMockEpisodeText(widget.episode.index),
        ),
      ],
      thumbnailUrl: widget.episode.thumbnailUrl,
      title: widget.episode.title ?? 'Episode ${widget.episode.index}',
    );
  }

  @override
  void dispose() {
    _headerHideTimer?.cancel();
    _savePagePosition();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFontSize = prefs.getString('reader_font_size');
    final savedTheme = prefs.getString('reader_theme');
    final savedPageIndex = prefs.getInt('reader_page_${widget.episode.id}') ?? 0;

    if (mounted) {
      setState(() {
        if (savedFontSize != null) {
          _fontSize = FontSize.values.firstWhere(
            (e) => e.name == savedFontSize,
            orElse: () => FontSize.medium,
          );
        }
        if (savedTheme != null) {
          _theme = ReadingTheme.values.firstWhere(
            (e) => e.name == savedTheme,
            orElse: () => ReadingTheme.light,
          );
        }
        _currentPageIndex = savedPageIndex;
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reader_font_size', _fontSize.name);
    await prefs.setString('reader_theme', _theme.name);
  }

  Future<void> _savePagePosition() async {
    if (_pageController.hasClients) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'reader_page_${widget.episode.id}',
        _currentPageIndex,
      );
    }
  }

  void _showHeaderTemporarily() {
    setState(() => _isHeaderVisible = true);
    _headerHideTimer?.cancel();
    _headerHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isHeaderVisible = false);
      }
    });
  }

  void _onPageTap() {
    setState(() {
      _isHeaderVisible = !_isHeaderVisible;
    });
    if (_isHeaderVisible) {
      _showHeaderTemporarily();
    }
  }

  void _showFontSizeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _FontSizeSelector(
        currentSize: _fontSize,
        onSelected: (size) {
          setState(() {
            _fontSize = size;
          });
          _savePreferences();
          _recalculatePages();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showThemeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ThemeSelector(
        currentTheme: _theme,
        onSelected: (theme) {
          setState(() {
            _theme = theme;
          });
          _savePreferences();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _recalculatePages() {
    if (_contentWidth > 0 && _contentHeight > 0) {
      // Debug: Print episode content length before pagination
      final contentLength = _displayEpisode.blocks.fold<int>(
        0,
        (sum, block) => sum + block.text.length,
      );
      debugPrint('EP${_displayEpisode.index} length = $contentLength');
      
      final newPages = _paginateEpisodeText(
        episode: _displayEpisode,
        style: _getTextStyle(),
        maxWidth: _contentWidth,
        maxHeight: _contentHeight,
      );
      
      if (mounted) {
        setState(() {
          final oldPageIndex = _currentPageIndex;
          _pages = newPages;
          // Try to preserve page position, or reset if invalid
          if (oldPageIndex < _pages.length) {
            _currentPageIndex = oldPageIndex;
            if (_pageController.hasClients) {
              _pageController.jumpToPage(_currentPageIndex);
            }
          } else if (_pages.isNotEmpty) {
            _currentPageIndex = 0;
            if (_pageController.hasClients) {
              _pageController.jumpToPage(0);
            }
          }
        });
      }
    }
  }

  void _onDimensionsReady(double width, double height) {
    if (!_dimensionsReady || _contentWidth != width || _contentHeight != height) {
      setState(() {
        _contentWidth = width;
        _contentHeight = height;
        _dimensionsReady = true;
      });
      _recalculatePages();
      
      // Restore saved page position after pages are calculated
      if (_currentPageIndex > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients && _currentPageIndex < _pages.length) {
            _pageController.jumpToPage(_currentPageIndex);
          }
        });
      }
    }
  }

  Color _getBackgroundColor() {
    switch (_theme) {
      case ReadingTheme.light:
        return Colors.white;
      case ReadingTheme.dark:
        return const Color(0xFF1E1E1E);
      case ReadingTheme.sepia:
        return const Color(0xFFF4E4BC);
    }
  }

  Color _getTextColor() {
    switch (_theme) {
      case ReadingTheme.light:
        return Colors.black87;
      case ReadingTheme.dark:
        return Colors.white;
      case ReadingTheme.sepia:
        return const Color(0xFF5C4A37);
    }
  }

  TextStyle _getTextStyle() {
    return TextStyle(
      fontSize: _fontSize.fontSize,
      height: _ReadingConstants.lineHeight,
      color: _getTextColor(),
      letterSpacing: _ReadingConstants.letterSpacing,
    );
  }

  double _getReadingProgress() {
    if (_pages.isEmpty) return 0.0;
    return (_currentPageIndex + 1) / _pages.length;
  }

  String _getProgressText() {
    if (_pages.isEmpty) return 'Episode ${widget.episode.index}';
    return 'Page ${_currentPageIndex + 1} / ${_pages.length} · Episode ${widget.episode.index}';
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBackgroundColor();
    final textColor = _getTextColor();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _theme == ReadingTheme.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Auto-hiding header
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: _isHeaderVisible ? 56 : 0,
                child: _isHeaderVisible
                    ? _ReaderHeader(
                        episodeNumber: widget.episode.index,
                        onBack: () => Navigator.pop(context),
                        onFontSize: _showFontSizeDialog,
                        onTheme: _showThemeDialog,
                        onShare: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Share feature coming soon')),
                          );
                        },
                        textColor: textColor,
                      )
                    : const SizedBox.shrink(),
              ),
              
              // Content area with pagination
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate available space for text
                    final headerHeight = _isHeaderVisible ? 56.0 : 0.0;
                    final progressBarHeight = 60.0;
                    final actionBarHeight = 80.0;
                    final availableHeight = constraints.maxHeight - 
                        headerHeight - progressBarHeight - actionBarHeight;
                    
                    final contentWidth = constraints.maxWidth - 
                        (_ReadingConstants.horizontalPadding * 2);
                    final contentHeight = availableHeight - 
                        (_ReadingConstants.verticalPadding * 2);
                    
                    // Notify when dimensions are ready
                    if (contentWidth > 0 && contentHeight > 0) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _onDimensionsReady(contentWidth, contentHeight);
                      });
                    }

                    return GestureDetector(
                      onTap: _onPageTap,
                      child: _buildContentArea(
                        backgroundColor: backgroundColor,
                        textColor: textColor,
                      ),
                    );
                  },
                ),
              ),

              // Error banner (if using mock data)
              if (_usingMockData)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No content available. Showing sample text for testing.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Bottom progress bar
              _ProgressBar(
                progress: _getReadingProgress(),
                progressText: _getProgressText(),
                textColor: textColor,
              ),

              // Bottom action bar (sticky)
              _BottomActionBar(
                onLearnNow: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Learn Now feature coming soon')),
                  );
                },
                onNextEpisode: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Next Episode feature coming soon')),
                  );
                },
                backgroundColor: backgroundColor,
                textColor: textColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the content area - ALWAYS shows text, never infinite spinner
  Widget _buildContentArea({
    required Color backgroundColor,
    required Color textColor,
  }) {
    // If pages are ready, show paginated content
    if (_pages.isNotEmpty) {
      return _PaginatedContent(
        pages: _pages,
        pageController: _pageController,
        textStyle: _getTextStyle(),
        backgroundColor: backgroundColor,
        textColor: textColor,
        onPageChanged: (index) {
          if (mounted) {
            setState(() => _currentPageIndex = index);
            _savePagePosition();
            _showHeaderTemporarily();
          }
        },
      );
    }

    // If dimensions not ready yet, show text directly (non-paginated) until pagination is ready
    // This ensures text is ALWAYS visible, never stuck on spinner
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: _ReadingConstants.horizontalPadding,
        vertical: _ReadingConstants.verticalPadding,
      ),
      child: Text(
        _getFullEpisodeText(),
        style: _getTextStyle(),
        textAlign: TextAlign.left,
      ),
    );
  }

  /// Get full episode text as a single string
  String _getFullEpisodeText() {
    final StringBuffer fullText = StringBuffer();
    for (final block in _displayEpisode.blocks) {
      if (block.type == BlockType.dialog && block.speaker != null && block.speaker!.isNotEmpty) {
        fullText.write('${block.speaker!}: ');
      }
      fullText.write(block.text);
      fullText.write('\n\n');
    }
    return fullText.toString().trim();
  }

  /// Paginate episode text into pages using TextPainter
  List<String> _paginateEpisodeText({
    required Episode episode,
    required TextStyle style,
    required double maxWidth,
    required double maxHeight,
  }) {
    if (maxWidth <= 0 || maxHeight <= 0) return [];

    final List<String> pages = [];
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    // Combine all episode blocks into a single text string
    final StringBuffer fullText = StringBuffer();
    for (final block in episode.blocks) {
      if (block.type == BlockType.dialog && block.speaker != null && block.speaker!.isNotEmpty) {
        fullText.write('${block.speaker!}: ');
      }
      fullText.write(block.text);
      fullText.write('\n\n');
    }

    final text = fullText.toString().trim();
    if (text.isEmpty) return [''];

    int currentIndex = 0;
    final textLength = text.length;

    while (currentIndex < textLength) {
      int pageEnd = currentIndex;
      int lastGoodBreak = currentIndex;

      // Find how much text fits on this page
      while (pageEnd < textLength) {
        // Find next word boundary
        int nextBreak = text.indexOf(' ', pageEnd);
        int nextNewline = text.indexOf('\n', pageEnd);
        
        int nextBoundary = nextBreak == -1 
            ? (nextNewline == -1 ? textLength : nextNewline)
            : (nextNewline == -1 ? nextBreak : (nextBreak < nextNewline ? nextBreak : nextNewline));
        
        if (nextBoundary == -1) nextBoundary = textLength;
        
        // Test if this chunk fits - use safe substring to prevent RangeError
        final safeEnd = (nextBoundary + 1).clamp(0, textLength);
        final testText = text.substring(currentIndex, safeEnd);
        textPainter.text = TextSpan(text: testText, style: style);
        textPainter.layout(maxWidth: maxWidth);

        if (textPainter.size.height <= maxHeight) {
          pageEnd = safeEnd;
          lastGoodBreak = pageEnd;
        } else {
          break;
        }
      }

      // If no good break found, force break
      if (lastGoodBreak == currentIndex) {
        int charCount = 1;
        while (charCount < 100 && currentIndex + charCount < textLength) {
          final safeEnd = (currentIndex + charCount).clamp(0, textLength);
          final testText = text.substring(currentIndex, safeEnd);
          textPainter.text = TextSpan(text: testText, style: style);
          textPainter.layout(maxWidth: maxWidth);
          
          if (textPainter.size.height > maxHeight) {
            break;
          }
          charCount++;
        }
        final safeBreak = (currentIndex + (charCount > 1 ? charCount - 1 : 1)).clamp(0, textLength);
        lastGoodBreak = safeBreak;
      }

      // Extract page text - use safe substring to prevent RangeError
      final safePageEnd = lastGoodBreak.clamp(0, textLength);
      final pageText = text.substring(currentIndex, safePageEnd).trim();
      if (pageText.isNotEmpty) {
        pages.add(pageText);
      }

      currentIndex = lastGoodBreak;
      
      // Skip whitespace
      while (currentIndex < textLength && 
             (text[currentIndex] == ' ' || text[currentIndex] == '\n')) {
        currentIndex++;
      }
    }

    // Ensure at least one page - use safe substring
    if (pages.isEmpty) {
      final safeText = text.trim();
      if (safeText.isNotEmpty) {
        pages.add(safeText);
      } else {
        pages.add(''); // Fallback to empty page if text is completely empty
      }
    }

    return pages;
  }
}

/// Header with controls
class _ReaderHeader extends StatelessWidget {
  final int episodeNumber;
  final VoidCallback onBack;
  final VoidCallback onFontSize;
  final VoidCallback onTheme;
  final VoidCallback onShare;
  final Color textColor;

  const _ReaderHeader({
    required this.episodeNumber,
    required this.onBack,
    required this.onFontSize,
    required this.onTheme,
    required this.onShare,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack,
            color: textColor,
          ),
          Expanded(
            child: Text(
              'Episode $episodeNumber',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: onFontSize,
            color: textColor,
            tooltip: 'Font size',
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            onPressed: onTheme,
            color: textColor,
            tooltip: 'Theme',
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: onShare,
            color: textColor,
            tooltip: 'Share',
          ),
        ],
      ),
    );
  }
}

/// Paginated reading content with horizontal PageView
class _PaginatedContent extends StatelessWidget {
  final List<String> pages;
  final PageController pageController;
  final TextStyle textStyle;
  final Color backgroundColor;
  final Color textColor;
  final ValueChanged<int> onPageChanged;

  const _PaginatedContent({
    required this.pages,
    required this.pageController,
    required this.textStyle,
    required this.backgroundColor,
    required this.textColor,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: pageController,
      onPageChanged: onPageChanged,
      itemCount: pages.length,
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: _ReadingConstants.horizontalPadding,
            vertical: _ReadingConstants.verticalPadding,
          ),
          color: backgroundColor,
          child: Text(
            pages[index],
            style: textStyle,
            textAlign: TextAlign.left,
          ),
        );
      },
    );
  }
}

/// Progress bar at bottom
class _ProgressBar extends StatelessWidget {
  final double progress;
  final String progressText;
  final Color textColor;

  const _ProgressBar({
    required this.progress,
    required this.progressText,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: textColor.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            progressText,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom action bar (sticky)
class _BottomActionBar extends StatelessWidget {
  final VoidCallback onLearnNow;
  final VoidCallback onNextEpisode;
  final Color backgroundColor;
  final Color textColor;

  const _BottomActionBar({
    required this.onLearnNow,
    required this.onNextEpisode,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onLearnNow,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Learn Now',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: onNextEpisode,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Next Episode',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Font size selector bottom sheet
class _FontSizeSelector extends StatelessWidget {
  final FontSize currentSize;
  final ValueChanged<FontSize> onSelected;

  const _FontSizeSelector({
    required this.currentSize,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Font Size',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: FontSize.values.map((size) {
              final isSelected = size == currentSize;
              return GestureDetector(
                onTap: () => onSelected(size),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    size.label,
                    style: TextStyle(
                      fontSize: size.fontSize,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black87,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Theme selector bottom sheet
class _ThemeSelector extends StatelessWidget {
  final ReadingTheme currentTheme;
  final ValueChanged<ReadingTheme> onSelected;

  const _ThemeSelector({
    required this.currentTheme,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Reading Theme',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 20),
          ...ReadingTheme.values.map((theme) {
            final isSelected = theme == currentTheme;
            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
              ),
              title: Text(theme.label),
              trailing: isSelected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () => onSelected(theme),
            );
          }),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/// Font size enum
enum FontSize {
  small('S', 16.0),
  medium('M', 18.0),
  large('L', 20.0),
  xlarge('XL', 22.0);

  final String label;
  final double fontSize;

  const FontSize(this.label, this.fontSize);
}

/// Reading theme enum
enum ReadingTheme {
  light('Light', Colors.white, Colors.black87),
  dark('Dark', const Color(0xFF1E1E1E), Colors.white),
  sepia('Sepia', const Color(0xFFF4E4BC), const Color(0xFF5C4A37));

  final String label;
  final Color backgroundColor;
  final Color textColor;

  const ReadingTheme(this.label, this.backgroundColor, this.textColor);
}
