import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/l10n/app_localizations.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:nimon/features/profile/share_public_profile_url.dart';

/// Route [extra] for [`/profile/share`].
class ShareProfileScreenArgs {
  const ShareProfileScreenArgs({
    required this.displayName,
    required this.handleLine,
    this.avatarUrl,
    this.userId,
    this.explicitShareUrl,
  });

  final String displayName;

  /// Raw handle from profile (may or may not include `@`).
  final String handleLine;
  final String? avatarUrl;
  final String? userId;
  final String? explicitShareUrl;
}

/// V1 utility-first share profile screen (M17M).
class ShareProfileScreen extends StatelessWidget {
  const ShareProfileScreen({
    super.key,
    required this.displayName,
    required this.handleLine,
    required this.publicProfileUrl,
    this.avatarUrl,
  });

  final String displayName;
  final String handleLine;

  /// Full HTTPS (or LAN) URL used for copy, share, and QR.
  final String publicProfileUrl;
  final String? avatarUrl;

  String _displayNameResolved(AppLocalizations l10n) {
    final t = displayName.trim();
    if (t.isNotEmpty) return t;
    return l10n.shareProfileFallbackDisplayName;
  }

  String? _handleAtForm() {
    var h = handleLine.trim();
    if (h.isEmpty) return null;
    if (!h.startsWith('@')) h = '@$h';
    return h;
  }

  String _urlTrimmed() => publicProfileUrl.trim();

  bool get _hasShareableUrl => _urlTrimmed().isNotEmpty;

  Future<void> _copyLink(BuildContext context, AppLocalizations l10n) async {
    final url = _urlTrimmed();
    if (url.isEmpty) return;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.shareProfileLinkCopied),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    await Clipboard.setData(ClipboardData(text: url));
  }

  Future<void> _shareProfile(BuildContext context) async {
    final url = _urlTrimmed();
    if (url.isEmpty) return;
    await Share.share(url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final name = _displayNameResolved(l10n);
    final handleAt = _handleAtForm();
    final url = _urlTrimmed();
    final shortLabel = url.isNotEmpty ? shortPublicProfileLinkLabel(url) : '';
    final canAct = _hasShareableUrl;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: NimonBackButton(
          onPressed: () => context.pop(),
          icon: Icons.close_rounded,
          tooltip: MaterialLocalizations.of(context).closeButtonLabel,
        ),
        centerTitle: true,
        title: Text(
          l10n.shareProfileTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: scheme.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.65),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      child: Column(
                        children: [
                          _ShareAvatar(
                            avatarUrl: avatarUrl,
                            diameter: 56,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: scheme.onSurface,
                            ),
                          ),
                          if (handleAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              handleAt,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (shortLabel.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            SelectableText(
                              shortLabel,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: canAct ? () => _copyLink(context, l10n) : null,
                    child: Text(l10n.shareProfileCopyLink),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: canAct ? () => _shareProfile(context) : null,
                    child: Text(l10n.shareProfileShareProfile),
                  ),
                  if (!canAct) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.shareProfileLinkUnavailable,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (canAct) ...[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.65),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ColoredBox(
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: QrImageView(
                                    key: ValueKey<String>(
                                        'share_profile_qr_$url'),
                                    data: url,
                                    version: QrVersions.auto,
                                    size: 168,
                                    backgroundColor: Colors.white,
                                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.shareProfileScanToOpen,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    l10n.shareProfilePublicHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
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

class _ShareAvatar extends StatelessWidget {
  const _ShareAvatar({
    required this.avatarUrl,
    required this.diameter,
  });

  final String? avatarUrl;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = (avatarUrl ?? '').trim();
    if (url.isEmpty) {
      return CircleAvatar(
        radius: diameter / 2,
        backgroundColor: scheme.surfaceContainerHighest,
        child: Icon(
          Icons.person_rounded,
          color: scheme.onSurfaceVariant,
          size: diameter * 0.45,
        ),
      );
    }
    return CircleAvatar(
      radius: diameter / 2,
      backgroundColor: scheme.surfaceContainerHighest,
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (_, __) {},
      child: null,
    );
  }
}
