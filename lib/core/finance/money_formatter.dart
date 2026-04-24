String extractMoneyValue(String value) {
  final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) {
    return '0';
  }
  return cleaned;
}

double parseMoneyValue(String value) {
  return double.tryParse(extractMoneyValue(value)) ?? 0;
}

String formatMoney(String value, String symbol) {
  return formatMoneyFromNumber(parseMoneyValue(value), symbol);
}

String formatMoneyFromNumber(num value, String symbol) {
  final amount = value.toDouble();
  final rounded = amount.roundToDouble();
  final numericText = amount == rounded
      ? rounded.toInt().toString()
      : amount.toStringAsFixed(2);
  return '$symbol$numericText';
}
