import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firebase_bootstrap.dart';

class TrackingRepository {
  TrackingRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<void> trackEvent({
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('tracking_events').add({
        'type': type,
        'data': data ?? <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
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
    final firestore = FirebaseBootstrap.firestoreOrNull;
    final auth = FirebaseBootstrap.authOrNull;
    final user = auth?.currentUser;
    if (firestore == null || user == null) return;

    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('tracking_events')
          .add({
            'type': type,
            'data': data ?? <String, dynamic>{},
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (error) {
      debugPrint('Failed to sync event "$type" to Firebase: $error');
    }
  }
}
