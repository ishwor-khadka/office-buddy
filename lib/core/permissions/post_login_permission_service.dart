import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../notifications/notification_service.dart';

class PostLoginPermissionService {
  static const _kRequestedPrefix =
      'post_login_permission_onboarding_completed_';

  static Future<bool> hasCompletedForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return true;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_requestedKey(user.uid)) ?? false;
  }

  static Future<void> markCompletedForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_requestedKey(user.uid), true);
  }

  static Future<void> requestCamera() => _requestCamera();

  static Future<void> requestActivityRecognition() =>
      _requestActivityRecognition();

  static Future<void> requestNotifications() => _requestNotifications();

  static String _requestedKey(String uid) {
    return '$_kRequestedPrefix$uid';
  }

  static Future<void> _requestCamera() async {
    try {
      final status = await Permission.camera.status;
      if (status.isDenied || status.isRestricted || status.isLimited) {
        await Permission.camera.request().timeout(const Duration(seconds: 20));
      }
    } catch (error) {
      debugPrint('Failed to request camera permission: $error');
    }
  }

  static Future<void> _requestActivityRecognition() async {
    try {
      final status = await Permission.activityRecognition.status;
      if (status.isDenied || status.isRestricted || status.isLimited) {
        await Permission.activityRecognition.request().timeout(
          const Duration(seconds: 20),
        );
      }
    } catch (error) {
      debugPrint('Failed to request activity recognition permission: $error');
    }
  }

  static Future<void> _requestNotifications() async {
    try {
      await FirebaseMessaging.instance.requestPermission().timeout(
        const Duration(seconds: 20),
      );
    } catch (error) {
      debugPrint('Failed to request Firebase messaging permission: $error');
    }

    try {
      await NotificationService.requestAndroidPermissions().timeout(
        const Duration(seconds: 20),
      );
    } catch (error) {
      debugPrint('Failed to request local notification permissions: $error');
    }

    try {
      await NotificationService.requestIosPermissions().timeout(
        const Duration(seconds: 20),
      );
    } catch (error) {
      debugPrint('Failed to request iOS notification permissions: $error');
    }
  }
}
