class UserSettings {
  const UserSettings({
    required this.workStartMinutes,
    required this.workEndMinutes,
    required this.breakIntervalMinutes,
    required this.requiredSteps,
  });

  // Minutes since midnight.
  final int workStartMinutes;
  final int workEndMinutes;

  // 20–90 in PRD; default 45.
  final int breakIntervalMinutes;

  // 20–30 in PRD; default 25.
  final int requiredSteps;

  UserSettings copyWith({
    int? workStartMinutes,
    int? workEndMinutes,
    int? breakIntervalMinutes,
    int? requiredSteps,
  }) {
    return UserSettings(
      workStartMinutes: workStartMinutes ?? this.workStartMinutes,
      workEndMinutes: workEndMinutes ?? this.workEndMinutes,
      breakIntervalMinutes: breakIntervalMinutes ?? this.breakIntervalMinutes,
      requiredSteps: requiredSteps ?? this.requiredSteps,
    );
  }
}

