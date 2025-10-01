import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/challenges.dart';
import '../widgets/challenge_card.dart';

class ReadingChallengesSection extends StatelessWidget {
  const ReadingChallengesSection({super.key, this.onSelect});

  final void Function(ReadingChallenge)? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Split list into pages
    List<List<ReadingChallenge>> chunk(List<ReadingChallenge> src, int n) {
      final out = <List<ReadingChallenge>>[];
      for (var i = 0; i < src.length; i += n) {
        out.add(src.sublist(i, math.min(i + n, src.length)));
      }
      return out;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.sizeOf(context);
        final isLandscape = size.width > size.height;

        // ---- Responsive knobs ----
        final cols = isLandscape ? 3 : 2;
        final rows = isLandscape ? 1 : 2;
        final itemsPerPage = cols * rows;

        // carousel feel
        final viewportFraction = isLandscape ? 0.78 : 0.86;
        const double crossGap = 12;
        const double mainGap = 12;
        const double hPad = 16;

        // child aspect (w/h) — cards have title+subtitle so ~1.45–1.6 works
        final double childAspectRatio = isLandscape ? 1.75 : 1.5;

        // width math
        final screenW = size.width;
        final viewportW = screenW * viewportFraction;
        final gridW = viewportW - (cols - 1) * crossGap;
        final tileW = gridW / cols;

        // Height budget:
        // clamp grid to a fraction of screen height so it never eats bottom bar.
        final maxGridHeight = size.height * (isLandscape ? 0.34 : 0.32);

        // safe caps
        final idealTileH = tileW / childAspectRatio;
        final idealGridH = rows * idealTileH + (rows - 1) * mainGap;
        final gridH = math.min(idealGridH, maxGridHeight);

        // recompute ratio if we were capped, to keep cells proportional
        final recomputedTileH = (gridH - (rows - 1) * mainGap) / rows;
        final effectiveChildAspect = tileW / recomputedTileH;

        final pages = chunk(challenges, itemsPerPage);

        return Padding(
          padding: const EdgeInsets.only(left: hPad, top: 8, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reading Challenges',
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: gridH,
                child: PageView.builder(
                  controller: PageController(viewportFraction: viewportFraction),
                  padEnds: false,
                  itemCount: pages.length,
                  itemBuilder: (context, pageIndex) {
                    final items = pages[pageIndex];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: crossGap,
                          mainAxisSpacing: mainGap,
                          childAspectRatio: effectiveChildAspect,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final m = items[i];
                          return ChallengeCard(
                            model: m,
                            onTap: () => onSelect?.call(m),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
