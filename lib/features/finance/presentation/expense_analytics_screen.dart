import 'dart:math' as math;

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

// ─── Data classes ────────────────────────────────────────────────────────────

class _MonthBar {
  const _MonthBar({
    required this.label,
    required this.total,
    required this.isCurrent,
  });
  final String label;
  final double total;
  final bool isCurrent;
}

class _AnalyticsData {
  const _AnalyticsData({
    required this.thisMonthTotal,
    required this.lastMonthTotal,
    required this.byCategory,
    required this.sixMonthTrend,
    required this.thisMonthCount,
    required this.dailyAverage,
    required this.topCategory,
    required this.currencySymbol,
  });
  final double thisMonthTotal;
  final double lastMonthTotal;
  final Map<String, double> byCategory;
  final List<_MonthBar> sixMonthTrend;
  final int thisMonthCount;
  final double dailyAverage;
  final String topCategory;
  final String currencySymbol;

  double get percentChange {
    if (lastMonthTotal == 0) return 0;
    return ((thisMonthTotal - lastMonthTotal) / lastMonthTotal) * 100;
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class ExpenseAnalyticsScreen extends StatefulWidget {
  const ExpenseAnalyticsScreen({super.key});

  @override
  State<ExpenseAnalyticsScreen> createState() => _ExpenseAnalyticsScreenState();
}

class _ExpenseAnalyticsScreenState extends State<ExpenseAnalyticsScreen> {
  final _repo = FinanceRepository();
  final _currencyRepo = CurrencyPreferenceRepository();
  late Future<_AnalyticsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadAnalytics();
  }

  Future<_AnalyticsData> _loadAnalytics() async {
    final now = DateTime.now();
    final sixMonthsAgo = DateTime(now.year, now.month - 5);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    final allExpenses = await _repo.loadExpensesInRange(
      from: sixMonthsAgo,
      to: tomorrow,
    );
    final currency = await _currencyRepo.load();

    final thisMonth = allExpenses.where((e) {
      final d = DateTime.fromMillisecondsSinceEpoch(e.expenseDateMillis);
      return d.year == now.year && d.month == now.month;
    }).toList();

    final lastMonthDate = DateTime(now.year, now.month - 1);
    final lastMonth = allExpenses.where((e) {
      final d = DateTime.fromMillisecondsSinceEpoch(e.expenseDateMillis);
      return d.year == lastMonthDate.year && d.month == lastMonthDate.month;
    }).toList();

    final thisMonthTotal = _sum(thisMonth);
    final lastMonthTotal = _sum(lastMonth);

    final Map<String, double> byCategory = {};
    for (final e in thisMonth) {
      byCategory[e.category] =
          (byCategory[e.category] ?? 0) + parseMoneyValue(e.amount);
    }
    final sortedCategories = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final trend = <_MonthBar>[];
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      final total = allExpenses
          .where((e) {
            final d = DateTime.fromMillisecondsSinceEpoch(e.expenseDateMillis);
            return d.year == m.year && d.month == m.month;
          })
          .fold(0.0, (sum, e) => sum + parseMoneyValue(e.amount));
      trend.add(_MonthBar(
        label: _monthAbbr(m.month),
        total: total,
        isCurrent: i == 0,
      ));
    }

    final dailyAvg = now.day > 0 ? thisMonthTotal / now.day : 0.0;
    final topCat =
        sortedCategories.isNotEmpty ? sortedCategories.first.key : '—';

    return _AnalyticsData(
      thisMonthTotal: thisMonthTotal,
      lastMonthTotal: lastMonthTotal,
      byCategory: Map.fromEntries(sortedCategories),
      sixMonthTrend: trend,
      thisMonthCount: thisMonth.length,
      dailyAverage: dailyAvg,
      topCategory: topCat,
      currencySymbol: currency.symbol,
    );
  }

