// test/mocks.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:smart_fireguard/providers/history_provider.dart';
import 'package:flutter/material.dart';

@GenerateMocks([
  FirebaseDatabase,
  DatabaseReference,
  DataSnapshot,
  DatabaseEvent,
  FirebaseMessaging,
  FlutterLocalNotificationsPlugin,
  SharedPreferences,
  HistoryProvider,
  ServiceInstance,
  AndroidServiceInstance,
  BuildContext,
])
void main() {}