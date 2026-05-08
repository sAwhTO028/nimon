import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';

/// V1 share-profile screen (lightweight, backend-agnostic).
class ShareProfileScreen extends StatelessWidget {
  const ShareProfileScreen({
    super.key,
    required this.displayName,
    required this.handle,
    required this.publicProfileUrl,
  });

  final String displayName;
  final String handle;
  final String publicProfileUrl;

  String get _safeName =>
      displayName.trim().isEmpty ? 'Just4withYou' : displayName.trim();
  String get _safeHandle =>
      handle.trim().isEmpty ? '@just4withyou' : handle.trim();
  String get _safeUrl => publicProfileUrl.trim().isEmpty
      ? 'https://nimon.app/u/just4withyou'
      : publicProfileUrl.trim();

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _safeUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile link copied'),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareV1(BuildContext context) async {
    // V1 lightweight: we copy and acknowledge. (Hook up share_plus later.)
    await _copyLink(context);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sharing UI coming soon'),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: NimonBackButton(
          onPressed: () => context.pop(),
          icon: Icons.close_rounded,
          tooltip: 'Close',
        ),
        centerTitle: true,
        title: Text(
          'Share Profile',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Material(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.65),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: scheme.surface,
                              child: Icon(
                                Icons.person_rounded,
                                color: scheme.onSurfaceVariant,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _safeName,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _safeHandle,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _QrPlaceholder(
                              size: 212,
                              bg: scheme.surface,
                              ink: scheme.onSurface,
                              border: scheme.outlineVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Scan to open profile',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _shareV1(context),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Share'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copyLink(context),
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Copy link'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Download coming soon'),
                      behavior: SnackBarBehavior.floating,
                      margin: EdgeInsets.all(16),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download card'),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                _safeUrl,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder({
    required this.size,
    required this.bg,
    required this.ink,
    required this.border,
  });

  final double size;
  final Color bg;
  final Color ink;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border.withValues(alpha: 0.7)),
      ),
      child: CustomPaint(
        painter: _FakeQrPainter(ink: ink.withValues(alpha: 0.88)),
      ),
    );
  }
}

class _FakeQrPainter extends CustomPainter {
  const _FakeQrPainter({required this.ink});

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = ink;
    final w = size.width;
    final cell = w / 29.0;

    void block(int x, int y, int s) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x * cell, y * cell, s * cell, s * cell),
          Radius.circular(cell * 0.6),
        ),
        p,
      );
    }

    // Corner markers
    block(2, 2, 7);
    block(4, 4, 3);
    block(20, 2, 7);
    block(22, 4, 3);
    block(2, 20, 7);
    block(4, 22, 3);

    // Light random-ish pattern (deterministic by coordinates)
    for (int y = 0; y < 29; y++) {
      for (int x = 0; x < 29; x++) {
        final inFinder = (x >= 2 && x <= 8 && y >= 2 && y <= 8) ||
            (x >= 20 && x <= 26 && y >= 2 && y <= 8) ||
            (x >= 2 && x <= 8 && y >= 20 && y <= 26);
        if (inFinder) continue;
        final v = (x * 17 + y * 23 + (x ^ y) * 11) % 13;
        if (v == 0 || v == 4 || v == 9) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell, cell),
            p,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FakeQrPainter oldDelegate) =>
      oldDelegate.ink != ink;
}
