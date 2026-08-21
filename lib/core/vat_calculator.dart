int calculateVatCents(int totalCents, double percent) {
  final rate = percent.clamp(0, 100).toDouble();
  if (totalCents <= 0 || rate <= 0) return 0;
  return (totalCents * rate / (100 + rate)).round();
}
