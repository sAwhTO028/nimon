import 'package:flutter/material.dart';
import 'package:nimon/ui/widgets/nimon_circle_nav_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nimon/features/learn/learn_explanation_language.dart';
import 'package:nimon/features/learn/learn_explanation_language_provider.dart';
import 'package:nimon/features/auth/auth_providers.dart';
import 'package:nimon/features/auth/auth_session_state.dart';
import 'package:nimon/features/settings/settings_providers.dart';
import 'package:nimon/core/design_system/nimon_layout.dart';
import 'package:nimon/core/design_system/nimon_tokens.dart';
import 'package:nimon/core/design_system/nimon_typography.dart';
import 'package:nimon/core/design_system/nimon_breakpoints.dart';

/// V1 Settings: General, Learning, Support — lightweight grouped layout.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static String _themeLabel(ThemeMode m) => switch (m) {
        ThemeMode.system => 'System default',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  static String _localeLabel(Locale? l) {
    if (l == null) return 'System default';
    if (l.languageCode == 'ja') return '日本語';
    return 'English';
  }

  static String _learnLanguageLabel(LearnExplanationLanguage v) => switch (v) {
        LearnExplanationLanguage.english => 'English',
        LearnExplanationLanguage.myanmar => 'Myanmar',
      };

  static String _readingLabel(String id) => switch (id) {
        'small' => 'Small',
        'large' => 'Large',
        _ => 'Standard',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = theme.space;
    final wc = context.widthClass;
    final themeMode = ref.watch(themeModeSettingProvider);
    final appLocale = ref.watch(appLocaleSettingProvider);
    final notificationsEnabled = ref.watch(notificationsEnabledSettingProvider);
    final readingScale = ref.watch(readingTextScaleSettingProvider);
    final readingId = readingScale <= 0.94
        ? 'small'
        : readingScale >= 1.08
            ? 'large'
            : 'standard';
    final learnLang = ref.watch(learnExplanationLanguageProvider);
    final authSession = ref.watch(authSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: const NimonBackButton(),
      ),
      body: NimonReadingColumn.wrap(
        context,
        ListView(
          children: [
            _SectionHeader(title: 'General'),
            ListTile(
              title: const Text('Account'),
              subtitle: Text(
                switch (authSession) {
                  AuthSessionAuthenticated(:final user) =>
                    user.email ?? user.id,
                  _ => 'Not signed in',
                },
              ),
              leading: Icon(
                Icons.account_circle_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            ListTile(
              title: const Text('App language'),
              subtitle: Text(_localeLabel(appLocale)),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              onTap: () => _pickAppLanguage(context, ref),
            ),
            ListTile(
              title: const Text('Theme'),
              subtitle: Text(_themeLabel(themeMode)),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              onTap: () => _pickTheme(context, ref),
            ),
            SwitchListTile.adaptive(
              value: notificationsEnabled,
              onChanged: (v) {
                ref
                    .read(notificationsEnabledSettingProvider.notifier)
                    .setEnabled(v);
              },
              title: const Text('Push notifications'),
              subtitle: const Text('Turn push notifications on or off'),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: s.x4, vertical: 2),
            ),
            SizedBox(height: s.x2),
            _SectionHeader(title: 'Learning'),
            ListTile(
              title: const Text('Learn language'),
              subtitle: Text(
                'Explanations and support text: ${_learnLanguageLabel(learnLang)}',
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              onTap: () => _pickLearnLanguage(context, ref),
            ),
            ListTile(
              title: const Text('Reading text size'),
              subtitle: Text(
                'Applies across reading surfaces: ${_readingLabel(readingId)}',
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              onTap: () => _pickReadingSize(context, ref),
            ),
            SwitchListTile.adaptive(
              value: ref.watch(monoExplanationEnabledSettingProvider),
              onChanged: (v) {
                ref
                    .read(monoExplanationEnabledSettingProvider.notifier)
                    .setEnabled(v);
              },
              title: const Text('Listening explanation sentence'),
              subtitle: const Text(
                'Show explanation lines in Listening / Pronunciation',
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: s.x4, vertical: 2),
            ),
            SwitchListTile.adaptive(
              value: ref.watch(monoReaderTranslationEnabledProvider),
              onChanged: (v) {
                ref
                    .read(monoReaderTranslationEnabledProvider.notifier)
                    .setEnabled(v);
              },
              title: const Text('Show Mono translations'),
              subtitle: const Text(
                'Show source and English meanings under each Japanese line on the Mono reader',
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: s.x4, vertical: 2),
            ),
            SizedBox(height: s.x2),
            _SectionHeader(title: 'Support'),
            ListTile(
              leading: Icon(
                Icons.help_outline_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: const Text('Help / Feedback'),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              onTap: () => context.push('/settings/help'),
            ),
            SizedBox(height: wc == NimonWidthClass.compact ? s.x6 : s.x8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAppLanguage(BuildContext context, WidgetRef ref) async {
    final current = ref.read(appLocaleSettingProvider);
    final currentCode = current == null
        ? 'system'
        : (current.languageCode == 'ja' ? 'ja' : 'en');
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('App language'),
          children: [
            RadioListTile<String>(
              title: const Text('System default'),
              value: 'system',
              groupValue: currentCode,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: currentCode,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            RadioListTile<String>(
              title: const Text('日本語'),
              subtitle: Text(
                'UI may still be mostly English in V1',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
              value: 'ja',
              groupValue: currentCode,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
          ],
        );
      },
    );
    if (code == null) return;
    if (code == 'system') {
      await ref.read(appLocaleSettingProvider.notifier).setLocale(null);
    } else if (code == 'en') {
      await ref.read(appLocaleSettingProvider.notifier).setLocale(
            const Locale('en'),
          );
    } else if (code == 'ja') {
      await ref.read(appLocaleSettingProvider.notifier).setLocale(
            const Locale('ja'),
          );
    }
  }

  Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    final current = ref.read(themeModeSettingProvider);
    final picked = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('Theme'),
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('System default'),
              value: ThemeMode.system,
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
          ],
        );
      },
    );
    if (picked != null) {
      await ref.read(themeModeSettingProvider.notifier).setThemeMode(picked);
    }
  }

  Future<void> _pickLearnLanguage(BuildContext context, WidgetRef ref) async {
    final current = ref.read(learnExplanationLanguageProvider);
    final picked = await showDialog<LearnExplanationLanguage>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('Learn language'),
          children: [
            RadioListTile<LearnExplanationLanguage>(
              title: const Text('English'),
              value: LearnExplanationLanguage.english,
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            RadioListTile<LearnExplanationLanguage>(
              title: const Text('Myanmar'),
              value: LearnExplanationLanguage.myanmar,
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
          ],
        );
      },
    );
    if (picked != null) {
      await ref
          .read(learnExplanationLanguageProvider.notifier)
          .setLanguage(picked);
    }
  }

  Future<void> _pickReadingSize(BuildContext context, WidgetRef ref) async {
    final scale = ref.read(readingTextScaleSettingProvider);
    final current = scale <= 0.94
        ? 'small'
        : scale >= 1.08
            ? 'large'
            : 'standard';
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('Reading text size'),
          children: [
            RadioListTile<String>(
              title: const Text('Small'),
              value: 'small',
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            RadioListTile<String>(
              title: const Text('Standard'),
              value: 'standard',
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            RadioListTile<String>(
              title: const Text('Large'),
              value: 'large',
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
          ],
        );
      },
    );
    if (picked != null) {
      await ref
          .read(readingTextScaleSettingProvider.notifier)
          .setFromSizeId(picked);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = theme.space;
    final wc = context.widthClass;
    return Padding(
      padding: EdgeInsets.fromLTRB(s.x5, s.x5, s.x5, s.x2),
      child: Text(
        title.toUpperCase(),
        style: theme.type.metadata(theme, wc).copyWith(
              letterSpacing: 0.7,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
