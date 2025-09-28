class CommDims {
  static const double vPad = 12;
  static const double headerH = 106;
  static const double rowH = 56;
  static const double rowGap = 8;
  static const int rows = 3;
  
  static double cardHeight() => headerH + rows * rowH + (rows - 1) * rowGap + 2 * vPad;
}
