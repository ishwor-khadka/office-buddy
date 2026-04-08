import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'favorites_repository.dart';

final favoritesRepositoryProvider = Provider((ref) => FavoritesRepository());

final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, Set<String>>(FavoritesNotifier.new);

class FavoritesNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    return ref.read(favoritesRepositoryProvider).load();
  }

  Future<void> toggle(String id) async {
    final current = state.asData?.value ?? <String>{};
    final next = <String>{...current};
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = AsyncData(next);
    await ref.read(favoritesRepositoryProvider).save(next);
  }
}
