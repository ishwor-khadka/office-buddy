import 'package:shared_preferences/shared_preferences.dart';

class FavoritesRepository {
  static const _kFavorites = 'exercise_favorites_v1';

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kFavorites) ?? const <String>[]).toSet();
  }

  Future<void> save(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kFavorites, ids.toList());
  }
}

