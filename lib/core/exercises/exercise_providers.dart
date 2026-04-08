import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'exercise.dart';
import 'exercise_repository.dart';

final exerciseRepositoryProvider = Provider((ref) => ExerciseRepository());

final exercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final repo = ref.read(exerciseRepositoryProvider);
  return repo.loadAll();
});

