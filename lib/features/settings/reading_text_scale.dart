/// Maps persisted `readingTextSize` (small | standard | large) to a linear scale factor.
double readingTextLinearScale(String readingTextSize) {
  switch (readingTextSize.trim().toLowerCase()) {
    case 'small':
      return 0.92;
    case 'large':
      return 1.12;
    default:
      return 1.0;
  }
}
