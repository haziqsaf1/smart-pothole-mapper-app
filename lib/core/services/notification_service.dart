import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Keep track of hazards already notified to avoid repeated alerts
  static final Set<String> _notifiedHazardIds = {};

  static Future<void> init() async {
    if (kIsWeb) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initializationSettings);

    // Request notification permission on Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  static Future<void> showHazardWarning({
    required String hazardId,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    // If the user was already alerted about this pothole, skip it
    if (_notifiedHazardIds.contains(hazardId)) return;

    const androidDetails = AndroidNotificationDetails(
      'pothole_warnings_channel',
      'Pothole Warnings',
      channelDescription: 'Alerts users when approaching road hazards',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      hazardId.hashCode, // Unique ID for notification instance
      title,
      body,
      notificationDetails,
    );

    // Mark as notified
    _notifiedHazardIds.add(hazardId);
  }

  /// Reset tracked hazard IDs (e.g., when starting a new trip)
  static void clearNotifiedHistory() {
    _notifiedHazardIds.clear();
  }
}
