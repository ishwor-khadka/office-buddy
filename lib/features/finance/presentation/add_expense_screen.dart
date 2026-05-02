import 'package:flutter/material.dart';

import '../../../core/finance/finance_repository.dart';
import '../../../core/settings/currency_preference.dart';
import '../../../core/settings/currency_preference_repository.dart';
import '../../../core/ui/ob_background.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final FinanceRepository _repository = FinanceRepository();
  final CurrencyPreferenceRepository _currencyRepository =
      CurrencyPreferenceRepository();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  ExpenseCategory? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;
  Future<CurrencyPreference>? _currencyFuture;

  @override
  void initState() {
    super.initState();
    _currencyFuture = _currencyRepository.load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CurrencyPreference>(
      future: _currencyFuture,
      builder: (context, snapshot) {
        final currency = snapshot.data ?? CurrencyPreference.defaultPreference;
        final navigator = Navigator.of(context);
        final theme = Theme.of(context);
        final amountFilled = _amountController.text.trim().isNotEmpty;
        final categorySelected = _selectedCategory != null;
        final canSave = amountFilled && categorySelected && !_saving;
        final showDescription = _selectedCategory == ExpenseCategory.other;
        final dateLabel = _formatDate(_selectedDate);

        return Scaffold(
          backgroundColor: const Color(0xFFF1F1F1),
          body: ObBackground(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFEAF5FF),
                            Color(0xFFF0E9FF),
                            Color(0xFFEAF5F1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 26,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(
                                    Icons.arrow_back,
                                    color: Color(0xFF374151),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Add Expense',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: const Color(0xFF111827),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                18,
                                18,
                                16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Amount',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: const Color(0xFF7A8190),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _amountController,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                    style: theme.textTheme.displaySmall
                                        ?.copyWith(
                                          color: const Color(0xFF8B8B8B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                    decoration: InputDecoration(
                                      prefixText: '${currency.symbol} ',
                                      prefixStyle: const TextStyle(
                                        color: Color(0xFF8B8B8B),
                                        fontSize: 34,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      hintText: '0',
                                      hintStyle: const TextStyle(
                                        color: Color(0xFF8B8B8B),
                                        fontSize: 34,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Select Category',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: const Color(0xFF111827),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            GridView.count(
                              crossAxisCount: 4,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.75,
                              children: ExpenseCategory.values
                                  .map(
                                    (category) => _CategoryTile(
                                      category: category,
                                      selected: _selectedCategory == category,
                                      onTap: () {
                                        setState(() {
                                          _selectedCategory = category;
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                            if (showDescription) ...[
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  18,
                                  18,
                                  14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.06,
                                      ),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Description',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: const Color(0xFF7A8190),
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: _descriptionController,
                                      maxLines: 2,
                                      decoration: const InputDecoration(
                                        hintText: 'Add a short note',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            Text(
                              'Expense Date',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: const Color(0xFF111827),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: _saving
                                  ? null
                                  : () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _selectedDate,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked == null || !mounted) return;
                                      setState(() => _selectedDate = picked);
                                    },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFD5D9E2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_month,
                                      color: Color(0xFF374151),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        dateLabel,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              color: const Color(0xFF111827),
                                            ),
                                      ),
                                    ),
                                    const Icon(Icons.expand_more),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: canSave
                                    ? () async {
                                        setState(() => _saving = true);
                                        final messenger =
                                            ScaffoldMessenger.of(context);
                                        try {
                                          await _repository.addExpense(
                                            amount: _amountController.text
                                                .trim(),
                                            category: _selectedCategory!.label,
                                            description: _descriptionController
                                                .text
                                                .trim(),
                                            expenseDate: _selectedDate,
                                          );
                                          if (!mounted) return;
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Expense saved to cloud.',
                                              ),
                                            ),
                                          );
                                          navigator.pop(true);
                                        } catch (error) {
                                          if (!mounted) return;
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Failed to save expense: $error',
                                              ),
                                            ),
                                          );
                                        } finally {
                                          if (mounted) {
                                            setState(() => _saving = false);
                                          }
                                        }
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF59B4E9),
                                  disabledBackgroundColor: const Color(
                                    0xFFE2E5EB,
                                  ),
                                  foregroundColor: Colors.white,
                                  disabledForegroundColor: const Color(
                                    0xFF9BA4B5,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Text(
                                  'Save Expense',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: canSave
                                        ? Colors.white
                                        : const Color(0xFF9BA4B5),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _formatDate(DateTime date) {
  final y = date.year.toString();
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

enum ExpenseCategory {
  food,
  transport,
  shopping,
  entertainment,
  bills,
  health,
  education,
  other,
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ExpenseCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (category) {
      ExpenseCategory.food => 'Food',
      ExpenseCategory.transport => 'Transport',
      ExpenseCategory.shopping => 'Shopping',
      ExpenseCategory.entertainment => 'Entertainment',
      ExpenseCategory.bills => 'Bills',
      ExpenseCategory.health => 'Health',
      ExpenseCategory.education => 'Education',
      ExpenseCategory.other => 'Other',
    };
    final icon = switch (category) {
      ExpenseCategory.food => '🍕',
      ExpenseCategory.transport => '🚗',
      ExpenseCategory.shopping => '🛍️',
      ExpenseCategory.entertainment => '🎬',
      ExpenseCategory.bills => '🧾',
      ExpenseCategory.health => '💊',
      ExpenseCategory.education => '📚',
      ExpenseCategory.other => '📦',
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF59B4E9) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white : const Color(0xFF4B5563),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (selected) ...[
                const SizedBox(height: 4),
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFF17C964),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

extension on ExpenseCategory {
  String get label => switch (this) {
    ExpenseCategory.food => 'Food',
    ExpenseCategory.transport => 'Transport',
    ExpenseCategory.shopping => 'Shopping',
    ExpenseCategory.entertainment => 'Entertainment',
    ExpenseCategory.bills => 'Bills',
    ExpenseCategory.health => 'Health',
    ExpenseCategory.education => 'Education',
    ExpenseCategory.other => 'Other',
  };
}
