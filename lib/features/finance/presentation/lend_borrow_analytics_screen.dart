import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/finance/finance_models.dart';
import '../../../core/finance/finance_repository.dart';
import '../../../core/finance/money_formatter.dart';
import '../../../core/settings/currency_preference_repository.dart';
import '../../../core/ui/ob_background.dart';
import '../../../core/ui/ob_glass.dart';
import '../../../core/ui/ob_tokens.dart';

// ─── Data ────────────────────────────────────────────────────────────────────

class _Activity {
  const _Activity({
    required this.personName,
    required this.title,
    required this.dateLabel,
    required this.amount,
    required this.isOwed,
  });
  final String personName;
  final String title;
  final String dateLabel;
  final String amount;
  final bool isOwed;
}

class _LendBorrowData {
  const _LendBorrowData({
    required this.totalOwed,
    required this.totalToGet,
    required this.borrowedFrom,
    required this.lentTo,
    required this.recentActivity,
    required this.currencySymbol,
    required this.totalTransactions,
  });
  final double totalOwed;
  final double totalToGet;
  final List<FinancePersonRecord> borrowedFrom;
  final List<FinancePersonRecord> lentTo;
  final List<_Activity> recentActivity;
  final String currencySymbol;
  final int totalTransactions;

  double get netBalance => totalToGet - totalOwed;
  int get totalPeople => borrowedFrom.length + lentTo.length;
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class LendBorrowAnalyticsScreen extends StatefulWidget {
  const LendBorrowAnalyticsScreen({super.key});

  @override
  State<LendBorrowAnalyticsScreen> createState() =>
      _LendBorrowAnalyticsScreenState();
}

class _LendBorrowAnalyticsScreenState
    extends State<LendBorrowAnalyticsScreen> {
  final _repo = FinanceRepository();
  final _currencyRepo = CurrencyPreferenceRepository();
  late Future<_LendBorrowData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_LendBorrowData> _load() async {
    final summary = await _repo.loadSummary();
    final currency = await _currencyRepo.load();

    final borrowed = summary.people.where((p) => p.isOwed).toList();
    final lent = summary.people.where((p) => !p.isOwed).toList();

    final totalOwed =
        borrowed.fold(0.0, (s, p) => s + parseMoneyValue(p.amount));
    final totalToGet =
        lent.fold(0.0, (s, p) => s + parseMoneyValue(p.amount));

    final allActivity = summary.people
        .expand(
          (p) => p.transactions.map(
            (t) => _Activity(
              personName: p.name,
              title: t.title,
              dateLabel: t.dateLabel,
              amount: t.amount,
              isOwed: p.isOwed,
            ),
          ),
        )
        .toList()
      ..sort((a, b) => b.dateLabel.compareTo(a.dateLabel));

    return _LendBorrowData(
      totalOwed: totalOwed,
      totalToGet: totalToGet,
      borrowedFrom: borrowed,
      lentTo: lent,
      recentActivity: allActivity.take(10).toList(),
      currencySymbol: currency.symbol,
      totalTransactions: summary.totalTransactions,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: ObBackground(
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ObTokens.mintDeep.withValues(alpha: 0.14),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -50,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE71D3D).withValues(alpha: 0.07),
                ),
              ),
            ),
            SafeArea(
              child: FutureBuilder<_LendBorrowData>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Failed to load: ${snapshot.error}'),
                    );
                  }
                  return _buildBody(context, snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, _LendBorrowData data) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, theme),
          const SizedBox(height: 20),
          _OverviewCard(data: data)
              .animate()
              .fade(duration: 300.ms)
              .slideY(begin: 0.06),
          const SizedBox(height: 16),
          _QuickStats(data: data)
              .animate()
              .fade(delay: 80.ms, duration: 300.ms),
          if (data.borrowedFrom.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionLabel(label: 'You Owe To'),
            const SizedBox(height: 10),
            _PeopleBarList(
              people: data.borrowedFrom,
              symbol: data.currencySymbol,
              accentColor: const Color(0xFFE71D3D),
            ).animate().fade(delay: 140.ms, duration: 320.ms),
          ],
          if (data.lentTo.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionLabel(label: "You'll Get From"),
            const SizedBox(height: 10),
            _PeopleBarList(
              people: data.lentTo,
              symbol: data.currencySymbol,
              accentColor: const Color(0xFF0BA24D),
            ).animate().fade(delay: 180.ms, duration: 320.ms),
          ],
          if (data.recentActivity.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionLabel(label: 'Recent Activity'),
            const SizedBox(height: 10),
            _ActivityList(
              activities: data.recentActivity,
              symbol: data.currencySymbol,
            ).animate().fade(delay: 220.ms, duration: 320.ms),
          ],
          if (data.totalPeople == 0)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.heartHandshake,
                      size: 48,
                      color: ObTokens.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No lend/borrow records yet.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: ObTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
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
              colors: [ObTokens.mintDeep, ObTokens.sky],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(
            LucideIcons.heartHandshake,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Lend/Borrow Analytics',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: ObTokens.text,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: ObTokens.text,
      letterSpacing: -0.2,
    ),
  );
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.data});
  final _LendBorrowData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = data.netBalance;
    final netColor = net >= 0 ? const Color(0xFF0BA24D) : const Color(0xFFE71D3D);
    final netLabel = net >= 0 ? 'Net Lender' : 'Net Borrower';
    final netIcon = net >= 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown;

    return ObGlass(
      tint: net >= 0 ? const Color(0xFFE6F9F0) : const Color(0xFFFFEBEB),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _OverviewColumn(
                  label: 'YOU OWE',
                  amount: formatMoneyFromNumber(
                    data.totalOwed,
                    data.currencySymbol,
                  ),
                  color: const Color(0xFFE71D3D),
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              Expanded(
                child: _OverviewColumn(
                  label: "YOU'LL GET",
                  amount: formatMoneyFromNumber(
                    data.totalToGet,
                    data.currencySymbol,
                  ),
                  color: const Color(0xFF0BA24D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: netColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: netColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(netIcon, size: 14, color: netColor),
                const SizedBox(width: 8),
                Text(
                  '$netLabel  ·  Net ${formatMoneyFromNumber(net.abs(), data.currencySymbol)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: netColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewColumn extends StatelessWidget {
  const _OverviewColumn({
    required this.label,
    required this.amount,
    required this.color,
  });
  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color.withValues(alpha: 0.8),
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          amount,
          style: theme.textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.data});
  final _LendBorrowData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            icon: LucideIcons.users,
            label: 'People',
            value: '${data.totalPeople}',
            color: ObTokens.iris,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatChip(
            icon: LucideIcons.repeat,
            label: 'Transactions',
            value: '${data.totalTransactions}',
            color: ObTokens.sky,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatChip(
            icon: LucideIcons.arrowLeftRight,
            label: 'Net Balance',
            value: formatMoneyFromNumber(
              data.netBalance.abs(),
              data.currencySymbol,
            ),
            color: ObTokens.mintDeep,
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ObGlass(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: ObTokens.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: ObTokens.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeopleBarList extends StatelessWidget {
  const _PeopleBarList({
    required this.people,
    required this.symbol,
    required this.accentColor,
  });
  final List<FinancePersonRecord> people;
  final String symbol;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final maxVal = people.fold(
      0.0,
      (m, p) => m > parseMoneyValue(p.amount) ? m : parseMoneyValue(p.amount),
    );

    return ObGlass(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: people.map((person) {
          final val = parseMoneyValue(person.amount);
          final fraction = maxVal > 0 ? val / maxVal : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _PersonBar(
              name: person.name,
              initials: person.initials,
              amount: formatMoneyFromNumber(val, symbol),
              fraction: fraction,
              color: accentColor,
              reason: person.transactions.isNotEmpty
                  ? person.transactions.first.title
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PersonBar extends StatelessWidget {
  const _PersonBar({
    required this.name,
    required this.initials,
    required this.amount,
    required this.fraction,
    required this.color,
    this.reason,
  });
  final String name;
  final String initials;
  final String amount;
  final double fraction;
  final Color color;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 14,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: ObTokens.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (reason != null)
                    Text(
                      reason!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ObTokens.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Text(
              amount,
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activities, required this.symbol});
  final List<_Activity> activities;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return ObGlass(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: activities.map((a) {
          final color = a.isOwed
              ? const Color(0xFFE71D3D)
              : const Color(0xFF0BA24D);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ActivityTile(
              activity: a,
              symbol: symbol,
              color: color,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.activity,
    required this.symbol,
    required this.color,
  });
  final _Activity activity;
  final String symbol;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LucideIcons.arrowLeftRight, size: 13, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.personName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ObTokens.text,
                  ),
                ),
                Text(
                  activity.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ObTokens.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(activity.amount, symbol),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                activity.dateLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: ObTokens.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
