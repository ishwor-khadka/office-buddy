import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

class FirebaseBootstrap {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static FirebaseAuth? get authOrNull {
    if (!_initialized) return null;
    return FirebaseAuth.instance;
  }

  static FirebaseFirestore? get firestoreOrNull {
    if (!_initialized) return null;
    return FirebaseFirestore.instance;
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
    } on UnsupportedError catch (error) {
      debugPrint('Firebase not configured for this platform: $error');
    } catch (error) {
      debugPrint('Firebase initialize failed: $error');
    }
  }
}
