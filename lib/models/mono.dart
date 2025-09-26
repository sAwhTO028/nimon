import 'package:flutter/foundation.dart';

@immutable
class Mono {
  final String id;
  final String title;
  final String? coverUrl;
  final String jlptLevel; // N5..N1
  final String? writerName;
  final List<String> tags;
  final int likes;

  const Mono({
    required this.id,
    required this.title,
    this.coverUrl,
    required this.jlptLevel,
    this.writerName,
    required this.tags,
    required this.likes,
  });

  Mono copyWith({
    String? id,
    String? title,
    String? coverUrl,
    String? jlptLevel,
    String? writerName,
    List<String>? tags,
    int? likes,
  }) =>
      Mono(
        id: id ?? this.id,
        title: title ?? this.title,
        coverUrl: coverUrl ?? this.coverUrl,
        jlptLevel: jlptLevel ?? this.jlptLevel,
        writerName: writerName ?? this.writerName,
        tags: tags ?? this.tags,
        likes: likes ?? this.likes,
      );
}
