class OfficeSchedule {
  const OfficeSchedule({
    required this.workStartMinutes,
    required this.workEndMinutes,
    required this.offDays,
    this.lunchStartMinutes,
    this.lunchEndMinutes,
  });

  final int workStartMinutes;
  final int workEndMinutes;
  final List<int> offDays;

  /// Lunch suppression window. Null means no lunch suppression.
  final int? lunchStartMinutes;
  final int? lunchEndMinutes;

  bool isLunchTime(int minutesSinceMidnight) {
    final lStart = lunchStartMinutes;
    final lEnd = lunchEndMinutes;
    if (lStart == null || lEnd == null || lEnd <= lStart) return false;
    return minutesSinceMidnight >= lStart && minutesSinceMidnight < lEnd;
  }

  factory OfficeSchedule.fromJson(Map<String, dynamic> json) {
    return OfficeSchedule(
      workStartMinutes: (json['workStartMinutes'] as num?)?.toInt() ?? 9 * 60,
      workEndMinutes: (json['workEndMinutes'] as num?)?.toInt() ?? 18 * 60,
      offDays: (json['offDays'] as List<dynamic>?)
              ?.map((value) => (value as num).toInt())
              .toList(growable: false) ??
          const <int>[6, 7],
      lunchStartMinutes: (json['lunchStartMinutes'] as num?)?.toInt(),
      lunchEndMinutes: (json['lunchEndMinutes'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workStartMinutes': workStartMinutes,
      'workEndMinutes': workEndMinutes,
      'offDays': offDays,
      if (lunchStartMinutes != null) 'lunchStartMinutes': lunchStartMinutes,
      if (lunchEndMinutes != null) 'lunchEndMinutes': lunchEndMinutes,
    };
  }

  OfficeSchedule copyWith({
    int? workStartMinutes,
    int? workEndMinutes,
    List<int>? offDays,
    Object? lunchStartMinutes = _sentinel,
    Object? lunchEndMinutes = _sentinel,
  }) {
    return OfficeSchedule(
      workStartMinutes: workStartMinutes ?? this.workStartMinutes,
      workEndMinutes: workEndMinutes ?? this.workEndMinutes,
      offDays: offDays ?? this.offDays,
      lunchStartMinutes: lunchStartMinutes == _sentinel
          ? this.lunchStartMinutes
          : lunchStartMinutes as int?,
      lunchEndMinutes: lunchEndMinutes == _sentinel
          ? this.lunchEndMinutes
          : lunchEndMinutes as int?,
    );
  }
}

const Object _sentinel = Object();
