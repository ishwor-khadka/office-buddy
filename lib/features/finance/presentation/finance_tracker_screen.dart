import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:office_buddy/core/router/app_routes.dart';

import '../../../core/finance/finance_models.dart';
import '../../../core/finance/finance_repository.dart';
import '../../../core/finance/money_formatter.dart';
import '../../../core/settings/currency_preference.dart';
import '../../../core/settings/currency_preference_repository.dart';
import '../../../core/ui/ob_background.dart';

class FinanceTrackerScreen extends StatefulWidget {
  const FinanceTrackerScreen({super.key});

  @override
  State<FinanceTrackerScreen> createState() => _FinanceTrackerScreenState();
}

class _FinanceTrackerScreenState extends State<FinanceTrackerScreen> {
  final FinanceRepository _repository = FinanceRepository();
  final CurrencyPreferenceRepository _currencyRepository =
      CurrencyPreferenceRepository();
  late Future<FinanceSummaryRecord> _summaryFuture;
  late Future<List<FinanceExpenseRecord>> _expensesFuture;
  late Future<CurrencyPreference> _currencyFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _repository.loadSummary();
    _expensesFuture = _repository.loadRecentExpenses();
    _currencyFuture = _currencyRepository.load();
  }

  Future<void> _refreshSummary() async {
    setState(() {
      _summaryFuture = _repository.loadSummary();
      _expensesFuture = _repository.loadRecentExpenses();
      _currencyFuture = _currencyRepository.load();
    });
    await _summaryFuture;
  }

  Future<void> _showAddNewDialog(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Add New',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: 220.ms,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: _AddNewDialog(
              onClose: () => Navigator.of(dialogContext).pop(),
              onAddExpense: () async {
                Navigator.of(dialogContext).pop();
                final changed = await context.push<bool>(
                  AppRoutes.financeAddExpenseScreen,
                );
                if (changed == true && mounted) {
                  await _refreshSummary();
                }
              },
              onAddBorrowLend: () async {
                Navigator.of(dialogContext).pop();
                final changed = await context.push<bool>(
                  AppRoutes.financeLendBorrowScreen,
                );
                if (changed == true && mounted) {
                  await _refreshSummary();
                }
              },
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: InkWell(
        onTap: () => _showAddNewDialog(context),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF63C5F4), Color(0xFF9B7BFF)],
            ),
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 30),
        ),
      ),
      backgroundColor: const Color(0xFFE8E8E8),
      body: ObBackground(
        child: SafeArea(
          child: FutureBuilder<FinanceSummaryRecord>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              final summary = snapshot.data ?? FinanceSummaryRecord.empty();

              return FutureBuilder<CurrencyPreference>(
                future: _currencyFuture,
                builder: (context, currencySnapshot) {
                  final currency =
                      currencySnapshot.data ??
                      CurrencyPreference.defaultPreference;

                  return FutureBuilder<List<FinanceExpenseRecord>>(
                    future: _expensesFuture,
                    builder: (context, expensesSnapshot) {
                      final expenses =
                          expensesSnapshot.data ??
                          const <FinanceExpenseRecord>[];

                      return Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 430),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F7F7),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 34,
                                    offset: const Offset(0, 18),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  18,
                                  18,
                                  26,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _Header()
                                        .animate()
                                        .fade(duration: 250.ms)
                                        .slideY(begin: 0.04),
                                    const SizedBox(height: 18),
                                    _ExpenseCard(
                                          amount: summary.todayExpenseAmount,
                                        )
                                        .animate()
                                        .fade(duration: 280.ms)
                                        .slideY(begin: 0.05),
                                    const SizedBox(height: 16),
                                    if (expenses.isNotEmpty) ...[
                                      Text(
                                        'Recent Expenses',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF171B2C),
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      ...expenses.map(
                                        (expense) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: _ExpenseTile(
                                            category: expense.category,
                                            description: expense.description,
                                            dateLabel: expense.dateLabel,
                                            amount: formatMoney(
                                              expense.amount,
                                              currency.symbol,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _BalanceCard.owe(
                                            summary.oweTotal,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _BalanceCard.get(
                                            summary.getTotal,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      'People',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF171B2C),
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (summary.people.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 24,
                                        ),
                                        child: Center(
                                          child: Text(
                                            'No borrow/lend records yet.',
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ),
                                      )
                                    else
                                      ...summary.people.map(
                                        (person) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: _PersonTile(
                                            person: _Person.fromRecord(person),
                                            onTap: () => context.push(
                                              AppRoutes.financePersonScreen,
                                              extra:
                                                  FinancePersonDetailsArgs.fromRecord(
                                                    person,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (snapshot.connectionState ==
                                            ConnectionState.waiting ||
                                        expensesSnapshot.connectionState ==
                                            ConnectionState.waiting)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 12),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        // Container(
        //   width: 40,
        //   height: 40,
        //   decoration: const BoxDecoration(
        //     shape: BoxShape.circle,
        //     gradient: LinearGradient(
        //       colors: [Color(0xFF58B4F7), Color(0xFF7F69FF)],
        //     ),
        //   ),
        //   child: const Icon(
        //     LucideIcons.walletCards,
        //     color: Colors.white,
        //     size: 20,
        //   ),
        // ),
        // const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Your Finance 👋',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF151B2A),
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFD7EFFF), Color(0xFFF0E7FF), Color(0xFFE8FFF7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Expense",
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF51607B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: theme.textTheme.displaySmall?.copyWith(
              color: const Color(0xFF10182A),
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 170,
                  child: Stack(
                    alignment: Alignment.center,
                    children: const [
                      SizedBox.expand(child: _DonutChart()),
                      SizedBox(
                        width: 76,
                        height: 76,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF2FAF8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                const _LegendRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DonutPainter());
  }
}

class _DonutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.28;
    final stroke = radius * 0.42;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi / 2;

    final segments = <({double sweep, Color color})>[
      (sweep: math.pi * 0.34, color: const Color(0xFF5EB7F6)),
      (sweep: math.pi * 0.19, color: const Color(0xFFA78BFA)),
      (sweep: math.pi * 0.22, color: const Color(0xFF65D1A6)),
      (sweep: math.pi * 0.15, color: const Color(0xFF7ED7CF)),
    ];

    double current = start;
    for (final segment in segments) {
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, current, segment.sweep, false, paint);
      current += segment.sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LegendRow extends StatelessWidget {
  const _LegendRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        _LegendItem(color: Color(0xFF5EB7F6), label: 'Food'),
        _LegendItem(color: Color(0xFFA78BFA), label: 'Transport'),
        _LegendItem(color: Color(0xFF65D1A6), label: 'Shopping'),
        _LegendItem(color: Color(0xFF7ED7CF), label: 'Others'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: const Color(0xFF465065),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard._({
    required this.title,
    required this.amount,
    required this.tint,
    required this.icon,
    required this.amountColor,
  });

  const _BalanceCard.owe(String amount)
    : this._(
        title: 'You Owe',
        amount: amount,
        tint: const Color(0xFFFFD6D6),
        icon: LucideIcons.trendingDown,
        amountColor: const Color(0xFFE71D3D),
      );

  const _BalanceCard.get(String amount)
    : this._(
        title: "You'll Get",
        amount: amount,
        tint: const Color(0xFFD7F8E6),
        icon: LucideIcons.trendingUp,
        amountColor: const Color(0xFF0BA24D),
      );
  final String title;
  final String amount;
  final Color tint;
  final IconData icon;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: amountColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: amountColor, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: theme.textTheme.titleLarge?.copyWith(
              color: const Color(0xFF1A2234),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.category,
    required this.description,
    required this.dateLabel,
    required this.amount,
  });

  final String category;
  final String description;
  final String dateLabel;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEAF5FF),
            ),
            child: const Icon(Icons.receipt_long, color: Color(0xFF4B98D8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF171B2C),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description.isEmpty
                      ? dateLabel
                      : '$description  •  $dateLabel',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount,
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFF10182A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Person {
  const _Person({
    required this.name,
    required this.amount,
    required this.isOwed,
    required this.color,
    required this.initials,
  });

  final String name;
  final String amount;
  final bool isOwed;
  final Color color;
  final String initials;

  factory _Person.fromRecord(FinancePersonRecord record) {
    return _Person(
      name: record.name,
      amount: record.amount,
      isOwed: record.isOwed,
      color: Color(record.colorValue),
      initials: record.initials,
    );
  }
}

class FinancePersonDetailsArgs {
  const FinancePersonDetailsArgs({
    required this.name,
    required this.amount,
    required this.isOwed,
    required this.color,
    required this.initials,
    required this.transactions,
  });

  factory FinancePersonDetailsArgs.fromPerson({
    required String name,
    required String amount,
    required bool isOwed,
    required Color color,
    required String initials,
  }) {
    return FinancePersonDetailsArgs(
      name: name,
      amount: amount,
      isOwed: isOwed,
      color: color,
      initials: initials,
      transactions: isOwed
          ? const [
              FinanceTransaction(
                title: 'Dinner at restaurant',
                dateLabel: 'Apr 5, 2026',
                amount: '300',
              ),
              FinanceTransaction(
                title: 'Movie tickets',
                dateLabel: 'Apr 3, 2026',
                amount: '200',
              ),
            ]
          : const [
              FinanceTransaction(
                title: 'Lunch split',
                dateLabel: 'Apr 6, 2026',
                amount: '150',
              ),
              FinanceTransaction(
                title: 'Taxi fare',
                dateLabel: 'Apr 4, 2026',
                amount: '150',
              ),
            ],
    );
  }

  factory FinancePersonDetailsArgs.fromRecord(FinancePersonRecord record) {
    return FinancePersonDetailsArgs(
      name: record.name,
      amount: record.amount,
      isOwed: record.isOwed,
      color: Color(record.colorValue),
      initials: record.initials,
      transactions: record.transactions
          .map(
            (transaction) => FinanceTransaction(
              title: transaction.title,
              dateLabel: transaction.dateLabel,
              amount: transaction.amount,
            ),
          )
          .toList(growable: false),
    );
  }

  final String name;
  final String amount;
  final bool isOwed;
  final Color color;
  final String initials;
  final List<FinanceTransaction> transactions;
}

class FinanceTransaction {
  const FinanceTransaction({
    required this.title,
    required this.dateLabel,
    required this.amount,
  });

  final String title;
  final String dateLabel;
  final String amount;
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person, required this.onTap});

  final _Person person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = person.isOwed
        ? const Color(0xFFE71D3D)
        : const Color(0xFF10A64B);
    final statusLabel = person.isOwed ? 'You owe' : 'Will get back';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: person.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: person.color.withValues(alpha: 0.32),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    person.initials,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF171B2C),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      statusLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                person.amount,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddNewDialog extends StatelessWidget {
  const _AddNewDialog({
    required this.onClose,
    required this.onAddExpense,
    required this.onAddBorrowLend,
  });

  final VoidCallback onClose;
  final VoidCallback onAddExpense;
  final VoidCallback onAddBorrowLend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: math.min(MediaQuery.sizeOf(context).width - 36, 720),
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Add New',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(
                  Icons.close,
                  color: Color(0xFF4B5563),
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AddNewActionCard(
            title: 'Add Expense',
            subtitle: 'Track your spending',
            icon: LucideIcons.receipt,
            gradient: const [Color(0xFF5FB5EC), Color(0xFF4B98D8)],
            onTap: onAddExpense,
          ),
          const SizedBox(height: 22),
          _AddNewActionCard(
            title: 'Add Borrow/Lend',
            subtitle: 'Track money owed',
            icon: LucideIcons.users,
            gradient: const [Color(0xFF9F83F8), Color(0xFF6CC8AE)],
            onTap: onAddBorrowLend,
          ),
        ],
      ),
    );
  }
}

class _AddNewActionCard extends StatelessWidget {
  const _AddNewActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 34),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
