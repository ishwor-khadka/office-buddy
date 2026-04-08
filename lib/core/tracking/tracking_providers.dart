import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_bootstrap.dart';
import 'tracking_repository.dart';

final supabaseClientProvider = Provider((ref) => SupabaseBootstrap.clientOrNull);

final trackingRepositoryProvider = Provider<TrackingRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return TrackingRepository(client);
});

