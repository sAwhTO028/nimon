import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/core/design_system/nimon_color_tokens.dart';
import 'package:nimon/core/settings/content_community.dart';
import 'package:nimon/core/settings/language_pair.dart';
import 'package:nimon/features/settings/presentation/providers/user_preferences_notifier.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';
import 'package:nimon/l10n/app_localizations.dart';

/// M11c: Settings shell (stores preferences; applying them is deferred).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(userPreferencesNotifierProvider.notifier).load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(authSessionProvider);
    final state = ref.watch(userPreferencesNotifierProvider);

    ref.listen(userPreferencesNotifierProvider, (prev, next) {
      final msg = next.errorMessage?.trim();
      if (msg == null || msg.isEmpty) return;
      if (prev?.errorMessage == next.errorMessage) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    });

    final tokens = Theme.of(context).extension<NimonColorTokens>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? NimonColorTokens.dark
            : NimonColorTokens.light);
    return Scaffold(
      backgroundColor: tokens.appBackground,
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        leading: const NimonBackButton(),
      ),
      body: switch (session) {
        AuthSessionAuthenticated() => _SettingsBody(state: state),
        _ => _SignInRequiredBody(onSignIn: () => context.go('/login')),
      },
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.state});

  final UserPreferencesState state;

  static String _appLocaleLabel(String code) => switch (code) {
        'system' => 'System',
        'en' => 'English',
        'ja' => '日本語',
        'my' => 'မြန်မာ',
        _ => 'System',
      };

  static String _contentLocaleLabel(String code) =>
      contentCommunityDisplayLabel(code);

  static String _learningLanguageLabel(String code) => switch (code) {
        'ja' => 'Japanese',
        _ => 'Japanese',
      };

  static String _themeModeLabel(String code) => switch (code) {
        'light' => 'Light',
        'dark' => 'Dark',
        _ => 'System',
      };

  static String _readingTextSizeLabel(AppLocalizations l10n, String code) =>
      switch (code) {
        'small' => l10n.settingsReadingTextSizeSmall,
        'large' => l10n.settingsReadingTextSizeLarge,
        _ => l10n.settingsReadingTextSizeStandard,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final prefs = state.prefs;
    final disabledWhileSaving = state.saving;

    return ListView(
      children: [
        _SectionHeader(title: l10n.settingsLanguageSection),
        ListTile(
          title: Text(l10n.settingsAppLanguage),
          subtitle: Text(_appLocaleLabel(prefs.appLocale)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: disabledWhileSaving
              ? null
              : () => _pickAppLanguage(context, ref, prefs.appLocale),
        ),
        ListTile(
          title: Text(l10n.settingsContentCommunity),
          subtitle: Text(_contentLocaleLabel(prefs.contentLocale)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: disabledWhileSaving
              ? null
              : () => _pickContentLocale(
                    context,
                    ref,
                    prefs.contentLocale,
                    prefs.learningLanguage,
                  ),
        ),
        ListTile(
          title: Text(l10n.settingsLearningLanguage),
          subtitle: Text(_learningLanguageLabel(prefs.learningLanguage)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: disabledWhileSaving
              ? null
              : () =>
                  _pickLearningLanguage(context, ref, prefs.learningLanguage),
        ),
        _SectionHeader(title: l10n.settingsReadingSection),
        ListTile(
          title: Text(l10n.settingsReadingTextSize),
          subtitle: Text(_readingTextSizeLabel(l10n, prefs.readingTextSize)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: disabledWhileSaving
              ? null
              : () => _pickReadingTextSize(
                    context,
                    ref,
                    prefs.readingTextSize,
                  ),
        ),
        SwitchListTile.adaptive(
          title: Text(l10n.settingsShowExplanationSentence),
          subtitle: Text(l10n.settingsShowExplanationSentenceSubtitle),
          value: prefs.showExplanations,
          onChanged: disabledWhileSaving
              ? null
              : (v) => ref
                  .read(userPreferencesNotifierProvider.notifier)
                  .updateShowExplanations(v),
        ),
        _SectionHeader(title: l10n.settingsAppearanceSection),
        ListTile(
          title: Text(l10n.settingsTheme),
          subtitle: Text(_themeModeLabel(prefs.themeMode)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: disabledWhileSaving
              ? null
              : () => _pickThemeMode(context, ref, prefs.themeMode),
        ),
        _SectionHeader(title: l10n.settingsAccountSection),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: Text(l10n.settingsEditProfile),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/profile/edit'),
        ),
        ListTile(
          leading: const Icon(Icons.logout_rounded),
          title: Text(l10n.settingsSignOut),
          subtitle: Text(l10n.settingsSignOutSubtitle),
          onTap: () async {
            final go = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.settingsSignOutDialogTitle),
                content: Text(l10n.settingsSignOutDialogBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l10n.settingsCancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l10n.settingsSignOut),
                  ),
                ],
              ),
            );
            if (go != true) return;
            await ref.read(authSessionProvider.notifier).logout();
            if (!context.mounted) return;
            context.go('/login');
          },
        ),
        _SectionHeader(title: l10n.settingsNotificationsSection),
        ListTile(
          leading: Icon(Icons.notifications_none_rounded),
          title: Text(l10n.settingsNotificationsSection),
          subtitle: Text(l10n.settingsComingSoon),
          enabled: false,
        ),
        _SectionHeader(title: l10n.settingsAboutSection),
        ListTile(
          leading: Icon(Icons.info_outline_rounded),
          title: Text(l10n.settingsAppVersion),
          subtitle: Text(l10n.settingsAppVersionPlaceholder),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _pickAppLanguage(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.settingsAppLanguage),
        children: [
          _radio(ctx,
              title: l10n.settingsSystem, value: 'system', group: current),
          _radio(ctx, title: l10n.settingsEnglish, value: 'en', group: current),
          _radio(ctx, title: '日本語', value: 'ja', group: current),
          _radio(ctx, title: 'မြန်မာ', value: 'my', group: current),
        ],
      ),
    );
    if (picked == null || picked == current) return;
    await ref
        .read(userPreferencesNotifierProvider.notifier)
        .updateAppLocale(picked);
  }

  Future<void> _pickContentLocale(
    BuildContext context,
    WidgetRef ref,
    String current,
    String learningLanguage,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.settingsContentCommunity),
        children: [
          _radio(ctx, title: l10n.settingsMyanmar, value: 'my', group: current),
          _radio(
            ctx,
            title: l10n.settingsInternationalEnglish,
            value: 'en',
            group: current,
          ),
          if (!isSameLanguagePair(
            contentLocale: 'ja',
            learningLanguage: learningLanguage,
          ))
            _radio(ctx,
                title: l10n.settingsJapanese, value: 'ja', group: current),
        ],
      ),
    );
    if (picked == null || picked == current) return;
    if (isSameLanguagePair(
      contentLocale: picked,
      learningLanguage: learningLanguage,
    )) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(languagePairBlockedMessage())),
        );
      }
      return;
    }
    await ref
        .read(userPreferencesNotifierProvider.notifier)
        .updateContentLocale(picked);
  }

  Future<void> _pickLearningLanguage(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.settingsLearningLanguage),
        children: [
          _radio(ctx,
              title: l10n.settingsJapanese, value: 'ja', group: current),
          ListTile(
            title: const Text('More languages'),
            subtitle: Text(l10n.settingsComingSoon),
            enabled: false,
          ),
        ],
      ),
    );
    if (picked == null || picked == current) return;
    await ref
        .read(userPreferencesNotifierProvider.notifier)
        .updateLearningLanguage(picked);
  }

  Future<void> _pickReadingTextSize(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.settingsReadingTextSize),
        children: [
          _radio(ctx,
              title: l10n.settingsReadingTextSizeSmall,
              value: 'small',
              group: current),
          _radio(
            ctx,
            title: l10n.settingsReadingTextSizeStandard,
            value: 'standard',
            group: current,
          ),
          _radio(ctx,
              title: l10n.settingsReadingTextSizeLarge,
              value: 'large',
              group: current),
        ],
      ),
    );
    if (picked == null || picked == current) return;
    await ref
        .read(userPreferencesNotifierProvider.notifier)
        .updateReadingTextSize(picked);
  }

  Future<void> _pickThemeMode(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.settingsTheme),
        children: [
          _radio(ctx,
              title: l10n.settingsSystem, value: 'system', group: current),
          _radio(ctx, title: 'Light', value: 'light', group: current),
          _radio(ctx, title: 'Dark', value: 'dark', group: current),
        ],
      ),
    );
    if (picked == null || picked == current) return;
    await ref
        .read(userPreferencesNotifierProvider.notifier)
        .updateThemeMode(picked);
  }

  Widget _radio(
    BuildContext ctx, {
    required String title,
    required String value,
    required String group,
  }) {
    return RadioListTile<String>(
      title: Text(title),
      value: value,
      groupValue: group,
      onChanged: (v) => Navigator.pop(ctx, v),
    );
  }
}

class _SignInRequiredBody extends StatelessWidget {
  const _SignInRequiredBody({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 34),
            const SizedBox(height: 12),
            Text(
              l10n.settingsSignInRequiredTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsSignInRequiredBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onSignIn,
              child: Text(l10n.settingsSignInCta),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
