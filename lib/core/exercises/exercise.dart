class Exercise {
  const Exercise({
    required this.id,
    required this.title,
    required this.bodyPart,
    required this.difficulty,
    required this.durationSeconds,
    required this.instructions,
  });

  final String id;
  final String title;
  final String bodyPart; // Neck, Back, Wrist, Eyes
  final String difficulty; // Easy, Medium
  final int durationSeconds;
  final List<String> instructions;

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      title: json['title'] as String,
      bodyPart: json['bodyPart'] as String,
      difficulty: json['difficulty'] as String,
      durationSeconds: json['durationSeconds'] as int,
      instructions: (json['instructions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(growable: false),
    );
  }
}

