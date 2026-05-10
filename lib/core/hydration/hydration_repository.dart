import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/firebase_bootstrap.dart';

class HydrationRepository {
  static const _kHydrationEntries = 'hydration_entries_v1';
  static const _kHydrationPendingSinceMs = 'hydration_pending_since_ms';
  static const _kHydrationPendingNotificationId =
      'hydration_pending_notification_id';
  static const _kHydrationPendingRetryCount = 'hydration_pending_retry_count';
  static const _kHydrationLastAckAtMs = 'hydration_last_ack_at_ms';
  static const _kHydrationLastPromptAtMs = 'hydration_last_prompt_at_ms';
  static const _collectionUsers = 'users';
  static const _collectionHydrationLogs = 'hydration_logs';

  Future<void> addHydrationEntry({
    required int timestampMillis,
    int amountMl = 250,
  }) async {
    await _saveLocalEntry(timestampMillis: timestampMillis, amountMl: amountMl);
    await _saveRemoteEntry(
      timestampMillis: timestampMillis,
      amountMl: amountMl,
    );
  }

  Future<List<Map<String, dynamic>>> loadEntries() async {
    final local = await _loadLocalEntries();
    final remote = await _loadRemoteEntries();
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final entry in [...remote, ...local]) {
      final t = (entry['t'] as num?)?.toInt();
      final ml = (entry['ml'] as num?)?.toInt();
      if (t == null || ml == null) {
        continue;
      }
      final key = '$t-$ml';
      if (!seen.add(key)) {
        continue;
      }
      merged.add({'t': t, 'ml': ml});
    }
    await _saveLocalEntries(merged);
    return merged;
  }

  Future<List<Map<String, dynamic>>> _loadLocalEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kHydrationEntries) ?? <String>[];
    return raw
        .map((item) => jsonDecode(item))
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _loadRemoteEntries() async {
    final firestore = FirebaseBootstrap.firestoreOrNull;
    final user = FirebaseBootstrap.authOrNull?.currentUser;
    if (firestore == null || user == null) {
      return const <Map<String, dynamic>>[];
    }
    try {
      final snapshot = await firestore
          .collection(_collectionUsers)
          .doc(user.uid)
          .collection(_collectionHydrationLogs)
          .orderBy('timestampMillis', descending: true)
          .limit(300)
          .get();
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            return <String, dynamic>{
              't': (data['timestampMillis'] as num?)?.toInt(),
              'ml': (data['amountMl'] as num?)?.toInt() ?? 250,
            };
          })
          .toList(growable: false);
    } catch (error) {
      debugPrint('Failed to load hydration logs from Firebase: $error');
      return const <Map<String, dynamic>>[];
    }
  }

  Future<int> totalForDayMl(DateTime date) async {
    final entries = await loadEntries();
    var total = 0;
    for (final entry in entries) {
      final t = (entry['t'] as num?)?.toInt();
      final ml = (entry['ml'] as num?)?.toInt() ?? 0;
      if (t == null) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(t);
      if (dt.year == date.year &&
          dt.month == date.month &&
          dt.day == date.day) {
        total += ml;
      }
    }
    return total;
  }

  Future<void> _saveLocalEntry({
    required int timestampMillis,
    required int amountMl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_kHydrationEntries) ?? <String>[];
    final next = <String>[
      ...existing,
      jsonEncode({'t': timestampMillis, 'ml': amountMl}),
    ];
    await prefs.setStringList(_kHydrationEntries, next);
    await prefs.setInt(_kHydrationLastAckAtMs, timestampMillis);
  }

  Future<void> _saveLocalEntries(List<Map<String, dynamic>> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = entries
        .map((entry) => jsonEncode({'t': entry['t'], 'ml': entry['ml']}))
        .toList(growable: false);
    await prefs.setStringList(_kHydrationEntries, encoded);
  }

  Future<void> _saveRemoteEntry({
    required int timestampMillis,
    required int amountMl,
  }) async {
    final firestore = FirebaseBootstrap.firestoreOrNull;
    final user = FirebaseBootstrap.authOrNull?.currentUser;
    if (firestore == null || user == null) return;
    try {
      await firestore
          .collection(_collectionUsers)
          .doc(user.uid)
          .collection(_collectionHydrationLogs)
          .add({
            'timestampMillis': timestampMillis,
            'amountMl': amountMl,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });
    } catch (error) {
      debugPrint('Failed to save hydration log to Firebase: $error');
    }
  }

  Future<void> clearPendingPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHydrationPendingSinceMs);
    await prefs.remove(_kHydrationPendingNotificationId);
    await prefs.remove(_kHydrationPendingRetryCount);
  }

  Future<void> setPendingPrompt({
    required int sinceMillis,
    required int notificationId,
    required int retryCount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kHydrationPendingSinceMs, sinceMillis);
    await prefs.setInt(_kHydrationPendingNotificationId, notificationId);
    await prefs.setInt(_kHydrationPendingRetryCount, retryCount);
    await prefs.setInt(_kHydrationLastPromptAtMs, sinceMillis);
  }

  Future<int?> getPendingSinceMillis() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kHydrationPendingSinceMs);
  }

  Future<int?> getPendingNotificationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kHydrationPendingNotificationId);
  }

  Future<int> getPendingRetryCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kHydrationPendingRetryCount) ?? 0;
  }

  Future<int?> getLastAcknowledgedAtMillis() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kHydrationLastAckAtMs);
  }

  Future<int?> getLastPromptAtMillis() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kHydrationLastPromptAtMs);
  }
}
