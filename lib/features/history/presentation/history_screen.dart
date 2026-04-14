import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/ui/ob_background.dart';
import '../../../core/ui/ob_glass.dart';
import 'history_providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final report = ref.watch(weeklyReportProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.accountScreen),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: ObBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: report.when(
              data: (r) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ObGlass(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Weekly Report', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 10),
                        _MetricRow(
                          label: 'Breaks completed',
                          value: '${r.breakCompletionPercent}%',
                        ),
                        const SizedBox(height: 8),
                        _MetricRow(
                          label: 'Exercise minutes',
                          value: '${r.exerciseMinutes}m',
                        ),
                        const SizedBox(height: 8),
                        _MetricRow(
                          label: 'Posture checks',
                          value: '${r.postureGood + r.postureNeedsCorrection}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ObGlass(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Details', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 10),
                          Text(
                            'Breaks: ${r.breaksCompleted} completed, ${r.breaksSnoozed} snoozed, ${r.breaksIgnored} ignored',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Posture: ${r.postureGood} good, ${r.postureNeedsCorrection} needs correction',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Exercises: ${r.exerciseMinutes} minutes total',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const Spacer(),
                          Text(
                            'Next: charts and day-by-day trends.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Failed to load report: $e')),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
