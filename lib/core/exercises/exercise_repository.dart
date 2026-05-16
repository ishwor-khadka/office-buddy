import 'dart:convert';

import 'package:flutter/services.dart';

import 'exercise.dart';

class ExerciseRepository {
  static Future<List<Exercise>>? _cachedExercises;

  Future<List<Exercise>> loadAll() async {
    return _cachedExercises ??= _loadAll();
  }

  Future<List<Exercise>> _loadAll() async {
    final raw = await rootBundle.loadString('assets/exercises.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = (decoded['exercises'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Exercise.fromJson)
        .toList(growable: false);
    return list;
  }
}
