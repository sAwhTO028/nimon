import 'package:flutter/material.dart';
class R {
  static EdgeInsets hPad(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    if (w >= 1024) return EdgeInsets.symmetric(horizontal: (w - 960) / 2 + 24);
    if (w >= 600) return const EdgeInsets.symmetric(horizontal: 24);
    return const EdgeInsets.symmetric(horizontal: 16);
  }
  static BorderRadius radius(BuildContext c) => BorderRadius.circular(16);
}
