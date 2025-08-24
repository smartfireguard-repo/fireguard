import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/history_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'user/welcome_page.dart';
import 'user/login_page.dart';
import 'user/register_page.dart';
import 'user/profile_page.dart';
import 'user/about_page.dart';
import 'user/history_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'utils/notification_helper.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔔 [Background] Received FCM: ${message.notification?.title}');
  await NotificationHelper.showCustomNotification(
    message.notification?.title ?? 'FireGuard Alert',
    message.notification?.body ?? 'Check your device status.',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationHelper.init(); // Initialize NotificationHelper

  runApp(
    ChangeNotifierProvider(
      create: (context) => HistoryProvider()..initialize(),
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
  @override
  void initState() {
    super.initState();
    _initFCM();
  }

  void _initFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission();
    print('🔔 Permission status: ${settings.authorizationStatus}');
    String? token = await messaging.getToken();
    print('📲 FCM Token: $token');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 [Foreground] Received FCM: ${message.notification?.title}');
      NotificationHelper.showCustomNotification(
        message.notification?.title ?? 'FireGuard Alert',
        message.notification?.body ?? 'Check your device status.',
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🧭 User tapped notification: ${message.notification?.title}');
      // Optionally navigate to history page or handle tap
      Navigator.of(context).pushNamed('/history');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart FireGuard',
      debugShowCheckedModeBanner: false,
      home: const AuthChecker(),
      routes: {
        '/welcome': (context) => const WelcomePage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/profile': (context) => const ProfilePage(),
        '/about': (context) => AboutPage(),
        '/history': (context) => const HistoryPage(),
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
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return snapshot.hasData ? const HistoryPage() : const WelcomePage();
      },
    );
  }
}