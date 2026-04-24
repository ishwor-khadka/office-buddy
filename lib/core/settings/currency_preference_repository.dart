import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/firebase_bootstrap.dart';
import 'currency_preference.dart';

class CurrencyPreferenceRepository {
  static const _collectionPath = 'users';
  static const _settingsDocId = 'settings';
  static const _currencyDocId = 'currency';
  static const _kCurrencyCode = 'currency_code';
  static const _kCurrencySymbol = 'currency_symbol';
  static const _kCurrencyName = 'currency_name';

  Future<CurrencyPreference> load() async {
    final fromFirebase = await loadFromFirebase();
    if (fromFirebase != null) {
      return fromFirebase;
    }

    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kCurrencyCode);
    final symbol = prefs.getString(_kCurrencySymbol);
    final name = prefs.getString(_kCurrencyName);
    if (code != null && symbol != null && name != null) {
      return CurrencyPreference(code: code, symbol: symbol, name: name);
    }

    return CurrencyPreference.defaultPreference;
  }

  Future<bool> hasSavedPreference() async {
    if (await hasFirebasePreference()) {
      return true;
    }
    return hasLocalPreference();
  }

  Future<bool> hasFirebasePreference() async {
    final firestore = FirebaseBootstrap.firestoreOrNull;
    final user = FirebaseBootstrap.authOrNull?.currentUser;
    if (firestore == null || user == null) return false;

    final snapshot = await firestore
        .collection(_collectionPath)
        .doc(user.uid)
        .collection(_settingsDocId)
        .doc(_currencyDocId)
        .get();

    return snapshot.exists && snapshot.data() != null;
  }

  Future<bool> hasLocalPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kCurrencyCode) &&
        prefs.containsKey(_kCurrencySymbol) &&
        prefs.containsKey(_kCurrencyName);
  }

  Future<CurrencyPreference?> loadFromFirebase() async {
    final firestore = FirebaseBootstrap.firestoreOrNull;
    final user = FirebaseBootstrap.authOrNull?.currentUser;
    if (firestore == null || user == null) return null;

    final snapshot = await firestore
        .collection(_collectionPath)
        .doc(user.uid)
        .collection(_settingsDocId)
        .doc(_currencyDocId)
        .get();

    if (!snapshot.exists || snapshot.data() == null) return null;
    return CurrencyPreference.fromJson(snapshot.data()!);
  }

  Future<bool> save(CurrencyPreference preference) async {
    await saveLocal(preference);
    try {
      await saveToFirebase(preference);
      return true;
    } catch (error) {
      debugPrint('Failed to save currency preference to Firebase: $error');
      return false;
    }
  }

  Future<void> saveLocal(CurrencyPreference preference) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrencyCode, preference.code);
    await prefs.setString(_kCurrencySymbol, preference.symbol);
    await prefs.setString(_kCurrencyName, preference.name);
  }

  Future<void> saveToFirebase(CurrencyPreference preference) async {
    final firestore = FirebaseBootstrap.firestoreOrNull;
    final user = FirebaseBootstrap.authOrNull?.currentUser;
    if (firestore == null || user == null) return;

    await firestore
        .collection(_collectionPath)
        .doc(user.uid)
        .collection(_settingsDocId)
        .doc(_currencyDocId)
        .set({
          ...preference.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}
