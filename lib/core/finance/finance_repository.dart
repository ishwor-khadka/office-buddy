import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../firebase/firebase_bootstrap.dart';
import '../settings/currency_preference_repository.dart';
import 'finance_models.dart';
import 'money_formatter.dart';

class FinanceRepository {
  static const _collectionPath = 'users';
  static const _financeDocId = 'finance';
  static const _expensesCollectionId = 'expenses';
  final CurrencyPreferenceRepository _currencyRepository =
      CurrencyPreferenceRepository();

  Future<FinanceSummaryRecord> loadSummary() async {
    final currency = await _currencyRepository.load();
    return _loadSummaryWithSymbol(currency.symbol);
  }

  Future<FinanceSummaryRecord> _loadSummaryWithSymbol(String symbol) async {
    final firestore = FirebaseBootstrap.firestoreOrNull;
    final user = FirebaseBootstrap.authOrNull?.currentUser;
    if (firestore == null || user == null) {
      return _applyCurrency(FinanceSummaryRecord.empty(), symbol);
    }

    final snapshot = await firestore
        .collection(_collectionPath)
        .doc(user.uid)
        .collection('settings')
        .doc(_financeDocId)
        .get();

    if (!snapshot.exists || snapshot.data() == null) {
      return _applyCurrency(FinanceSummaryRecord.empty(), symbol);
    }

    return _applyCurrency(
      FinanceSummaryRecord.fromJson(snapshot.data()!),
      symbol,
    );
  }

