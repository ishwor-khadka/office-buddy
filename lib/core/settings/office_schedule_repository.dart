import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/firebase_bootstrap.dart';
import 'office_schedule.dart';

class OfficeScheduleRepository {
  static const _collectionPath = 'users';
  static const _settingsDocId = 'settings';
  static const _officeDocId = 'office';
  static const _kStartMinutes = 'office_start_minutes';
  static const _kEndMinutes = 'office_end_minutes';
  static const _kOffDays = 'office_off_days';

  Future<OfficeSchedule> load() async {
    final fromFirebase = await loadFromFirebase();
    if (fromFirebase != null) {
      return fromFirebase;
    }

    final prefs = await SharedPreferences.getInstance();
    return OfficeSchedule(
      workStartMinutes: prefs.getInt(_kStartMinutes) ?? 9 * 60,
      workEndMinutes: prefs.getInt(_kEndMinutes) ?? 18 * 60,
      offDays: prefs.getStringList(_kOffDays)?.map(int.parse).toList() ??
          const <int>[6, 7],
    );
  }

  Future<bool> hasSavedSchedule() async {
    if (await hasFirebaseSchedule()) {
      return true;
    }
    return hasLocalSchedule();
  }

  Future<bool> hasFirebaseSchedule() async {
    final firestore = FirebaseBootstrap.firestoreOrNull;
    final user = FirebaseBootstrap.authOrNull?.currentUser;
    if (firestore == null || user == null) return false;

    final snapshot = await firestore
        .collection(_collectionPath)
        .doc(user.uid)
        .collection(_settingsDocId)
        .doc(_officeDocId)
        .get();

    if (!snapshot.exists) return false;
    return _hasValidScheduleMap(snapshot.data());
  }

  Future<bool> hasLocalSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_kStartMinutes) ||
        !prefs.containsKey(_kEndMinutes) ||
        !prefs.containsKey(_kOffDays)) {
      return false;
    }

    final start = prefs.getInt(_kStartMinutes);
    final end = prefs.getInt(_kEndMinutes);
    final offDaysRaw = prefs.getStringList(_kOffDays);
    if (start == null || end == null || offDaysRaw == null) {
      return false;
    }

    List<int> offDays;
    try {
      offDays = offDaysRaw.map(int.parse).toList(growable: false);
    } catch (_) {
      return false;
    }

    return _isValidScheduleValues(start, end, offDays);
  }

  Future<OfficeSchedule?> loadFromFirebase() async {
    final firestore = FirebaseBootstrap.firestoreOrNull;
    final user = FirebaseBootstrap.authOrNull?.currentUser;
    if (firestore == null || user == null) return null;

    final snapshot = await firestore
        .collection(_collectionPath)
        .doc(user.uid)
        .collection(_settingsDocId)
        .doc(_officeDocId)
        .get();

    if (!snapshot.exists || snapshot.data() == null) return null;
    return OfficeSchedule.fromJson(snapshot.data()!);
  }

  Future<bool> save(OfficeSchedule schedule) async {
    await saveLocal(schedule);
    try {
      await saveToFirebase(schedule);
      return true;
    } catch (error) {
      debugPrint('Failed to save office schedule to Firebase: $error');
      return false;
    }
  }

  Future<void> saveLocal(OfficeSchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kStartMinutes, schedule.workStartMinutes);
    await prefs.setInt(_kEndMinutes, schedule.workEndMinutes);
    await prefs.setStringList(
      _kOffDays,
      schedule.offDays.map((day) => day.toString()).toList(growable: false),
    );
  }

  Future<void> saveToFirebase(OfficeSchedule schedule) async {
    final firestore = FirebaseBootstrap.firestoreOrNull;
    final user = FirebaseBootstrap.authOrNull?.currentUser;
    if (firestore == null || user == null) return;

    await firestore
        .collection(_collectionPath)
        .doc(user.uid)
        .collection(_settingsDocId)
        .doc(_officeDocId)
        .set(
          {
            ...schedule.toJson(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
  }

  bool _hasValidScheduleMap(Map<String, dynamic>? data) {
    if (data == null) return false;

    final start = (data['workStartMinutes'] as num?)?.toInt();
    final end = (data['workEndMinutes'] as num?)?.toInt();
    final offDaysDynamic = data['offDays'] as List<dynamic>?;
    if (start == null || end == null || offDaysDynamic == null) {
      return false;
    }

    final offDays = offDaysDynamic
        .whereType<num>()
        .map((value) => value.toInt())
        .toList(growable: false);

    if (offDays.length != offDaysDynamic.length) {
      return false;
    }
    return _isValidScheduleValues(start, end, offDays);
  }

  bool _isValidScheduleValues(int start, int end, List<int> offDays) {
    const minutesPerDay = 24 * 60;
    final validTimeRange =
        start >= 0 &&
        start < minutesPerDay &&
        end >= 0 &&
        end < minutesPerDay;
    final validOffDays = offDays.every(
      (day) => day >= DateTime.monday && day <= DateTime.sunday,
    );
    return validTimeRange && validOffDays;
  }
}
