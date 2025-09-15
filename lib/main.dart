import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/history_provider.dart';
import 'firebase_options.dart';
import 'user/welcome_page.dart';
import 'user/login_page.dart';
import 'user/register_page.dart';
import 'user/profile_page.dart';
import 'user/about_page.dart';
import 'user/history_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'utils/notification_helper.dart';
import 'models/notification_type.dart';

/// ---------------------------------------------
/// FCM background handler
/// ---------------------------------------------
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await _initializeFirebase();
    print('🔔 [Background] Received FCM: ${message.toMap()}');
    
    final title = message.notification?.title ?? 'FireGuard Alert';
    final body = message.notification?.body ?? 'Check your device status.';

    // Show notification
    await NotificationHelper.showCustomNotification(title, body);

    // Save to user_logs
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId != null) {
      final ref = FirebaseDatabase.instance.ref('user_logs/$userId').push();
      await ref.set({
        'title': title,
        'body': body,
        'timestamp': DateTime.now().toIso8601String(),
        'channelId': title == 'FLAME DETECTED'
            ? 'flame_channel'
            : title == 'SMOKE DETECTED'
                ? 'smoke_channel'
                : title == 'EMERGENCY'
                    ? 'emergency_channel'
                    : 'default_channel',
        'sound': title == 'FLAME DETECTED'
            ? 'flamealarm'
            : title == 'SMOKE DETECTED'
                ? 'smokealarm'
                : 'firealarm',
      });
      print('🔔 [Background] Saved FCM notification to user_logs');
    } else {
      print('🔔 [Background] No userId, cannot save FCM notification');
    }
  } catch (e, stackTrace) {
    print('🔔 [Background] FCM Error: $e\nStackTrace: $stackTrace');
  }
}

/// ---------------------------------------------
/// Background service config + entry point
/// ---------------------------------------------
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      autoStartOnBoot: true,
      isForegroundMode: true,
      foregroundServiceTypes: [AndroidForegroundType.dataSync],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  await service.startService();
  print('🔄 [Main] Background service started');
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  try {
    // Initialize Firebase with retry
    await _initializeFirebase();
    print('🔄 [Background] Firebase initialized');

    // Initialize SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');
    String? deviceId = prefs.getString('deviceId');
    print('🔄 [Background] UserID: $userId, DeviceID: $deviceId');

    // If no userId or deviceId, try to fetch from FirebaseAuth
    if (userId == null || deviceId == null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        userId = user.uid;
        final snapshot = await FirebaseDatabase.instance
            .ref('users/$userId')
            .get();
        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>?;
          deviceId = data?['deviceId']?.toString() ?? '';
          await prefs.setString('userId', userId);
          await prefs.setString('deviceId', deviceId);
          print('🔄 [Background] Fetched from Firebase: UserID: $userId, DeviceID: $deviceId');
        } else {
          print('🔄 [Background] No user data in Firebase');
          return;
        }
      } else {
        print('🔄 [Background] No authenticated user');
        return;
      }
    }

    // Monitor RTDB if user and device are available
    if (userId != null && deviceId != null && deviceId.isNotEmpty) {
      DatabaseReference deviceRef = FirebaseDatabase.instance.ref('device_ids/$deviceId');
      print('🔄 [Background] Setting up listener for device_ids/$deviceId');
      deviceRef.onValue.listen((event) async {
        try {
          final data = event.snapshot.value as Map?;
          print('🔄 [Background] Received device data: $data');
          if (data != null) {
            // Process notification using fuzzy logic
            final double? temp = _parseDouble(data['temperature'] ?? data['temp']);
            final double? smoke = _parseDouble(data['smoke'] ?? data['smokeLevel']);
            final bool flame = (data['flame'] == 1 ||
                data['flame']?.toString() == '1' ||
                data['flame'] == true ||
                data['flame']?.toString().toLowerCase() == 'yes');
            final now = DateTime.now();

            final fuzzyTemp = _fuzzifyTemp(temp ?? 0);
            final fuzzySmoke = _fuzzifySmoke(smoke ?? 0);
            final notifType = _determineNotificationType(fuzzyTemp, fuzzySmoke, flame);

            if (notifType == null) {
              print('🔄 [Background] No notification triggered for data: $data');
              return;
            }

            // Create notification
            final notif = {
              'type': notifType,
              'date': _nowDate(),
              'time': _nowTime(),
              'smoke': smoke != null ? '${smoke.toStringAsFixed(1)}' : 'N/A',
              'temperature': temp != null ? '${temp.toStringAsFixed(1)}°C' : 'N/A',
              'flame': flame ? 'YES' : 'NO',
              'emergency': notifType == NotificationType.emergency.value ? 'true' : 'false',
              'timestamp': now.millisecondsSinceEpoch,
            };
            print('🔄 [Background] Creating notification: $notif');

            // Save to RTDB
            final ref = FirebaseDatabase.instance.ref('user_logs/$userId').push();
            await ref.set(notif);
            print('🔄 [Background] Notification saved to RTDB');

            // Show notification
            await NotificationHelper.showCustomNotification(notifType);
            print('🔄 [Background] Notification displayed: $notifType');
          } else {
            print('🔄 [Background] No device data');
          }
        } catch (e, stackTrace) {
          print('🔄 [Background] Device data error: $e\nStackTrace: $stackTrace');
        }
      }, onError: (error) {
        print('🔄 [Background] Device data error: $error');
      });
    } else {
      print('🔄 [Background] Cannot set up listener: userId=$userId, deviceId=$deviceId');
    }

    // Set as foreground service
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((_) => service.setAsForegroundService());
      service.on('setAsBackground').listen((_) => service.setAsBackgroundService());
      await service.setAsForegroundService();
      await service.setForegroundNotificationInfo(
        title: 'FireGuard Service',
        content: 'Monitoring device status...',
      );
      print('🔄 [Background] Foreground service set');
    }

    // Stop handler
    service.on('stopService').listen((_) => service.stopSelf());

    // Periodic task
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      print('🔄 [Background] Service running at ${DateTime.now()}');
      if (service is AndroidServiceInstance && await service.isForegroundService()) {
        await service.setForegroundNotificationInfo(
          title: 'FireGuard Service',
          content: 'Last check at ${DateTime.now()}',
        );
      }
      await prefs.setString('last_active', DateTime.now().toIso8601String());
    });
  } catch (e, stackTrace) {
    print('🔄 [Background] Error: $e\nStackTrace: $stackTrace');
  }
}

