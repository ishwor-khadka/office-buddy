import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/firebase_bootstrap.dart';

class FcmTokenService {
  static const _kPrefsFcmToken = 'fcm_token';
  static const _collectionUsers = 'users';
  static const _collectionDeviceTokens = 'device_tokens';

  static Future<String?> registerCurrentUserToken() async {
    final auth = FirebaseBootstrap.authOrNull;
    final firestore = FirebaseBootstrap.firestoreOrNull;
    final user = auth?.currentUser;
    if (user == null || firestore == null) return null;

    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsFcmToken, token);

      await _deleteAllUserTokenDocs(user.uid);
      final docId = _docIdForToken(token);
      await firestore
          .collection(_collectionUsers)
          .doc(user.uid)
          .collection(_collectionDeviceTokens)
          .doc(docId)
          .set({
            'token': token,
            'platform': defaultTargetPlatform.name,
            'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
          });

      return token;
    } catch (error) {
      debugPrint('Failed to register FCM token: $error');
      return null;
    }
  }

  static Future<void> deleteCurrentUserToken() async {
    final auth = FirebaseBootstrap.authOrNull;
    final firestore = FirebaseBootstrap.firestoreOrNull;
    final user = auth?.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final localToken = prefs.getString(_kPrefsFcmToken);

    try {
      if (user != null && firestore != null && localToken != null) {
        await firestore
            .collection(_collectionUsers)
            .doc(user.uid)
            .collection(_collectionDeviceTokens)
            .doc(_docIdForToken(localToken))
            .delete();
      }
    } catch (error) {
      debugPrint('Failed to delete FCM token doc: $error');
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      debugPrint('Failed to delete FCM token from device: $error');
    }

    await prefs.remove(_kPrefsFcmToken);
  }

  static String _docIdForToken(String token) {
    return token.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }

  static Future<void> _deleteAllUserTokenDocs(String uid) async {
    final firestore = FirebaseBootstrap.firestoreOrNull;
    if (firestore == null) return;
    try {
      final snapshot = await firestore
          .collection(_collectionUsers)
          .doc(uid)
          .collection(_collectionDeviceTokens)
          .get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (error) {
      debugPrint('Failed clearing old FCM tokens: $error');
    }
  }
}
