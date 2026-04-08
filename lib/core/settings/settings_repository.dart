import 'package:shared_preferences/shared_preferences.dart';

import 'user_settings.dart';

class SettingsRepository {
  static const _kWorkStartMinutes = 'work_start_minutes';
  static const _kWorkEndMinutes = 'work_end_minutes';
  static const _kBreakIntervalMinutes = 'break_interval_minutes';
  static const _kRequiredSteps = 'required_steps';

  Future<UserSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return UserSettings(
      workStartMinutes: prefs.getInt(_kWorkStartMinutes) ?? (9 * 60),
      workEndMinutes: prefs.getInt(_kWorkEndMinutes) ?? (18 * 60),
      breakIntervalMinutes: prefs.getInt(_kBreakIntervalMinutes) ?? 45,
      requiredSteps: prefs.getInt(_kRequiredSteps) ?? 25,
    );
  }

  Future<void> save(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kWorkStartMinutes, settings.workStartMinutes);
    await prefs.setInt(_kWorkEndMinutes, settings.workEndMinutes);
    await prefs.setInt(_kBreakIntervalMinutes, settings.breakIntervalMinutes);
    await prefs.setInt(_kRequiredSteps, settings.requiredSteps);
  }
}