/// ---------------------------------------------
/// Helper to initialize Firebase with retry
/// ---------------------------------------------
Future<void> _initializeFirebase() async {
  const maxRetries = 3;
  for (var attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      print('🔄 [Background] Firebase initialized successfully');
      return;
    } catch (e) {
      print('🔄 [Background] Firebase init attempt $attempt failed: $e');
      if (attempt == maxRetries) rethrow;
      await Future.delayed(const Duration(seconds: 2));
    }
  }
}

// Fuzzy logic for temperature
Map<String, double> _fuzzifyTemp(double temp) {
  double low = 0, med = 0, high = 0;
  if (temp <= 25) low = 1;
  else if (temp > 25 && temp < 30) low = (30 - temp) / 5;
  if (temp >= 25 && temp <= 45) med = (temp <= 35) ? (temp - 25) / 10 : (45 - temp) / 10;
  if (temp >= 35) high = (temp >= 55) ? 1 : (temp - 35) / 20;
  return {
    'Low': low.clamp(0, 1),
    'Medium': med.clamp(0, 1),
    'High': high.clamp(0, 1),
  };
}

// Fuzzy logic for smoke
Map<String, double> _fuzzifySmoke(double smoke) {
  double clean = 0, mod = 0, smoky = 0;
  if (smoke <= 200) clean = 1;
  else if (smoke > 200 && smoke < 300) clean = (300 - smoke) / 100;
  if (smoke >= 200 && smoke <= 300) mod = (smoke - 200) / 100;
  else if (smoke > 300 && smoke <= 400) mod = 1;
  else if (smoke > 400 && smoke <= 500) mod = (500 - smoke) / 100;
  if (smoke > 400 && smoke <= 500) smoky = (smoke - 400) / 100;
  else if (smoke > 500) smoky = 1;
  return {
    'Clean': clean.clamp(0, 1),
    'Moderate': mod.clamp(0, 1),
    'Smoky': smoky.clamp(0, 1),
  };
}

