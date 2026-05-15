import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../notifications/notification_service.dart';

class PostLoginPermissionService {
  static const _kRequestedPrefix = 'post_login_permissions_requested_';
  static Future<void>? _inFlightRequest;

  static Future<void> requestForCurrentUser({bool force = false}) async {
    if (_inFlightRequest != null) {
      return _inFlightRequest;
    }

    _inFlightRequest = _requestForCurrentUser(force: force);
    try {
      await _inFlightRequest;
    } finally {
      _inFlightRequest = null;
    }
  }

  static Future<void> _requestForCurrentUser({required bool force}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final requestedKey = '$_kRequestedPrefix${user.uid}';
    if (!force && (prefs.getBool(requestedKey) ?? false)) {
      return;
    }

    await _requestCamera();
    await _requestActivityRecognition();
    await _requestNotifications();

    await prefs.setBool(requestedKey, true);
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
  }
}
