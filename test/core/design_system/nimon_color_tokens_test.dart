import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/design_system/nimon_color_tokens.dart';

void main() {
  group('M11k NimonColorTokens light', () {
    test('official palette', () {
      const l = NimonColorTokens.light;
      expect(l.appBackground, const Color(0xFFF6F8FB));
      expect(l.surface, const Color(0xFFDFE6EE));
      expect(l.border, const Color(0xFFB8C2CE));
      expect(l.textSecondary, const Color(0xFF7A8796));
      expect(l.textPrimary, const Color(0xFF3B4450));
      expect(l.actionPrimary, const Color(0xFF3B4450));
      expect(l.disabled, const Color(0xFFB8C2CE));
      expect(l.success, const Color(0xFF6F9F8B));
      expect(l.warning, const Color(0xFFB89A5E));
      expect(l.error, const Color(0xFFB86B6B));
      expect(l.info, const Color(0xFF6F8FA8));
      expect(l.react, const Color(0xFFC76B6B));
    });
  });

  group('M11k NimonColorTokens dark', () {
    test('official palette', () {
      const d = NimonColorTokens.dark;
      expect(d.appBackground, const Color(0xFF1F2630));
      expect(d.surface, const Color(0xFF2A3440));
      expect(d.border, const Color(0xFF4D5A69));
      expect(d.textSecondary, const Color(0xFFA8B4C2));
      expect(d.textPrimary, const Color(0xFFE8EDF3));
      expect(d.actionPrimary, const Color(0xFFE8EDF3));
      expect(d.disabled, const Color(0xFF4D5A69));
      expect(d.success, const Color(0xFF8FBFA5));
      expect(d.warning, const Color(0xFFC7AE7A));
      expect(d.error, const Color(0xFFC98484));
      expect(d.info, const Color(0xFF8FAFCB));
      expect(d.react, const Color(0xFFC98484));
    });
  });
}
