class CurrencyPreference {
  const CurrencyPreference({
    required this.code,
    required this.symbol,
    required this.name,
  });

  final String code;
  final String symbol;
  final String name;

  static const CurrencyPreference defaultPreference = CurrencyPreference(
    code: 'INR',
    symbol: '₹',
    name: 'Indian Rupee',
  );

  String get displayLabel => '$symbol $code';

  factory CurrencyPreference.fromJson(Map<String, dynamic> json) {
    final code = json['currencyCode'] as String? ?? defaultPreference.code;
    final symbol =
        json['currencySymbol'] as String? ?? defaultPreference.symbol;
    final name = json['currencyName'] as String? ?? defaultPreference.name;
    return CurrencyPreference(code: code, symbol: symbol, name: name);
  }

  Map<String, dynamic> toJson() {
    return {
      'currencyCode': code,
      'currencySymbol': symbol,
      'currencyName': name,
    };
  }
}

const List<CurrencyPreference> supportedCurrencyPreferences =
    <CurrencyPreference>[
      CurrencyPreference(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
      CurrencyPreference(code: 'USD', symbol: '\$', name: 'US Dollar'),
      CurrencyPreference(code: 'EUR', symbol: '€', name: 'Euro'),
      CurrencyPreference(code: 'GBP', symbol: '£', name: 'British Pound'),
      CurrencyPreference(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar'),
      CurrencyPreference(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar'),
      CurrencyPreference(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
      CurrencyPreference(code: 'CHF', symbol: 'CHF', name: 'Swiss Franc'),
    ];

CurrencyPreference currencyPreferenceForCode(String code) {
  return supportedCurrencyPreferences.firstWhere(
    (option) => option.code == code,
    orElse: () => CurrencyPreference.defaultPreference,
  );
}
