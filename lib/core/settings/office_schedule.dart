class OfficeSchedule {
  const OfficeSchedule({
    required this.workStartMinutes,
    required this.workEndMinutes,
    required this.offDays,
  });

  final int workStartMinutes;
  final int workEndMinutes;
  final List<int> offDays;

  factory OfficeSchedule.fromJson(Map<String, dynamic> json) {
    return OfficeSchedule(
      workStartMinutes: (json['workStartMinutes'] as num?)?.toInt() ?? 9 * 60,
      workEndMinutes: (json['workEndMinutes'] as num?)?.toInt() ?? 18 * 60,
      offDays: (json['offDays'] as List<dynamic>?)
              ?.map((value) => (value as num).toInt())
              .toList(growable: false) ??
          const <int>[6, 7],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workStartMinutes': workStartMinutes,
      'workEndMinutes': workEndMinutes,
      'offDays': offDays,
    };
  }

  OfficeSchedule copyWith({
    int? workStartMinutes,
    int? workEndMinutes,
    List<int>? offDays,
  }) {
    return OfficeSchedule(
      workStartMinutes: workStartMinutes ?? this.workStartMinutes,
      workEndMinutes: workEndMinutes ?? this.workEndMinutes,
      offDays: offDays ?? this.offDays,
    );
  }
}
