import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/ui/ob_background.dart';

class FinanceTrackerScreen extends StatelessWidget {
  const FinanceTrackerScreen({super.key});

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
              onAddExpense: () {
                Navigator.of(dialogContext).pop();
                context.push('/finance/add-expense');
              },
              onAddBorrowLend: () {
                Navigator.of(dialogContext).pop();
                context.push('/finance/lend-borrow');
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
          child: Center(
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
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header()
                            .animate()
                            .fade(duration: 250.ms)
                            .slideY(begin: 0.04),
                        const SizedBox(height: 18),
                        _ExpenseCard()
                            .animate()
                            .fade(duration: 280.ms)
                            .slideY(begin: 0.05),
                        const SizedBox(height: 16),
                        Row(
                          children: const [
                            Expanded(child: _BalanceCard.owe()),
                            SizedBox(width: 12),
                            Expanded(child: _BalanceCard.get()),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'People',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF171B2C),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._people.map(
                          (person) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PersonTile(
                              person: person,
                              onTap: () => context.push(
                                '/finance/person',
                                extra: FinancePersonDetailsArgs.fromPerson(
                                  name: person.name,
                                  amount: person.amount,
                                  isOwed: person.isOwed,
                                  color: person.color,
                                  initials: person.initials,
                                ),
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
            '₹850',
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

  const _BalanceCard.owe()
    : this._(
        title: 'You Owe',
        amount: '₹2500',
        tint: const Color(0xFFFFD6D6),
        icon: LucideIcons.trendingDown,
        amountColor: const Color(0xFFE71D3D),
      );

  const _BalanceCard.get()
    : this._(
        title: "You'll Get",
        amount: '₹1800',
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
                amount: '₹300',
              ),
              FinanceTransaction(
                title: 'Movie tickets',
                dateLabel: 'Apr 3, 2026',
                amount: '₹200',
              ),
            ]
          : const [
              FinanceTransaction(
                title: 'Lunch split',
                dateLabel: 'Apr 6, 2026',
                amount: '₹150',
              ),
              FinanceTransaction(
                title: 'Taxi fare',
                dateLabel: 'Apr 4, 2026',
                amount: '₹150',
              ),
            ],
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

const _people = [
  _Person(
    name: 'Rajesh',
    amount: '₹500',
    isOwed: true,
    color: Color(0xFF5EB7F6),
    initials: '👱',
  ),
  _Person(
    name: 'Priya',
    amount: '₹300',
    isOwed: false,
    color: Color(0xFFA78BFA),
    initials: '👩',
  ),
  _Person(
    name: 'Amit',
    amount: '₹1200',
    isOwed: true,
    color: Color(0xFF65D1A6),
    initials: '👨',
  ),
  _Person(
    name: 'Sneha',
    amount: '₹800',
    isOwed: false,
    color: Color(0xFFA78BFA),
    initials: '👩',
  ),
  _Person(
    name: 'Suresh',
    amount: '₹800',
    isOwed: true,
    color: Color(0xFF5EB7F6),
    initials: '👱',
  ),
];

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

class _BorrowLendDialog extends StatefulWidget {
  const _BorrowLendDialog({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_BorrowLendDialog> createState() => _BorrowLendDialogState();
}

class _BorrowLendDialogState extends State<_BorrowLendDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'hari');
    _amountController = TextEditingController(text: '100');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBorrowed = _selectedTab == 0;
    final note = isBorrowed
        ? 'You borrowed money from hari'
        : 'hari borrowed money from you';

    return Container(
      width: math.min(MediaQuery.sizeOf(context).width - 24, 360),
      height: math.min(MediaQuery.sizeOf(context).height - 44, 730),
      margin: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5BADE7), Color(0xFF8B7AF6), Color(0xFF68C9AE)],
              stops: [0.0, 0.56, 1.0],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Add Borrow/Lend',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ModeTab(
                            label: 'Borrowed (You owe)',
                            selected: isBorrowed,
                            onTap: () => setState(() => _selectedTab = 0),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _ModeTab(
                            label: 'Lent (They owe)',
                            selected: !isBorrowed,
                            onTap: () => setState(() => _selectedTab = 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF52BF9B),
                      ),
                      child: const Center(
                        child: Text('👱', style: TextStyle(fontSize: 42)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Person's Name",
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF6C7487),
                          ),
                        ),
                        const SizedBox(height: 2),
                        TextField(
                          controller: _nameController,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF1C2233),
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const Divider(height: 18),
                        Text(
                          'Amount',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF6C7487),
                          ),
                        ),
                        const SizedBox(height: 2),
                        TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF1C2233),
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            prefixText: '₹ ',
                            prefixStyle: TextStyle(
                              color: Color(0xFF8F97A8),
                              fontSize: 28,
                              fontWeight: FontWeight.w400,
                            ),
                            isDense: true,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      note,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF10182A),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      'Save Transaction',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF10182A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected
                  ? const Color(0xFF1E2434)
                  : Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
