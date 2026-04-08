import 'package:shared_preferences/shared_preferences.dart';

class BreakStateRepository {
  static const _kNextBreakAtMillis = 'next_break_at_ms';
  static const _kSnoozeUntilMillis = 'break_snooze_until_ms';
  static const _kConsecutiveIgnored = 'break_consecutive_ignored';
  static const _kEscalationLevel = 'break_escalation_level';
  static const _kLastMovementAtMillis = 'last_movement_at_ms';
  static const _kLastStepCount = 'last_step_count';
  static const _kLastStepAtMillis = 'last_step_at_ms';

  Future<int?> getNextBreakAtMillis() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kNextBreakAtMillis);
  }

  Future<void> setNextBreakAtMillis(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kNextBreakAtMillis, value);
  }

  Future<int?> getSnoozeUntilMillis() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kSnoozeUntilMillis);
  }

  Future<void> setSnoozeUntilMillis(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSnoozeUntilMillis, value);
  }

  Future<void> clearSnooze() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSnoozeUntilMillis);
  }

  Future<int> getConsecutiveIgnored() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kConsecutiveIgnored) ?? 0;
  }

  Future<void> setConsecutiveIgnored(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kConsecutiveIgnored, value);
  }

  Future<int> getEscalationLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kEscalationLevel) ?? 0;
  }

  Future<void> setEscalationLevel(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kEscalationLevel, value);
  }

  Future<int?> getLastMovementAtMillis() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kLastMovementAtMillis);
  }

  Future<void> setLastMovementAtMillis(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastMovementAtMillis, value);
  }

  Future<int?> getLastStepCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kLastStepCount);
  }

  Future<void> setLastStepCount(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastStepCount, value);
  }

  Future<int?> getLastStepAtMillis() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kLastStepAtMillis);
  }

  Future<void> setLastStepAtMillis(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastStepAtMillis, value);
  }
}
