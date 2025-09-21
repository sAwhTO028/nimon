import 'package:flutter/material.dart';

class R {
  static bool phone(BuildContext c) => MediaQuery.sizeOf(c).shortestSide < 600;
  static bool tablet(BuildContext c) =>
      MediaQuery.sizeOf(c).shortestSide >= 600 &&
          MediaQuery.sizeOf(c).shortestSide < 1024;
  static bool desktop(BuildContext c) =>
      MediaQuery.sizeOf(c).shortestSide >= 1024;

  static double maxTextWidth(BuildContext c) =>
      tablet(c) || desktop(c) ? 760 : MediaQuery.sizeOf(c).width;

  static EdgeInsets hPad(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    if (desktop(c)) return EdgeInsets.symmetric(horizontal: (w - 960) / 2 + 24);
    if (tablet(c)) return const EdgeInsets.symmetric(horizontal: 24);
    return const EdgeInsets.symmetric(horizontal: 16);
  }

  static BorderRadius radius(BuildContext c) =>
      BorderRadius.circular(phone(c) ? 14 : 18);
}
