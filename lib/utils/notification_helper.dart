import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:smart_fireguard/models/notification_type.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Store notification history with a limit
  static final List<Map<String, String>> _notificationHistory = [];
  static const int _maxHistorySize = 100;

  // Track last notification timestamp per type for rate limiting
  static final Map<String, DateTime> _lastNotificationTimestamps = {};

  static Future<void> init() async {
    try {
      const android = AndroidInitializationSettings('@mipmap/logo');
      const settings = InitializationSettings(android: android);
      await _flutterLocalNotificationsPlugin.initialize(settings);

      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.deleteNotificationChannel('fireguard_channel');

      await _createNotificationChannel(
        'flame_channel',
        'Flame Alerts',
        'Channel for flame detection alerts',
        'flamealarm',
      );
      await _createNotificationChannel(
        'smoke_channel',
        'Smoke Alerts',
        'Channel for smoke detection alerts',
        'smokealarm',
      );
      await _createNotificationChannel(
        'emergency_channel',
        'Emergency Alerts',
        'Channel for emergency alerts',
        'firealarm',
      );
      await _createNotificationChannel(
        'default_channel',
        'Default Alerts',
        'Channel for default alerts',
        'firealarm',
      );
    } catch (e) {
      print('🔔 [Local] Error initializing notifications: $e');
    }
  }

  static Future<void> _createNotificationChannel(
    String channelId,
    String channelName,
    String channelDescription,
    String sound,
  ) async {
    try {
      final androidChannel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound(sound),
      );
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    } catch (e) {
      print('🔔 [Local] Error creating channel $channelId: $e');
    }
  }

  static Future<void> showCustomNotification(String? title, [String? body]) async {
    if (title == null || title.isEmpty) {
      print('🔔 [Local] Error: Notification title is null or empty');
      return;
    }

    final now = DateTime.now();
    final lastTimestamp = _lastNotificationTimestamps[title];
    if (lastTimestamp != null && now.difference(lastTimestamp).inSeconds < 5) {
      print('🔔 [Local] Notification suppressed: $title (rate limit)');
      return;
    }

    print('🔔 [Local] Showing notification: $title - $body');

    String sound;
    String finalBody;
    String channelId;

    switch (title) {
      case 'FLAME DETECTED':
        finalBody = body?.isNotEmpty ?? false
            ? body!
            : 'Check for open flames or fire sources immediately. Ensure fire extinguishers are accessible.';
        sound = 'flamealarm';
        channelId = 'flame_channel';
        break;
      case 'SMOKE DETECTED':
        finalBody = body?.isNotEmpty ?? false
            ? body!
            : 'Ventilate the area if safe. Check for smoke sources like electrical faults or burning materials.';
        sound = 'smokealarm';
        channelId = 'smoke_channel';
        break;
      case 'EMERGENCY':
        finalBody = body?.isNotEmpty ?? false
            ? body!
            : 'Evacuate immediately and call emergency services. Do not re-enter until safe.';
        sound = 'firealarm';
        channelId = 'emergency_channel';
        break;
      default:
        finalBody = body?.isNotEmpty ?? false ? body! : 'Stay alert and monitor the situation.';
        sound = 'firealarm';
        channelId = 'default_channel';
    }

    print('🔔 Using sound: $sound for channel: $channelId');

    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        '$title Alerts',
        playSound: true,
        channelDescription: 'Channel for $title alerts',
        importance: Importance.max,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound(sound),
      );
      final platformDetails = NotificationDetails(android: androidDetails);

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        finalBody,
        platformDetails,
      );

      _lastNotificationTimestamps[title] = now;

      if (_notificationHistory.length >= _maxHistorySize) {
        _notificationHistory.removeAt(0);
      }
      _notificationHistory.add({
        'title': title,
        'body': finalBody,
        'timestamp': DateTime.now().toIso8601String(),
        'channelId': channelId,
        'sound': sound,
      });
    } catch (e) {
      print('🔔 [Local] Error showing notification: $e');
    }
  }

  static List<Map<String, String>> getNotificationHistory() {
    return List.unmodifiable(_notificationHistory);
  }

  static Future<void> testNotifications() async {
    await init();
    await showCustomNotification(NotificationType.flameDetected.value, 'Test flame');
    await Future.delayed(const Duration(seconds: 2));
    await showCustomNotification(NotificationType.smokeDetected.value, 'Test smoke');
    await Future.delayed(const Duration(seconds: 2));
    await showCustomNotification(NotificationType.emergency.value, 'Test emergency');
    await Future.delayed(const Duration(seconds: 2));
    await showCustomNotification(NotificationType.defaultNotification.value, 'Test default');
  }
}