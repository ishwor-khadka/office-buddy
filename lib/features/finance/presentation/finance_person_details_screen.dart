import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/finance/money_formatter.dart';
import '../../../core/settings/currency_preference.dart';
import '../../../core/settings/currency_preference_repository.dart';
import '../../../core/ui/ob_background.dart';
import '../../../core/ui/ob_glass.dart';
import '../../../core/ui/ob_tokens.dart';
import 'finance_tracker_screen.dart';

class FinancePersonDetailsScreen extends StatelessWidget {
  FinancePersonDetailsScreen({super.key, required this.args});

  final FinancePersonDetailsArgs args;
  final Future<CurrencyPreference> _currencyFuture =
      CurrencyPreferenceRepository().load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CurrencyPreference>(
      future: _currencyFuture,
      builder: (context, snapshot) {
        final currency = snapshot.data ?? CurrencyPreference.defaultPreference;
        final theme = Theme.of(context);
        final owed = args.isOwed;
        final amountColor = owed
            ? const Color(0xFFE71D3D)
            : const Color(0xFF0BA24D);
        final statusLabel = owed ? 'You owe' : 'Will get back';

        return Scaffold(
          extendBodyBehindAppBar: true,
          body: ObBackground(
            child: Stack(
              children: [
                Positioned(
                  top: -80,
                  right: -60,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (owed ? ObTokens.iris : ObTokens.mintDeep)
                          .withValues(alpha: 0.15),
                    ),
                  ),
                ),
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(context, theme),
                        const SizedBox(height: 20),
                        _buildHeroCard(
                          theme,
                          currency,
                          owed,
                          amountColor,
                          statusLabel,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: LucideIcons.repeat,
                                title: 'Transactions',
                                value: '${args.transactions.length}',
                                iconColor: ObTokens.iris,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                icon: LucideIcons.clock,
                                title: 'Last Activity',
                                value: '2 days ago',
                                iconColor: ObTokens.sky,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ObGlass(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: ObTokens.iris.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      LucideIcons.list,
                                      color: ObTokens.iris,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Transaction History',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: ObTokens.text,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ...args.transactions.map(
                                (transaction) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _TransactionRow(
                                    title: transaction.title,
                                    dateLabel: transaction.dateLabel,
                                    amount: formatMoney(
                                      transaction.amount,
                                      currency.symbol,
                                    ),
                                    amountColor: amountColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: owed
                                      ? [
                                          ObTokens.mintDeep,
                                          const Color(0xFF0BA24D),
                                        ]
                                      : [ObTokens.sky, ObTokens.iris],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      LucideIcons.checkCircle,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Settle Balance',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        InkWell(
          onTap: () => context.pop(),
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
        Expanded(
          child: Text(
            'Person Details',
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

  Widget _buildHeroCard(
    ThemeData theme,
    CurrencyPreference currency,
    bool owed,
    Color amountColor,
    String statusLabel,
  ) {
    return ObGlass(
      tint: owed ? const Color(0xFFFFEBEB) : const Color(0xFFE6F9F0),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: args.color,
              boxShadow: [
                BoxShadow(
                  color: args.color.withValues(alpha: 0.32),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                args.initials,
                style: const TextStyle(fontSize: 38),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            args.name,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: ObTokens.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: amountColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: amountColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Text(
                  statusLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatMoney(args.amount, currency.symbol),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
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

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.title,
    required this.dateLabel,
    required this.amount,
    required this.amountColor,
  });

  final String title;
  final String dateLabel;
  final String amount;
  final Color amountColor;

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
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: amountColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              LucideIcons.arrowLeftRight,
              size: 14,
              color: amountColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ObTokens.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ObTokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: theme.textTheme.titleMedium?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ObGlass(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: ObTokens.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: ObTokens.text,
            ),
          ),
        ],
      ),
    );
  }
}
