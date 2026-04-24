class FinanceExpenseRecord {
  const FinanceExpenseRecord({
    required this.amount,
    required this.currencyCode,
    required this.category,
    required this.description,
    required this.dateLabel,
    required this.createdAtMillis,
  });

  final String amount;
  final String currencyCode;
  final String category;
  final String description;
  final String dateLabel;
  final int createdAtMillis;

  factory FinanceExpenseRecord.fromJson(Map<String, dynamic> json) {
    return FinanceExpenseRecord(
      amount: json['amount'] as String? ?? '0',
      currencyCode: json['currencyCode'] as String? ?? 'INR',
      category: json['category'] as String? ?? 'Other',
      description: json['description'] as String? ?? '',
      dateLabel: json['dateLabel'] as String? ?? '',
      createdAtMillis: (json['createdAtMillis'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'currencyCode': currencyCode,
      'category': category,
      'description': description,
      'dateLabel': dateLabel,
      'createdAtMillis': createdAtMillis,
    };
  }
}

class FinanceTransactionRecord {
  const FinanceTransactionRecord({
    required this.title,
    required this.dateLabel,
    required this.amount,
  });

  final String title;
  final String dateLabel;
  final String amount;

  FinanceTransactionRecord copyWith({
    String? title,
    String? dateLabel,
    String? amount,
  }) {
    return FinanceTransactionRecord(
      title: title ?? this.title,
      dateLabel: dateLabel ?? this.dateLabel,
      amount: amount ?? this.amount,
    );
  }

  factory FinanceTransactionRecord.fromJson(Map<String, dynamic> json) {
    return FinanceTransactionRecord(
      title: json['title'] as String? ?? '',
      dateLabel: json['dateLabel'] as String? ?? '',
      amount: json['amount'] as String? ?? '0',
    );
  }

  Map<String, dynamic> toJson() {
    return {'title': title, 'dateLabel': dateLabel, 'amount': amount};
  }
}

class FinancePersonRecord {
  const FinancePersonRecord({
    required this.name,
    required this.amount,
    required this.isOwed,
    required this.colorValue,
    required this.initials,
    required this.transactions,
  });

  final String name;
  final String amount;
  final bool isOwed;
  final int colorValue;
  final String initials;
  final List<FinanceTransactionRecord> transactions;

  FinancePersonRecord copyWith({
    String? name,
    String? amount,
    bool? isOwed,
    int? colorValue,
    String? initials,
    List<FinanceTransactionRecord>? transactions,
  }) {
    return FinancePersonRecord(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      isOwed: isOwed ?? this.isOwed,
      colorValue: colorValue ?? this.colorValue,
      initials: initials ?? this.initials,
      transactions: transactions ?? this.transactions,
    );
  }

  factory FinancePersonRecord.fromJson(Map<String, dynamic> json) {
    return FinancePersonRecord(
      name: json['name'] as String? ?? '',
      amount: json['amount'] as String? ?? '0',
      isOwed: json['isOwed'] as bool? ?? true,
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF5EB7F6,
      initials: json['initials'] as String? ?? '👤',
      transactions:
          (json['transactions'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(FinanceTransactionRecord.fromJson)
              .toList(growable: false) ??
          const <FinanceTransactionRecord>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'isOwed': isOwed,
      'colorValue': colorValue,
      'initials': initials,
      'transactions': transactions.map((e) => e.toJson()).toList(),
    };
  }
}

class FinanceSummaryRecord {
  const FinanceSummaryRecord({
    required this.todayExpenseAmount,
    required this.oweTotal,
    required this.getTotal,
    required this.people,
    required this.totalTransactions,
    required this.lastActivityLabel,
  });

  final String todayExpenseAmount;
  final String oweTotal;
  final String getTotal;
  final List<FinancePersonRecord> people;
  final int totalTransactions;
  final String lastActivityLabel;

  factory FinanceSummaryRecord.empty() {
    return const FinanceSummaryRecord(
      todayExpenseAmount: '0',
      oweTotal: '0',
      getTotal: '0',
      people: <FinancePersonRecord>[],
      totalTransactions: 0,
      lastActivityLabel: 'No activity yet',
    );
  }

  factory FinanceSummaryRecord.fromJson(Map<String, dynamic> json) {
    return FinanceSummaryRecord(
      todayExpenseAmount: json['todayExpenseAmount'] as String? ?? '0',
      oweTotal: json['oweTotal'] as String? ?? '0',
      getTotal: json['getTotal'] as String? ?? '0',
      people:
          (json['people'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(FinancePersonRecord.fromJson)
              .toList(growable: false) ??
          const <FinancePersonRecord>[],
      totalTransactions: (json['totalTransactions'] as num?)?.toInt() ?? 0,
      lastActivityLabel:
          json['lastActivityLabel'] as String? ?? 'No activity yet',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'todayExpenseAmount': todayExpenseAmount,
      'oweTotal': oweTotal,
      'getTotal': getTotal,
      'people': people.map((e) => e.toJson()).toList(),
      'totalTransactions': totalTransactions,
      'lastActivityLabel': lastActivityLabel,
    };
  }

  FinanceSummaryRecord copyWith({
    String? todayExpenseAmount,
    String? oweTotal,
    String? getTotal,
    List<FinancePersonRecord>? people,
    int? totalTransactions,
    String? lastActivityLabel,
  }) {
    return FinanceSummaryRecord(
      todayExpenseAmount: todayExpenseAmount ?? this.todayExpenseAmount,
      oweTotal: oweTotal ?? this.oweTotal,
      getTotal: getTotal ?? this.getTotal,
      people: people ?? this.people,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      lastActivityLabel: lastActivityLabel ?? this.lastActivityLabel,
    );
  }
}
