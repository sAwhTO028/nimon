import 'package:flutter/material.dart';

class ReadingChallenge {
  final String emoji;
  final String title;
  final String subtitle;
  final Color bg;
  final Color fg;

  const ReadingChallenge({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.bg,
    required this.fg,
  });
}

/// Seed challenges (feel free to tweak colors to your theme)
const challenges = <ReadingChallenge>[
  ReadingChallenge(
    emoji: '❤️',
    title: 'Love',
    subtitle: 'Romance & bonding',
    bg: Color(0xFFFFE3EC),
    fg: Color(0xFF7A1E45),
  ),
  ReadingChallenge(
    emoji: '😂',
    title: 'Comedy',
    subtitle: 'Light & funny',
    bg: Color(0xFFE9F2FF),
    fg: Color(0xFF123A7A),
  ),
  ReadingChallenge(
    emoji: '👻',
    title: 'Horror',
    subtitle: 'Ghosts & thrills',
    bg: Color(0xFFFFECE3),
    fg: Color(0xFF6E1B11),
  ),
  ReadingChallenge(
    emoji: '🏯',
    title: 'Cultural',
    subtitle: 'Traditions & festivals',
    bg: Color(0xFFEFF7F1),
    fg: Color(0xFF0A5730),
  ),
  ReadingChallenge(
    emoji: '🗺️',
    title: 'Adventure',
    subtitle: 'Explore & discover',
    bg: Color(0xFFEFF6FF),
    fg: Color(0xFF123D6B),
  ),
  ReadingChallenge(
    emoji: '🧙',
    title: 'Fantasy',
    subtitle: 'Magic & myths',
    bg: Color(0xFFF3ECFF),
    fg: Color(0xFF442B7A),
  ),
  ReadingChallenge(
    emoji: '🎭',
    title: 'Drama',
    subtitle: 'Life & conflicts',
    bg: Color(0xFFFFF4E5),
    fg: Color(0xFF7A4B00),
  ),
  ReadingChallenge(
    emoji: '💼📖',
    title: 'Business / Learning',
    subtitle: 'Biz JP & study',
    bg: Color(0xFFE9FBFF),
    fg: Color(0xFF094A5A),
  ),
  ReadingChallenge(
    emoji: '🚀🤖',
    title: 'Sci-Fi / Tech',
    subtitle: 'Future & science',
    bg: Color(0xFFEAF3FF),
    fg: Color(0xFF0E3B8A),
  ),
  ReadingChallenge(
    emoji: '🔎',
    title: 'Mystery',
    subtitle: 'Detective & suspense',
    bg: Color(0xFFF6F0FF),
    fg: Color(0xFF3F2468),
  ),
];
