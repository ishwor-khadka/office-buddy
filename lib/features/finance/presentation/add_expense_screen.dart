import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/ui/ui_refresh_bus.dart';

import '../../../core/finance/finance_repository.dart';
import '../../../core/settings/currency_preference.dart';
import '../../../core/settings/currency_preference_repository.dart';
import '../../../core/ui/ob_background.dart';
import '../../../core/ui/ob_glass.dart';
import '../../../core/ui/ob_tokens.dart';

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
          extendBodyBehindAppBar: true,
          body: ObBackground(
            child: Stack(
              children: [
                Positioned(
                  top: -60,
                  right: -40,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ObTokens.sky.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 60,
                  left: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ObTokens.iris.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(context),
                            const SizedBox(height: 20),
                            _buildAmountCard(theme, currency),
                            const SizedBox(height: 20),
                            Text(
                              'Select Category',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: ObTokens.text,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ObGlass(
                              padding: const EdgeInsets.all(14),
                              child: GridView.count(
                                crossAxisCount: 4,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 0.78,
                                children: ExpenseCategory.values
                                    .map(
                                      (category) => _CategoryTile(
                                        category: category,
                                        selected:
                                            _selectedCategory == category,
                                        onTap: () {
                                          UiRefreshBus.instance.update(
                                            this,
                                            () =>
                                                _selectedCategory = category,
                                          );
                                        },
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            if (showDescription) ...[
                              const SizedBox(height: 16),
                              ObGlass(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          LucideIcons.fileText,
                                          size: 15,
                                          color: ObTokens.textMuted,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Description',
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                                color: ObTokens.textMuted,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _descriptionController,
                                      maxLines: 2,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(color: ObTokens.text),
                                      decoration: const InputDecoration(
                                        hintText: 'Add a short note',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                        isDense: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Text(
                              'Expense Date',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: ObTokens.text,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildDatePicker(context, theme, dateLabel),
                            const SizedBox(height: 24),
                            _buildSaveButton(
                              theme,
                              canSave,
                              navigator,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            child: const Icon(
              LucideIcons.arrowLeft,
              color: ObTokens.text,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [ObTokens.sky, ObTokens.iris],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(LucideIcons.receipt, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          'Add Expense',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: ObTokens.text,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountCard(ThemeData theme, CurrencyPreference currency) {
    return ObGlass(
      tint: ObTokens.sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.banknote, size: 15, color: ObTokens.textMuted),
              const SizedBox(width: 6),
              Text(
                'Amount',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: ObTokens.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            onChanged: (_) => UiRefreshBus.instance.update(this, () {}),
            style: theme.textTheme.displaySmall?.copyWith(
              color: ObTokens.text,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              prefixText: '${currency.symbol} ',
              prefixStyle: TextStyle(
                color: ObTokens.textMuted,
                fontSize: 34,
                fontWeight: FontWeight.w400,
              ),
              hintText: '0',
              hintStyle: TextStyle(
                color: ObTokens.textMuted,
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
    );
  }

  Widget _buildDatePicker(
    BuildContext context,
    ThemeData theme,
    String dateLabel,
  ) {
    return InkWell(
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
              UiRefreshBus.instance.update(
                this,
                () => _selectedDate = picked,
              );
            },
      borderRadius: BorderRadius.circular(16),
      child: ObGlass(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: ObTokens.iris.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                LucideIcons.calendar,
                color: ObTokens.iris,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                dateLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: ObTokens.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(LucideIcons.chevronDown, size: 16, color: ObTokens.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(
    ThemeData theme,
    bool canSave,
    NavigatorState navigator,
  ) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: canSave
            ? () async {
                UiRefreshBus.instance.update(this, () => _saving = true);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _repository.addExpense(
                    amount: _amountController.text.trim(),
                    category: _selectedCategory!.label,
                    description: _descriptionController.text.trim(),
                    expenseDate: _selectedDate,
                  );
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Expense saved to cloud.')),
                  );
                  navigator.pop(true);
                } catch (error) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to save expense: $error'),
                    ),
                  );
                } finally {
                  if (mounted) {
                    UiRefreshBus.instance.update(this, () => _saving = false);
                  }
                }
              }
            : null,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return Colors.white.withValues(alpha: 0.4);
            }
            return null;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: canSave
                ? const LinearGradient(
                    colors: [ObTokens.sky, ObTokens.iris],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: canSave ? null : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.save,
                  size: 18,
                  color: canSave ? Colors.white : ObTokens.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  _saving ? 'Saving…' : 'Save Expense',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: canSave ? Colors.white : ObTokens.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
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
      ExpenseCategory.entertainment => 'Fun',
      ExpenseCategory.bills => 'Bills',
      ExpenseCategory.health => 'Health',
      ExpenseCategory.education => 'Study',
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
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [ObTokens.sky, ObTokens.iris],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.7),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: ObTokens.iris.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? Colors.white : ObTokens.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
