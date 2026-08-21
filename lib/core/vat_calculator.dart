int calculateVatCents(int taxableCents, double percent) {
  final rate = percent.clamp(0, 100).toDouble();
  if (taxableCents <= 0 || rate <= 0) return 0;
  return (taxableCents * rate / 100).round();
}
