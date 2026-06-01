import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../../core/ui/ui_refresh_bus.dart';
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
import '../../../core/ui/ob_glass.dart';
import '../../../core/ui/ob_tokens.dart';

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
    UiRefreshBus.instance.update(this, () {
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
      extendBodyBehindAppBar: true,
      floatingActionButton: _GradientFab(
        onTap: () => _showAddNewDialog(context),
      ),
      body: ObBackground(
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -60,
              child: _Blob(
                color: ObTokens.iris.withValues(alpha: 0.15),
                size: 280,
              ),
            ),
            Positioned(
              bottom: 120,
              left: -50,
              child: _Blob(
                color: ObTokens.sky.withValues(alpha: 0.18),
                size: 240,
              ),
            ),
            SafeArea(
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
                          final loading =
                              snapshot.connectionState ==
                                  ConnectionState.waiting ||
                              expensesSnapshot.connectionState ==
                                  ConnectionState.waiting;

                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Header()
                                    .animate()
                                    .fade(duration: 250.ms)
                                    .slideY(begin: -0.04),
                                const SizedBox(height: 16),
                                _TodayExpenseCard(
                                  amount: summary.todayExpenseAmount,
                                ).animate().fade(duration: 300.ms).slideY(
                                  begin: 0.05,
                                ),
                                const SizedBox(height: 16),
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
                                ).animate().fade(duration: 320.ms, delay: 60.ms),
                                if (expenses.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  _SectionLabel(label: 'Recent Expenses'),
                                  const SizedBox(height: 10),
                                  ObGlass(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      children: expenses
                                          .map(
                                            (expense) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8,
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
                                          )
                                          .toList(),
                                    ),
                                  ).animate().fade(
                                    duration: 320.ms,
                                    delay: 80.ms,
                                  ),
                                ],
                                const SizedBox(height: 20),
                                _SectionLabel(label: 'People'),
                                const SizedBox(height: 10),
                                if (summary.people.isEmpty)
                                  ObGlass(
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 20,
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              LucideIcons.users,
                                              size: 32,
                                              color: ObTokens.textMuted,
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              'No borrow/lend records yet.',
                                              style: theme.textTheme.bodyMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ).animate().fade(
                                    duration: 320.ms,
                                    delay: 100.ms,
                                  )
                                else
                                  ObGlass(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      children: summary.people
                                          .map(
                                            (person) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: _PersonTile(
                                                person: _Person.fromRecord(
                                                  person,
                                                ),
                                                onTap: () => context.push(
                                                  AppRoutes.financePersonScreen,
                                                  extra: FinancePersonDetailsArgs
                                                      .fromRecord(person),
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ).animate().fade(
                                    duration: 320.ms,
                                    delay: 100.ms,
                                  ),
                                if (loading)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 16),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class _GradientFab extends StatelessWidget {
  const _GradientFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [ObTokens.sky, ObTokens.iris],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x557C6BFF),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(LucideIcons.plus, color: Colors.white, size: 26),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: ObTokens.text,
        letterSpacing: -0.2,
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
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
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
          child: const Icon(
            LucideIcons.walletCards,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Your Finance',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: ObTokens.text,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayExpenseCard extends StatelessWidget {
  const _TodayExpenseCard({required this.amount});
  final String amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ObGlass(
      tint: ObTokens.sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  LucideIcons.receipt,
                  size: 16,
                  color: ObTokens.text,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Today's Expense",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: ObTokens.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: theme.textTheme.displaySmall?.copyWith(
              color: ObTokens.text,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const SizedBox.expand(child: _DonutChart()),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
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
      (sweep: math.pi * 0.34, color: ObTokens.sky),
      (sweep: math.pi * 0.19, color: ObTokens.iris),
      (sweep: math.pi * 0.22, color: ObTokens.mintDeep),
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
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _LegendItem(color: ObTokens.sky, label: 'Food'),
        _LegendItem(color: ObTokens.iris, label: 'Transport'),
        _LegendItem(color: ObTokens.mintDeep, label: 'Shopping'),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: ObTokens.textMuted,
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
        tint: const Color(0xFFFFEBEB),
        icon: LucideIcons.trendingDown,
        amountColor: const Color(0xFFE71D3D),
      );

  const _BalanceCard.get(String amount)
    : this._(
        title: "You'll Get",
        amount: amount,
        tint: const Color(0xFFE6F9F0),
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
    return ObGlass(
      tint: tint,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: amountColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: amountColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: theme.textTheme.titleLarge?.copyWith(
              color: ObTokens.text,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ObTokens.sky.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              LucideIcons.receipt,
              color: ObTokens.sky,
              size: 18,
            ),
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
                    color: ObTokens.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description.isEmpty
                      ? dateLabel
                      : '$description  ·  $dateLabel',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount,
            style: theme.textTheme.titleMedium?.copyWith(
              color: ObTokens.text,
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
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: person.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: person.color.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    person.initials,
                    style: const TextStyle(fontSize: 18),
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
                        color: ObTokens.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    person.amount,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: ObTokens.textMuted,
                  ),
                ],
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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      decoration: BoxDecoration(
        color: ObTokens.canvas,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
                    color: ObTokens.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.x, size: 18, color: ObTokens.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _AddNewActionCard(
            title: 'Add Expense',
            subtitle: 'Track your spending',
            icon: LucideIcons.receipt,
            gradientColors: const [ObTokens.sky, ObTokens.iris],
            onTap: onAddExpense,
          ),
          const SizedBox(height: 14),
          _AddNewActionCard(
            title: 'Add Borrow/Lend',
            subtitle: 'Track money owed',
            icon: LucideIcons.users,
            gradientColors: const [ObTokens.iris, ObTokens.mintDeep],
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
    required this.gradientColors,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors.last.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.arrowRight,
                color: Colors.white.withValues(alpha: 0.8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
