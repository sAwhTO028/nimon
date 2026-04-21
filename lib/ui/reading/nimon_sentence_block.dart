import 'package:flutter/material.dart';
import 'package:nimon/core/design_system/nimon_tokens.dart';
import 'package:nimon/ui/reading/nimon_furigana_preview_style.dart';
import 'package:nimon/ui/reading/nimon_ruby_text.dart';
import 'package:nimon/ui/reading/nimon_translation_text.dart';

/// Reusable reading sentence block:
/// - Japanese (with optional ruby per token)
/// - optional translation underneath
class NimonSentenceBlock extends StatelessWidget {
  final List<NimonRubyToken>? tokens;
  final String? plainJapanese;
  final String? translation;
  final bool showTranslation;
  final TextAlign textAlign;
  final EdgeInsetsGeometry? padding;

  const NimonSentenceBlock({
    super.key,
    this.tokens,
    this.plainJapanese,
    this.translation,
    this.showTranslation = true,
    this.textAlign = TextAlign.start,
    this.padding,
  }) : assert(tokens != null || plainJapanese != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = theme.space;

    final line = resolveNimonFuriganaLineStyle(
      context,
      theme,
      NimonFuriganaPreviewContext.reading,
    );
    final baseStyle = line.baseStyle;
    final rubyStyle = line.rubyStyle;

    final hasTranslation = (translation ?? '').trim().isNotEmpty;

    return Padding(
      padding: padding ?? EdgeInsets.symmetric(vertical: s.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tokens != null)
            NimonRubyText(
              tokens: tokens!,
              baseStyle: baseStyle,
              rubyStyle: rubyStyle,
              textAlign: textAlign,
            )
          else
            Text(
              plainJapanese!,
              style: baseStyle,
              textAlign: textAlign,
            ),
          if (showTranslation && hasTranslation)
            NimonTranslationText(text: translation!),
        ],
      ),
    );
  }
}

