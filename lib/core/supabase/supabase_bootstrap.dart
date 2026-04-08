import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  static bool _initialized = false;

  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => _url.isNotEmpty && _anonKey.isNotEmpty;
  static bool get isInitialized => _initialized;

  static SupabaseClient? get clientOrNull {
    if (!_initialized) return null;
    return Supabase.instance.client;
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    if (!isConfigured) {
      debugPrint(
        'Supabase not configured. Pass --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=...',
      );
      return;
    }

    try {
      await Supabase.initialize(url: _url, anonKey: _anonKey);
      _initialized = true;
    } catch (error) {
      // Keep app usable even if Supabase init fails.
      debugPrint('Supabase initialize failed: $error');
    }
  }
}

