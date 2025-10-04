import 'package:flutter/foundation.dart';

@immutable
class OneShot {
  final String id;
  final String title;
  final String? coverUrl;
  final String writerName;
  final String jlpt; // "N5".."N1"
  final int likes;
  final int monoNo; // display as Mono# in band

  const OneShot({
    required this.id,
    required this.title,
    this.coverUrl,
    required this.writerName,
    required this.jlpt,
    required this.likes,
    required this.monoNo,
  });

  OneShot copyWith({
    String? id,
    String? title,
    String? coverUrl,
    String? writerName,
    String? jlpt,
    int? likes,
    int? monoNo,
  }) =>
      OneShot(
        id: id ?? this.id,
        title: title ?? this.title,
        coverUrl: coverUrl ?? this.coverUrl,
        writerName: writerName ?? this.writerName,
        jlpt: jlpt ?? this.jlpt,
        likes: likes ?? this.likes,
        monoNo: monoNo ?? this.monoNo,
      );
}