  double _sum(List<FinanceExpenseRecord> records) =>
      records.fold(0.0, (s, e) => s + parseMoneyValue(e.amount));

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
                  color: ObTokens.iris.withValues(alpha: 0.13),
                ),
              ),
            ),
            Positioned(
              bottom: 120,
              left: -50,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ObTokens.sky.withValues(alpha: 0.15),
                ),
              ),
            ),
            SafeArea(
              child: FutureBuilder<_AnalyticsData>(
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
                  final data = snapshot.data!;
                  return _buildBody(context, data);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, _AnalyticsData data) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, theme),
          const SizedBox(height: 20),
          _MonthComparisonCard(data: data)
              .animate()
              .fade(duration: 300.ms)
              .slideY(begin: 0.06),
          const SizedBox(height: 16),
          _QuickStatsRow(data: data)
              .animate()
              .fade(delay: 80.ms, duration: 300.ms),
          const SizedBox(height: 20),
          _SectionLabel(label: '6-Month Trend'),
          const SizedBox(height: 10),
          _TrendChart(bars: data.sixMonthTrend, symbol: data.currencySymbol)
              .animate()
              .fade(delay: 140.ms, duration: 320.ms),
          if (data.byCategory.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionLabel(label: 'Category Breakdown — This Month'),
            const SizedBox(height: 10),
            _CategoryBreakdown(
              byCategory: data.byCategory,
              total: data.thisMonthTotal,
              symbol: data.currencySymbol,
            ).animate().fade(delay: 200.ms, duration: 320.ms),
          ],
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
              colors: [ObTokens.iris, ObTokens.sky],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(LucideIcons.barChart2, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          'Expense Analytics',
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

class _MonthComparisonCard extends StatelessWidget {
  const _MonthComparisonCard({required this.data});
  final _AnalyticsData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = data.percentChange;
    final up = pct >= 0;
    final pctColor = up ? const Color(0xFFE71D3D) : const Color(0xFF0BA24D);
    final pctIcon = up ? LucideIcons.trendingUp : LucideIcons.trendingDown;
    final pctLabel = '${pct.abs().toStringAsFixed(1)}%';

    return ObGlass(
      tint: ObTokens.iris,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MonthColumn(
                  label: 'THIS MONTH',
                  amount: formatMoneyFromNumber(
                    data.thisMonthTotal,
                    data.currencySymbol,
                  ),
                  isHighlighted: true,
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              Expanded(
                child: _MonthColumn(
                  label: 'LAST MONTH',
                  amount: formatMoneyFromNumber(
                    data.lastMonthTotal,
                    data.currencySymbol,
                  ),
                  isHighlighted: false,
                ),
              ),
            ],
          ),
          if (data.lastMonthTotal > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: pctColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: pctColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(pctIcon, size: 14, color: pctColor),
                  const SizedBox(width: 6),
                  Text(
                    '$pctLabel ${up ? 'more' : 'less'} than last month',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: pctColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthColumn extends StatelessWidget {
  const _MonthColumn({
    required this.label,
    required this.amount,
    required this.isHighlighted,
  });
  final String label;
  final String amount;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: ObTokens.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          amount,
          style: theme.textTheme.titleLarge?.copyWith(
            color: isHighlighted ? ObTokens.iris : ObTokens.text,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({required this.data});
  final _AnalyticsData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            icon: LucideIcons.calculator,
            label: 'Daily Avg',
            value: formatMoneyFromNumber(
              data.dailyAverage,
              data.currencySymbol,
            ),
            color: ObTokens.sky,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatChip(
            icon: LucideIcons.star,
            label: 'Top Category',
            value: data.topCategory,
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatChip(
            icon: LucideIcons.receipt,
            label: 'Expenses',
            value: '${data.thisMonthCount}',
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

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.bars, required this.symbol});
  final List<_MonthBar> bars;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxVal = bars.fold(0.0, (m, b) => math.max(m, b.total));

    return ObGlass(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bars.map((bar) {
                final fraction = maxVal > 0 ? bar.total / maxVal : 0.0;
                final barHeight = 100.0 * fraction;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (bar.total > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              _compact(bar.total, symbol),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: bar.isCurrent
                                    ? ObTokens.iris
                                    : ObTokens.textMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 9,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          height: math.max(barHeight, bar.total > 0 ? 4 : 0),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                            gradient: bar.isCurrent
                                ? const LinearGradient(
                                    colors: [ObTokens.sky, ObTokens.iris],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  )
                                : LinearGradient(
                                    colors: [
                                      ObTokens.iris.withValues(alpha: 0.2),
                                      ObTokens.iris.withValues(alpha: 0.35),
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: bars.map((bar) {
              return Expanded(
                child: Text(
                  bar.label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: bar.isCurrent ? ObTokens.iris : ObTokens.textMuted,
                    fontWeight:
                        bar.isCurrent ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _compact(double val, String symbol) {
    if (val >= 1000) return '$symbol${(val / 1000).toStringAsFixed(1)}k';
    return '$symbol${val.toInt()}';
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.byCategory,
    required this.total,
    required this.symbol,
  });
  final Map<String, double> byCategory;
  final double total;
  final String symbol;

  static const _colors = [
    ObTokens.iris,
    ObTokens.sky,
    ObTokens.mintDeep,
    Color(0xFFF59E0B),
    Color(0xFFFF6B8A),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFFF6900),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = byCategory.entries.toList();

    return ObGlass(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: entries.indexed.map((indexed) {
          final i = indexed.$1;
          final entry = indexed.$2;
          final fraction = total > 0 ? entry.value / total : 0.0;
          final pct = (fraction * 100).toStringAsFixed(1);
          final color = _colors[i % _colors.length];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CategoryBar(
              label: entry.key,
              amount: formatMoneyFromNumber(entry.value, symbol),
              fraction: fraction,
              pct: '$pct%',
              color: color,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.label,
    required this.amount,
    required this.fraction,
    required this.pct,
    required this.color,
  });
  final String label;
  final String amount;
  final double fraction;
  final String pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ObTokens.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              amount,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ObTokens.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 38,
              child: Text(
                pct,
                textAlign: TextAlign.end,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _monthAbbr(int month) => const [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
][month - 1];
