import 'package:flutter/material.dart';

/// Shared colors for quiz setup, play, and result — calm, warm-neutral + one accent.
abstract final class QuizFlowTheme {
  QuizFlowTheme._();

  static const ink = Color(0xFF1A1917);
  static const inkMuted = Color(0xFF5C5A55);
  static const pageBg = Color(0xFFF6F3EA);

  /// Primary CTA (Start Quiz, Next, See results, Retry).
  static const primary = Color(0xFF5E6D86);
  static const onPrimary = Color(0xFFFFFFFF);

  /// Secondary / outline actions (Back to Learn, cancel-style).
  static const secondaryFill = Color(0xFFFDFCF9);
  static const secondaryBorder = Color(0xFFD8D2C6);

  /// Correct / success — soft green.
  static const success = Color(0xFF5F8F72);
  static const successBg = Color(0xFFE9F3ED);
  static const successBorder = Color(0xFF8AB399);

  /// Wrong / error — muted coral.
  static const error = Color(0xFFB86F6A);
  static const errorBg = Color(0xFFF7EEED);
  static const errorBorder = Color(0xFFC99590);

  /// Progress bar (same family as primary, slightly lighter).
  static const progressFill = Color(0xFF7A8BA3);
}
