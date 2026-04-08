import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_repository.dart';
import 'user_settings.dart';

final settingsRepositoryProvider = Provider((ref) => SettingsRepository());

final userSettingsProvider =
    AsyncNotifierProvider<UserSettingsNotifier, UserSettings>(
  UserSettingsNotifier.new,
);

class UserSettingsNotifier extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() async {
    final repo = ref.read(settingsRepositoryProvider);
    return repo.load();
  }

  Future<void> save(UserSettings settings) async {
    final repo = ref.read(settingsRepositoryProvider);
    state = AsyncData(settings);
    await repo.save(settings);
  }
}