// Determines notification type
String? _determineNotificationType(
    Map<String, double> fuzzyTemp,
    Map<String, double> fuzzySmoke,
    bool flame,
) {
  if ((fuzzySmoke['Smoky'] ?? 0) >= 0.7 && (fuzzyTemp['High'] ?? 0) >= 0.7) {
    return NotificationType.emergency.value;
  }
  if (flame) {
    return NotificationType.flameDetected.value;
  }
  if ((fuzzySmoke['Smoky'] ?? 0) >= 0.7) {
    return NotificationType.smokeDetected.value;
  }
  return null;
}

// Parses dynamic value to double
double? _parseDouble(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toDouble();
  if (val is String) {
    final cleaned = val.replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(cleaned);
  }
  return null;
}

// Formats current date as MMDDYYYY
String _nowDate() {
  final now = DateTime.now();
  return '${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.year}';
}

// Formats current time as HH:MM AM/PM
String _nowTime() {
  final now = DateTime.now();
  int hour = now.hour;
  final ampm = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12 == 0 ? 12 : hour % 12;
  final minute = now.minute.toString().padLeft(2, '0');
  return '$hour:$minute $ampm';
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  print('🍎 [iOS Background] Running task...');
  return true;
}

/// ---------------------------------------------
/// Permissions
/// ---------------------------------------------
Future<void> requestBackgroundPermissions() async {
  final notificationStatus = await Permission.notification.request();
  print('🔔 Notification Permission: $notificationStatus');
  if (notificationStatus.isDenied || notificationStatus.isPermanentlyDenied) {
    print('🔔 Notification permission denied, opening settings');
    await openAppSettings();
  }

  final batteryStatus = await Permission.ignoreBatteryOptimizations.request();
  print('🔋 Battery Optimization Exemption: $batteryStatus');
  if (batteryStatus.isDenied || batteryStatus.isPermanentlyDenied) {
    print('🔋 Battery optimization exemption denied, opening settings');
    await openAppSettings();
  }
}

/// ---------------------------------------------
/// Main
/// ---------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();

  // Register FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize local notifications
  await NotificationHelper.init();

  // Request permissions
  await requestBackgroundPermissions();

  // Start background service
  await initializeBackgroundService();

  // Ensure user data is saved
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', user.uid);
    final snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>?;
      final deviceId = data?['deviceId']?.toString() ?? '';
      await prefs.setString('deviceId', deviceId);
      print('📲 [Main] Saved userId: ${user.uid}, deviceId: $deviceId');
    }
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => HistoryProvider()..initialize(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initFCM();
  }

  Future<void> _initFCM() async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
    print('🔔 FCM Permission: ${settings.authorizationStatus}');

    final token = await messaging.getToken();
    print('📲 FCM Token: $token');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final title = message.notification?.title ?? 'FireGuard Alert';
      final body = message.notification?.body ?? 'Check your device status.';
      print('📩 [Foreground] $title');
      await NotificationHelper.showCustomNotification(title, body, context);

      final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
      final notifications = historyProvider.notifications;
      notifications.add({
        'title': title,
        'body': body,
        'timestamp': DateTime.now().toIso8601String(),
        'channelId': title == 'FLAME DETECTED'
            ? 'flame_channel'
            : title == 'SMOKE DETECTED'
                ? 'smoke_channel'
                : title == 'EMERGENCY'
                    ? 'emergency_channel'
                    : 'default_channel',
        'sound': title == 'FLAME DETECTED'
            ? 'flamealarm'
            : title == 'SMOKE DETECTED'
                ? 'smokealarm'
                : 'firealarm',
      });
      await historyProvider.updateNotifications(notifications);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('🧭 Notification tapped from background: ${message.notification?.title}');
      if (mounted) {
        Navigator.of(context).pushNamed('/history');
      }
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null && mounted) {
      print('🧭 App opened from terminated: ${initialMessage.notification?.title}');
      Navigator.of(context).pushNamed('/history');
    }

    await _flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/logo')),
      onDidReceiveNotificationResponse: (resp) {
        if (resp.payload == 'history' && mounted) {
          Navigator.of(context).pushNamed('/history');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart FireGuard',
      debugShowCheckedModeBanner: false,
      home: const AuthChecker(),
      routes: {
        '/welcome': (_) => const WelcomePage(),
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/profile': (_) => const ProfilePage(),
        '/about': (_) => AboutPage(),
        '/history': (_) => const HistoryPage(),
      },
    );
  }
}

class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return snapshot.hasData ? const HistoryPage() : const WelcomePage();
      },
    );
  }
}