  Future<void> saveSummary(FinanceSummaryRecord summary) async {
    final firestore = FirebaseBootstrap.firestoreOrNull;
    final user = FirebaseBootstrap.authOrNull?.currentUser;
    if (firestore == null || user == null) return;

    await firestore
        .collection(_collectionPath)
        .doc(user.uid)
        .collection('settings')
        .doc(_financeDocId)
        .set({
          ...summary.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> upsertPerson(FinancePersonRecord person) async {
    final currency = await _currencyRepository.load();
    final summary = await _loadSummaryWithSymbol(currency.symbol);
    final updatedPeople = [...summary.people];
    final index = updatedPeople.indexWhere((item) => item.name == person.name);
    if (index >= 0) {
      updatedPeople[index] = person;
    } else {
      updatedPeople.add(person);
    }

    final transactions = updatedPeople
        .expand((item) => item.transactions)
        .length;
    final oweTotal = formatMoneyFromNumber(
      _sumAmounts(
        updatedPeople.where((item) => item.isOwed).map((item) => item.amount),
      ),
      currency.symbol,
    );
    final getTotal = formatMoneyFromNumber(
      _sumAmounts(
        updatedPeople.where((item) => !item.isOwed).map((item) => item.amount),
      ),
      currency.symbol,
    );
    final todayExpenseAmount = summary.todayExpenseAmount;
    final lastActivityLabel = person.transactions.isNotEmpty
        ? person.transactions.first.dateLabel
        : summary.lastActivityLabel;

    await saveSummary(
      summary.copyWith(
        people: updatedPeople,
        totalTransactions: transactions,
        oweTotal: oweTotal,
        getTotal: getTotal,
        todayExpenseAmount: todayExpenseAmount,
        lastActivityLabel: lastActivityLabel,
      ),
    );
  }

  Future<void> addExpense({
    required String amount,
    required String category,
    required String description,
    required DateTime expenseDate,
  }) async {
    final normalizedAmount = _normalizeAmountForFirestore(amount);
    if (normalizedAmount == null) {
      throw const FormatException(
        'Amount must be a number with up to 2 decimal places.',
      );
    }

    final currency = await _currencyRepository.load();
    final summary = await _loadSummaryWithSymbol(currency.symbol);
    final todayExpense = _addMoney(
      summary.todayExpenseAmount,
      normalizedAmount,
      currency.symbol,
    );
    final totalTransactions = summary.totalTransactions + 1;

    await _saveExpenseRecord(
      FinanceExpenseRecord(
        amount: normalizedAmount,
        currencyCode: currency.code,
        category: category,
        description: description,
        dateLabel: _dateLabel(expenseDate),
        expenseDateMillis: expenseDate.millisecondsSinceEpoch,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    await saveSummary(
      summary.copyWith(
        todayExpenseAmount: todayExpense,
        totalTransactions: totalTransactions,
        lastActivityLabel: description.isEmpty
            ? 'Expense added: $category'
            : 'Expense added: $category - $description',
      ),
    );
  }

  Future<List<FinanceExpenseRecord>> loadExpensesInRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final firestore = FirebaseBootstrap.firestoreOrNull;
    final user = FirebaseBootstrap.authOrNull?.currentUser;
    if (firestore == null || user == null) return const <FinanceExpenseRecord>[];

    final snapshot = await firestore
        .collection(_collectionPath)
        .doc(user.uid)
        .collection(_expensesCollectionId)
        .where(
          'expenseDateMillis',
          isGreaterThanOrEqualTo: from.millisecondsSinceEpoch,
        )
        .where('expenseDateMillis', isLessThan: to.millisecondsSinceEpoch)
        .orderBy('expenseDateMillis', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => FinanceExpenseRecord.fromJson(doc.data()))
        .toList(growable: false);
  }

  Future<List<FinanceExpenseRecord>> loadRecentExpenses({int limit = 5}) async {
    final firestore = FirebaseBootstrap.firestoreOrNull;
    final user = FirebaseBootstrap.authOrNull?.currentUser;
    if (firestore == null || user == null) {
      return const <FinanceExpenseRecord>[];
    }

    final snapshot = await firestore
        .collection(_collectionPath)
        .doc(user.uid)
        .collection(_expensesCollectionId)
        .orderBy('createdAtMillis', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => FinanceExpenseRecord.fromJson(doc.data()))
        .toList(growable: false);
  }

  Future<void> _saveExpenseRecord(FinanceExpenseRecord expense) async {
    final firestore = FirebaseBootstrap.firestoreOrNull;
    final user = FirebaseBootstrap.authOrNull?.currentUser;
    if (firestore == null) {
      throw StateError('Firebase Firestore is not configured.');
    }
    if (user == null) {
      throw StateError('You must be signed in to save expenses.');
    }

    debugPrint(
      'Saving expense to project=${firestore.app.options.projectId}, uid=${user.uid}',
    );

    await firestore
        .collection(_collectionPath)
        .doc(user.uid)
        .collection(_expensesCollectionId)
        .add({...expense.toJson(), 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> addBorrowLend({
    required String name,
    required String amount,
    required bool isOwed,
    String reason = '',
  }) async {
    final currency = await _currencyRepository.load();
    final colorValue = isOwed ? 0xFF5EB7F6 : 0xFFA78BFA;
    final initial = name.trim().isEmpty
        ? '👤'
        : name.trim().substring(0, 1).toUpperCase();
    final formattedAmount = formatMoney(amount, currency.symbol);
    final baseTitle = isOwed ? 'Borrowed money' : 'Lent money';
    final title = reason.isEmpty ? baseTitle : '$baseTitle · $reason';

    final person = FinancePersonRecord(
      name: name.trim(),
      amount: formattedAmount,
      isOwed: isOwed,
      colorValue: colorValue,
      initials: initial,
      transactions: [
        FinanceTransactionRecord(
          title: title,
          dateLabel: _todayLabel(),
          amount: formattedAmount,
        ),
      ],
    );

    await upsertPerson(person);
  }

  FinanceSummaryRecord _applyCurrency(
    FinanceSummaryRecord summary,
    String symbol,
  ) {
    return summary.copyWith(
      todayExpenseAmount: formatMoney(summary.todayExpenseAmount, symbol),
      oweTotal: formatMoney(summary.oweTotal, symbol),
      getTotal: formatMoney(summary.getTotal, symbol),
      people: summary.people
          .map(
            (person) => person.copyWith(
              amount: formatMoney(person.amount, symbol),
              transactions: person.transactions
                  .map(
                    (transaction) => transaction.copyWith(
                      amount: formatMoney(transaction.amount, symbol),
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  double _sumAmounts(Iterable<String> values) {
    var total = 0.0;
    for (final value in values) {
      total += parseMoneyValue(value);
    }
    return total;
  }

  String _addMoney(String current, String delta, String symbol) {
    final total = parseMoneyValue(current) + parseMoneyValue(delta);
    return formatMoneyFromNumber(total, symbol);
  }

  String _todayLabel() {
    return _dateLabel(DateTime.now());
  }

  String _dateLabel(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> settlePerson(String name) async {
    final currency = await _currencyRepository.load();
    final summary = await _loadSummaryWithSymbol(currency.symbol);
    final updatedPeople =
        summary.people.where((p) => p.name != name).toList(growable: false);

    final oweTotal = formatMoneyFromNumber(
      _sumAmounts(
        updatedPeople.where((p) => p.isOwed).map((p) => p.amount),
      ),
      currency.symbol,
    );
    final getTotal = formatMoneyFromNumber(
      _sumAmounts(
        updatedPeople.where((p) => !p.isOwed).map((p) => p.amount),
      ),
      currency.symbol,
    );

    await saveSummary(
      summary.copyWith(
        people: updatedPeople,
        oweTotal: oweTotal,
        getTotal: getTotal,
        lastActivityLabel: 'Settled balance with $name',
      ),
    );
  }

  Future<void> updatePersonAmount(String name, String newRawAmount) async {
    final currency = await _currencyRepository.load();
    final summary = await _loadSummaryWithSymbol(currency.symbol);
    final updatedPeople = [...summary.people];
    final index = updatedPeople.indexWhere((p) => p.name == name);
    if (index < 0) return;

    final person = updatedPeople[index];
    final formattedAmount = formatMoney(newRawAmount, currency.symbol);
    final newTx = FinanceTransactionRecord(
      title: 'Balance updated',
      dateLabel: _todayLabel(),
      amount: newRawAmount,
    );

    updatedPeople[index] = person.copyWith(
      amount: formattedAmount,
      transactions: [newTx, ...person.transactions],
    );

    final oweTotal = formatMoneyFromNumber(
      _sumAmounts(
        updatedPeople.where((p) => p.isOwed).map((p) => p.amount),
      ),
      currency.symbol,
    );
    final getTotal = formatMoneyFromNumber(
      _sumAmounts(
        updatedPeople.where((p) => !p.isOwed).map((p) => p.amount),
      ),
      currency.symbol,
    );

    await saveSummary(
      summary.copyWith(
        people: updatedPeople,
        totalTransactions: summary.totalTransactions + 1,
        oweTotal: oweTotal,
        getTotal: getTotal,
        lastActivityLabel: 'Updated balance with $name',
      ),
    );
  }

  String? _normalizeAmountForFirestore(String raw) {
    final cleaned = extractMoneyValue(raw).trim();
    if (cleaned.isEmpty) return null;

    final directMatch = RegExp(r'^\d+(\.\d{1,2})?$');
    if (directMatch.hasMatch(cleaned)) {
      return cleaned;
    }

    final parsed = double.tryParse(cleaned);
    if (parsed == null) return null;

    final normalized = parsed
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'\.0+$'), '')
        .replaceFirst(RegExp(r'(\.\d*[1-9])0+$'), r'$1');

    return directMatch.hasMatch(normalized) ? normalized : null;
  }
}
