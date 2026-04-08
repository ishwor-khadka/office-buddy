import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_bootstrap.dart';

class TrackingRepository {
  TrackingRepository(this._client);

  final SupabaseClient _client;

  Future<void> trackEvent({
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _client.from('tracking_events').insert({
        'type': type,
        'data': data ?? <String, dynamic>{},
      });
    } catch (error) {
      debugPrint('Failed to track event "$type": $error');
      rethrow;
    }
  }

  static Future<void> trackIfAvailable({
    required String type,
    Map<String, dynamic>? data,
  }) async {
    final client = SupabaseBootstrap.clientOrNull;
    if (client == null) return;
    if (client.auth.currentSession == null) return;

    try {
      await client.from('tracking_events').insert({
        'type': type,
        'data': data ?? <String, dynamic>{},
      });
    } catch (error) {
      debugPrint('Failed to sync event "$type" to Supabase: $error');
    }
  }
}
