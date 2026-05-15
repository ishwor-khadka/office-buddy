import 'package:flutter/widgets.dart';

class UiRefreshBus {
  UiRefreshBus._();

  static final UiRefreshBus instance = UiRefreshBus._();

  final ValueNotifier<int> tick = ValueNotifier<int>(0);

  void update(State state, [VoidCallback? fn]) {
    if (!state.mounted) return;
    fn?.call();
    tick.value = tick.value + 1;
  }
}

