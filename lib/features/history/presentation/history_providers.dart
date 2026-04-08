import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/database_helper.dart';

class WeeklyReport {
  const WeeklyReport({
    required this.breaksCompleted,
    required this.breaksSnoozed,
    required this.breaksIgnored,
    required this.postureGood,
    required this.postureNeedsCorrection,
    required this.exerciseMinutes,
  });

  final int breaksCompleted;
  final int breaksSnoozed;
  final int breaksIgnored;
  final int postureGood;
  final int postureNeedsCorrection;
  final int exerciseMinutes;

  int get breakTotal => breaksCompleted + breaksSnoozed + breaksIgnored;

  int get breakCompletionPercent {
    if (breakTotal == 0) return 0;
    return ((breaksCompleted / breakTotal) * 100).round();
  }
}

final weeklyReportProvider = FutureProvider<WeeklyReport>((ref) async {
  final now = DateTime.now();
  final since = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
  final db = DatabaseHelper.instance;

  final completed = await db.countBreakLogsSince(
    sinceMillis: since,
    outcome: 'COMPLETED',
  );
  final snoozed = await db.countBreakLogsSince(
    sinceMillis: since,
    outcome: 'SNOOZED',
  );
  final ignored = await db.countBreakLogsSince(
    sinceMillis: since,
    outcome: 'IGNORED',
  );

  final postureGood = await db.countPostureLogsSince(
    sinceMillis: since,
    result: 'GOOD',
  );
  final postureNeeds = await db.countPostureLogsSince(
    sinceMillis: since,
    result: 'NEEDS_CORRECTION',
  );

  final exerciseSeconds = await db.sumExerciseSecondsSince(sinceMillis: since);
  final exerciseMinutes = (exerciseSeconds / 60).round();

  return WeeklyReport(
    breaksCompleted: completed,
    breaksSnoozed: snoozed,
    breaksIgnored: ignored,
    postureGood: postureGood,
    postureNeedsCorrection: postureNeeds,
    exerciseMinutes: exerciseMinutes,
  );
});

