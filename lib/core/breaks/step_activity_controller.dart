import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';

import 'break_state_repository.dart';

final stepActivityControllerProvider =
    NotifierProvider<StepActivityController, bool>(StepActivityController.new);

class StepActivityController extends Notifier<bool> {
  StreamSubscription<StepCount>? _sub;

  @override
  bool build() {
    _start();
    ref.onDispose(() => _sub?.cancel());
    return true;
  }

  void _start() {
    if (_sub != null) return;
    final repo = BreakStateRepository();
    try {
      _sub = Pedometer.stepCountStream.listen(
        (event) async {
          final steps = event.steps;
          final nowMs = DateTime.now().millisecondsSinceEpoch;

          final lastSteps = await repo.getLastStepCount();
          if (lastSteps == null) {
            await repo.setLastStepCount(steps);
            await repo.setLastStepAtMillis(nowMs);
            return;
          }

          if (steps > lastSteps) {
            await repo.setLastMovementAtMillis(nowMs);
            await repo.setLastStepCount(steps);
            await repo.setLastStepAtMillis(nowMs);
          }
        },
        onError: (e) {
          debugPrint('Step activity stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('Step activity init failed: $e');
    }
  }
}
