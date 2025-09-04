import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_fireguard/models/notification_type.dart';
import 'package:smart_fireguard/providers/history_provider.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    try {
      print('🔔 [Local] Initializing notifications');
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
      print('🔔 [Local] Notification channels created');
    } catch (e, stackTrace) {
      print('🔔 [Local] Error initializing notifications: $e\nStackTrace: $stackTrace');
    }
  }

  static Future<void> _createNotificationChannel(
    String channelId,
    String channelName,
    String channelDescription,
    String sound,
  ) async {
    try {
      print('🔔 [Local] Creating channel: $channelId');
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
      print('🔔 [Local] Channel $channelId created');
    } catch (e, stackTrace) {
      print('🔔 [Local] Error creating channel $channelId: $e\nStackTrace: $stackTrace');
    }
  }

  static Future<void> showCustomNotification(
    String? title,
    [String? body, BuildContext? context]
  ) async {
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

    print('🔔 [Local] Using sound: $sound for channel: $channelId');

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
        payload: 'history',
      );

      _lastNotificationTimestamps[title] = now;

      if (context != null) {
        final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
        final notifications = historyProvider.notifications;
        notifications.add({
          'title': title,
          'body': finalBody,
          'timestamp': now.toIso8601String(),
          'channelId': channelId,
          'sound': sound,
        });
        await historyProvider.updateNotifications(notifications);
        print('🔔 [Local] Saved notification to HistoryProvider');
      }
    } catch (e, stackTrace) {
      print('🔔 [Local] Error showing notification: $e\nStackTrace: $stackTrace');
    }
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

  static final Map<String, DateTime> _lastNotificationTimestamps = {};
}